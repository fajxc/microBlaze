`timescale 1ns / 1ps

module nn_core #(
    parameter integer N_IN  = 784,
    parameter integer H     = 32,
    parameter integer N_OUT = 10,
    parameter integer SHIFT = 8
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    output reg         done,

    input  wire        pix_we,
    input  wire [9:0]  pix_addr,
    input  wire [7:0]  pix_data,

    output wire        b1_en,
    output wire [4:0]  b1_addr,
    input  wire [31:0] b1_dout,

    output wire        w1_en,
    output wire [14:0] w1_addr,
    input  wire [7:0]  w1_dout,

    output wire        w2_en,
    output wire [8:0]  w2_addr,
    input  wire [7:0]  w2_dout,

    output wire        b2_en,
    output wire [3:0]  b2_addr,
    input  wire [31:0] b2_dout,

    // Reserved debug registers (tied to 0, available for future use)
    output wire signed [31:0] dbg_score0,
    output wire signed [31:0] dbg_acc0,
    output wire signed [31:0] dbg_b20,
    output wire signed [31:0] dbg_partial4_o0,
    output wire signed [31:0] dbg_w2_00,

    output reg [3:0] predicted
);

    // Debug ports reserved for future use
    assign dbg_score0      = 32'sd0;
    assign dbg_acc0        = 32'sd0;
    assign dbg_b20         = 32'sd0;
    assign dbg_partial4_o0 = 32'sd0;
    assign dbg_w2_00       = 32'sd0;

    // ============================================================
    // FSM State Encoding
    // ============================================================
    localparam S_IDLE       = 4'd0,
               S_L1_SET     = 4'd1,
               S_L1_WAIT    = 4'd2,
               S_L1_MAC     = 4'd3,
               S_L1_FINISH  = 4'd4,
               S_L2_SET     = 4'd5,
               S_L2_WAIT    = 4'd6,
               S_L2_MAC     = 4'd7,
               S_L2_FINISHO = 4'd8,
               S_DONE       = 4'd9,
               S_L2_PRIME0  = 4'd10,
               S_L1_PRIME0  = 4'd11;

    reg [3:0] state;

    // ============================================================
    // Pixel Buffer
    // ============================================================
    reg [7:0] x_mem [0:N_IN-1];

    always @(posedge clk) begin
        if (!rst && pix_we && pix_addr < N_IN)
            x_mem[pix_addr] <= pix_data;
    end

    // ============================================================
    // ROM Control
    // ============================================================
    reg        b1_en_r, w1_en_r, w2_en_r, b2_en_r;
    reg [4:0]  b1_addr_r;
    reg [14:0] w1_addr_r;
    reg [8:0]  w2_addr_r;
    reg [3:0]  b2_addr_r;

    assign b1_en   = b1_en_r;
    assign b1_addr = b1_addr_r;
    assign w1_en   = w1_en_r;
    assign w1_addr = w1_addr_r;
    assign w2_en   = w2_en_r;
    assign w2_addr = w2_addr_r;
    assign b2_en   = b2_en_r;
    assign b2_addr = b2_addr_r;

    // ============================================================
    // BRAM Output Registers (1-cycle read latency)
    // ============================================================
    reg signed [7:0]  w1_q, w2_q;
    reg signed [31:0] b1_q, b2_q;

    always @(posedge clk) begin
        if (rst) begin
            w1_q <= 8'sd0;  w2_q <= 8'sd0;
            b1_q <= 32'sd0; b2_q <= 32'sd0;
        end else begin
            w1_q <= $signed(w1_dout);
            w2_q <= $signed(w2_dout);
            b1_q <= $signed(b1_dout);
            b2_q <= $signed(b2_dout);
        end
    end

    // ============================================================
    // Hidden Layer Storage
    // ============================================================
    reg signed [31:0] hidden [0:H-1];

    // ============================================================
    // Address Index Functions (row-major)
    // w1[h][i] -> h*784 + i
    // w2[o][h] -> o*32  + h
    // ============================================================
    function [14:0] w1_index;
        input [5:0] hh;
        input [9:0] ii;
        reg [14:0] tmp;
        begin
            tmp = {{9{1'b0}}, hh} * 15'd784;
            w1_index = tmp + {{5{1'b0}}, ii};
        end
    endfunction

    function [8:0] w2_index;
        input [3:0] oo;
        input [5:0] hh;
        reg [8:0] tmp;
        begin
            tmp = {{5{1'b0}}, oo} * 9'd32;
            w2_index = tmp + {{3{1'b0}}, hh[4:0]};
        end
    endfunction

    // ============================================================
    // Start Pulse Detector
    // ============================================================
    reg  start_d;
    wire start_pulse = start & ~start_d;

    always @(posedge clk) begin
        if (rst) start_d <= 1'b0;
        else     start_d <= start;
    end

    // ============================================================
    // Loop Counters
    // ============================================================
    reg [9:0] ii;
    reg [5:0] hh;
    reg [3:0] oo;

    // ============================================================
    // Layer 1 Pipeline Tags
    // Track which (hh, ii) was issued to BRAM vs which is being used in MAC
    // ============================================================
    reg [5:0] l1_hh_issued, l1_hh_use;
    reg [9:0] l1_ii_issued, l1_ii_use;

    reg signed [7:0] w1_use;
    reg [7:0]        x_use;
    reg [7:0]        x_q;

    // ============================================================
    // Layer 2 Pipeline Tags
    // ============================================================
    reg [5:0] hh_issued, hh_use_tag;
    reg [3:0] oo_issued, oo_use_tag;

    reg signed [7:0]  w2_use;
    reg signed [31:0] hs_use;
    reg signed [31:0] hscaled_q;

    // ============================================================
    // Accumulators and Argmax
    // ============================================================
    reg signed [63:0] acc;
    reg signed [63:0] best_val;
    reg [3:0]         best_idx;
    reg signed [63:0] l1_sum;

    // ============================================================
    // Combinational MAC Wires
    // ============================================================

    // Layer 1: int8 weight * uint8 pixel
    wire signed [15:0] mul_w1x_use = $signed(w1_use) * $signed({1'b0, x_use});

    // Layer 2: int8 weight * int32 hidden_scaled
    wire signed [63:0] term_use     = $signed(w2_use) * $signed(hs_use);
    wire signed [63:0] acc_use_next = acc + term_use;

    // Layer 2 final score: accumulator + bias
    wire signed [63:0] score64 = acc + $signed(b2_q);

    // ============================================================
    // FSM
    // ============================================================
    integer t;
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            done      <= 1'b0;
            predicted <= 4'd0;

            b1_en_r <= 1'b0; w1_en_r <= 1'b0;
            w2_en_r <= 1'b0; b2_en_r <= 1'b0;

            b1_addr_r <= 5'd0;  w1_addr_r <= 15'd0;
            w2_addr_r <= 9'd0;  b2_addr_r <= 4'd0;

            ii <= 10'd0; hh <= 6'd0; oo <= 4'd0;
            acc      <= 64'sd0;
            best_val <= -64'sd9223372036854775807;
            best_idx <= 4'd0;

            l1_hh_issued <= 6'd0;  l1_ii_issued <= 10'd0;
            l1_hh_use    <= 6'd0;  l1_ii_use    <= 10'd0;
            w1_use <= 8'sd0; x_use <= 8'd0; x_q <= 8'd0;

            hh_issued  <= 6'd0;  oo_issued  <= 4'd0;
            hh_use_tag <= 6'd0;  oo_use_tag <= 4'd0;
            w2_use <= 8'sd0; hs_use <= 32'sd0;

            hscaled_q <= 32'sd0;

            for (t = 0; t < H; t = t + 1)
                hidden[t] <= 32'sd0;

        end else begin
            done <= (state == S_DONE);

            case (state)

            // ------------------------------------------------
            // IDLE: wait for start pulse, then kick off Layer 1
            // ------------------------------------------------
            S_IDLE: begin
                done    <= 1'b0;
                b1_en_r <= 1'b0; w1_en_r <= 1'b0;
                w2_en_r <= 1'b0; b2_en_r <= 1'b0;

                if (start_pulse) begin
                    hh  <= 6'd0;
                    ii  <= 10'd0;
                    acc <= 64'sd0;

                    w1_en_r   <= 1'b1;
                    w1_addr_r <= w1_index(6'd0, 10'd0);
                    b1_en_r   <= 1'b1;
                    b1_addr_r <= 5'd0;

                    x_q          <= x_mem[10'd0];
                    l1_hh_issued <= 6'd0;
                    l1_ii_issued <= 10'd0;

                    state <= S_L1_PRIME0;
                end
            end

            // ------------------------------------------------
            // Layer 1: PRIME -> WAIT -> MAC loop
            // PRIME burns 1 cycle for BRAM read latency
            // WAIT latches the valid BRAM output
            // MAC accumulates and issues the next address
            // ------------------------------------------------
            S_L1_PRIME0: begin
                w1_en_r <= 1'b1;
                b1_en_r <= 1'b1;
                state   <= S_L1_WAIT;
            end

            S_L1_WAIT: begin
                w1_en_r <= 1'b1;
                b1_en_r <= 1'b1;

                w1_use    <= $signed(w1_dout);
                x_use     <= x_q;
                l1_hh_use <= l1_hh_issued;
                l1_ii_use <= l1_ii_issued;

                state <= S_L1_MAC;
            end

            S_L1_MAC: begin
                acc <= acc + $signed({{48{mul_w1x_use[15]}}, mul_w1x_use});

                if (ii < N_IN-1) begin
                    ii <= ii + 10'd1;

                    w1_en_r      <= 1'b1;
                    w1_addr_r    <= w1_index(hh, ii + 10'd1);
                    x_q          <= x_mem[ii + 10'd1];
                    l1_hh_issued <= hh;
                    l1_ii_issued <= ii + 10'd1;

                    state <= S_L1_PRIME0;
                end else begin
                    state <= S_L1_FINISH;
                end
            end

            // ------------------------------------------------
            // Layer 1: FINISH - apply bias + ReLU, move to next neuron
            // ------------------------------------------------
            S_L1_FINISH: begin
                l1_sum = acc + $signed(b1_q);
                hidden[hh] <= (l1_sum > 0) ? l1_sum[31:0] : 32'sd0;

                if (hh < H-1) begin
                    hh  <= hh + 6'd1;
                    ii  <= 10'd0;
                    acc <= 64'sd0;

                    w1_en_r      <= 1'b1;
                    w1_addr_r    <= w1_index(hh + 6'd1, 10'd0);
                    l1_hh_issued <= hh + 6'd1;
                    l1_ii_issued <= 10'd0;
                    b1_en_r      <= 1'b1;
                    b1_addr_r    <= hh + 6'd1;
                    x_q          <= x_mem[10'd0];

                    state <= S_L1_WAIT;
                end else begin
                    // Transition to Layer 2
                    oo  <= 4'd0;
                    hh  <= 6'd0;
                    acc <= 64'sd0;

                    best_val <= -64'sd9223372036854775807;
                    best_idx <= 4'd0;

                    w2_en_r   <= 1'b1;
                    w2_addr_r <= w2_index(4'd0, 6'd0);
                    b2_en_r   <= 1'b1;
                    b2_addr_r <= 4'd0;

                    hscaled_q <= (hidden[6'd0] >>> SHIFT);
                    oo_issued <= 4'd0;
                    hh_issued <= 6'd0;

                    state <= S_L2_PRIME0;
                end
            end

            // ------------------------------------------------
            // Layer 2: PRIME -> WAIT -> MAC loop
            // Same BRAM latency pattern as Layer 1
            // ------------------------------------------------
            S_L2_PRIME0: begin
                w2_en_r <= 1'b1;
                b2_en_r <= 1'b1;
                state   <= S_L2_WAIT;
            end

            S_L2_WAIT: begin
                w2_en_r <= 1'b1;
                b2_en_r <= 1'b1;

                w2_use     <= $signed(w2_dout);
                hs_use     <= hscaled_q;
                oo_use_tag <= oo_issued;
                hh_use_tag <= hh_issued;

                state <= S_L2_MAC;
            end

            S_L2_MAC: begin
                acc <= acc_use_next;

                if (hh == H-1) begin
                    state <= S_L2_FINISHO;
                end else begin
                    hh <= hh + 6'd1;

                    w2_en_r   <= 1'b1;
                    w2_addr_r <= w2_index(oo, hh + 6'd1);
                    hscaled_q <= (hidden[hh + 6'd1] >>> SHIFT);
                    oo_issued <= oo;
                    hh_issued <= hh + 6'd1;

                    state <= S_L2_PRIME0;
                end
            end

            // ------------------------------------------------
            // Layer 2: FINISH - add bias, update argmax, next output neuron
            // ------------------------------------------------
            S_L2_FINISHO: begin
                if (score64 > best_val) begin
                    best_val <= score64;
                    best_idx <= oo;
                end

                if (oo < N_OUT-1) begin
                    oo  <= oo + 4'd1;
                    hh  <= 6'd0;
                    acc <= 64'sd0;

                    w2_en_r   <= 1'b1;
                    w2_addr_r <= w2_index(oo + 4'd1, 6'd0);
                    b2_en_r   <= 1'b1;
                    b2_addr_r <= oo + 4'd1;

                    hscaled_q <= (hidden[6'd0] >>> SHIFT);
                    oo_issued <= oo + 4'd1;
                    hh_issued <= 6'd0;

                    state <= S_L2_WAIT;
                end else begin
                    predicted <= (score64 > best_val) ? oo : best_idx;
                    state     <= S_DONE;
                end
            end

            // ------------------------------------------------
            // DONE: hold until start deasserts
            // ------------------------------------------------
            S_DONE: begin
                b1_en_r <= 1'b0; w1_en_r <= 1'b0;
                w2_en_r <= 1'b0; b2_en_r <= 1'b0;

                if (!start) state <= S_IDLE;
            end

            default: state <= S_IDLE;

            endcase
        end
    end

endmodule