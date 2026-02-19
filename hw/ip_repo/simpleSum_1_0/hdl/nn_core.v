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

    output reg signed [31:0] dbg_score0,
    output reg signed [31:0] dbg_acc0,
    output reg signed [31:0] dbg_b20,
    output reg signed [31:0] dbg_partial4_o0, // sum h=0..3 for o=0, no bias
    output reg signed [31:0] dbg_w2_00,  // actual w2[0][0] seen (sign-extended)
    
    output reg  [3:0]  predicted
);

    // ============================================================
    // Pixel buffer (uint8 exactly like your friend's C)
    // ============================================================
    reg [7:0] x_mem [0:N_IN-1];
    always @(posedge clk) begin
        if (!rst && pix_we) begin
            if (pix_addr < N_IN)
                x_mem[pix_addr] <= pix_data;
        end
    end

    // ============================================================
    // ROM control regs
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
    // Capture ROM outputs (keeps timing deterministic)
    // BRAM read latency is 1 cycle, so these regs hold "addr from prev cycle"
    // ============================================================
    reg signed [7:0]  w1_q, w2_q;
    reg signed [31:0] b1_q, b2_q;

    always @(posedge clk) begin
        if (rst) begin
            w1_q <= 8'sd0;
            w2_q <= 8'sd0;
            b1_q <= 32'sd0;
            b2_q <= 32'sd0;
        end else begin
            w1_q <= $signed(w1_dout);
            w2_q <= $signed(w2_dout);
            b1_q <= $signed(b1_dout);
            b2_q <= $signed(b2_dout);
        end
    end

    // ============================================================
    // Hidden storage (use 32-bit like friend's C, but keep accumulator wide)
    // ============================================================
    reg signed [31:0] hidden [0:H-1];

    // ============================================================
    // Address helpers (row-major matches friend's w1[h][i], w2[o][h])
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
    // Start pulse detect
    // ============================================================
    reg start_d;
    wire start_pulse = start & ~start_d;
    always @(posedge clk) begin
        if (rst) start_d <= 1'b0;
        else     start_d <= start;
    end

    // ============================================================
    // Loop counters, accumulators, argmax
    // ============================================================
    reg [9:0] ii;
    reg [5:0] hh;
    reg [3:0] oo;
    
    reg [5:0] hh_d1;
    reg [3:0] oo_d1;
    
    reg signed [63:0] l1_sum;

    reg signed [63:0] acc;        // wide accumulator
    reg signed [63:0] best_val;
    reg [3:0]         best_idx;

    // Latch the corresponding data for the address we just issued
    reg [7:0]         x_q;         // uint8
    reg signed [31:0] hscaled_q;   // hidden >>> SHIFT
    reg signed [31:0] hscaled_q_d1;
    
    // latching regs at l2 wait
    reg signed [7:0]  w2_use;
    reg signed [31:0] hs_use;


    // Multipliers (signed weights, unsigned x, signed hidden_scaled)
    wire signed [15:0] mul_w1x = w1_q * $signed({1'b0, x_q});        // int8 * uint8
    wire signed [39:0] mul_w2h = w2_q * $signed(hscaled_q_d1);          // int8 * int32
    
    
    // Layer 2 score for current output neuron (logit)
    wire signed [63:0] score64 = acc + $signed(b2_q);
    wire signed [63:0] term_w2h = $signed({{24{mul_w2h[39]}}, mul_w2h});
    wire signed [63:0] acc_next = acc + term_w2h;
    
    wire signed [63:0] term_use = $signed(w2_use) * $signed(hs_use);
    wire signed [63:0] acc_use_next = acc + term_use;
    // ============================================================
    // FSM (explicit PRIME waits for 1-cycle ROM)
    // ============================================================
    localparam S_IDLE        = 4'd0,

               // Layer 1
               S_L1_SET      = 4'd1,
               S_L1_WAIT     = 4'd2,
               S_L1_MAC      = 4'd3,
               S_L1_FINISH   = 4'd4,

               // Layer 2
               S_L2_SET      = 4'd5,
               S_L2_WAIT     = 4'd6,
               S_L2_MAC      = 4'd7,
               S_L2_FINISHO  = 4'd8,

               S_DONE        = 4'd9;

    reg [3:0] state;

    integer t;
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            done      <= 1'b0;
            predicted <= 4'd0;
            dbg_score0 <= 32'sd0;
            dbg_acc0   <= 32'sd0;
            dbg_b20    <= 32'sd0;
            dbg_partial4_o0 <= 32'sd0;
            dbg_w2_00 <= 32'sd0;
            hh_d1 <= 6'd0;
            oo_d1 <= 4'd0;
            hscaled_q_d1 <= 32'sd0;
            w2_use <= 8'sd0;
            hs_use <= 32'sd0;

            

            b1_en_r <= 1'b0; w1_en_r <= 1'b0; w2_en_r <= 1'b0; b2_en_r <= 1'b0;
            b1_addr_r <= 5'd0; w1_addr_r <= 15'd0; w2_addr_r <= 9'd0; b2_addr_r <= 4'd0;

            ii <= 10'd0; hh <= 6'd0; oo <= 4'd0;
            acc <= 64'sd0;

            best_val <= -64'sd9223372036854775807;
            best_idx <= 4'd0;

            x_q <= 8'd0;
            hscaled_q <= 32'sd0;

            for (t = 0; t < H; t = t + 1)
                hidden[t] <= 32'sd0;

        end else begin
            // default behavior
            done <= (state == S_DONE);
            hh_d1 <= hh;
            oo_d1 <= oo;
            hscaled_q_d1 <= hscaled_q;
            case (state)

            // ====================================================
            // IDLE
            // ====================================================
            S_IDLE: begin
                done <= 1'b0;

                b1_en_r <= 1'b0; w1_en_r <= 1'b0; w2_en_r <= 1'b0; b2_en_r <= 1'b0;

                if (start_pulse) begin
                    // start layer1 at hh=0, ii=0
                    hh  <= 6'd0;
                    ii  <= 10'd0;
                    acc <= 64'sd0;

                    // enable w1/b1 and set initial addresses
                    w1_en_r   <= 1'b1;
                    w1_addr_r <= w1_index(6'd0, 10'd0);

                    b1_en_r   <= 1'b1;
                    b1_addr_r <= 5'd0;

                    // latch matching x for the address we just issued
                    x_q <= x_mem[10'd0];

                    state <= S_L1_WAIT; // wait 1 cycle for w1_q to become valid
                end
            end

            // ====================================================
            // LAYER 1: WAIT (prime ROM)
            // ====================================================
            S_L1_WAIT: begin
                // keep ROMs enabled (safe)
                w1_en_r <= 1'b1;
                b1_en_r <= 1'b1;
                state <= S_L1_MAC;
            end

            // ====================================================
            // LAYER 1: MAC
            // ====================================================
            S_L1_MAC: begin
                // accumulate using the weight/data from the address issued 1 cycle ago
                acc <= acc + $signed({{48{mul_w1x[15]}}, mul_w1x});

                if (ii < N_IN-1) begin
                    // issue next address and latch its x
                    ii <= ii + 10'd1;

                    w1_en_r   <= 1'b1;
                    w1_addr_r <= w1_index(hh, ii + 10'd1);

                    x_q <= x_mem[ii + 10'd1];

                    // stay in MAC (pipeline continues, no extra waits)
                    state <= S_L1_MAC;
                end else begin
                    // finished dot-product for this hidden neuron
                    state <= S_L1_FINISH;
                end
            end

            // ====================================================
            // LAYER 1: FINISH (bias + ReLU, then next hidden neuron)
            // ====================================================
            S_L1_FINISH: begin
                // bias is in b1_q (address set at start of this hh)
                // friend does int32 accum; we clamp by truncating to 32 after ReLU
                // ReLU
                l1_sum = acc + $signed(b1_q);
                if (l1_sum > 0)
                    hidden[hh] <= l1_sum[31:0];
                else
                    hidden[hh] <= 32'sd0;

                if (hh < H-1) begin
                    // next hidden neuron
                    hh  <= hh + 6'd1;
                    ii  <= 10'd0;
                    acc <= 64'sd0;

                    // set next addresses
                    w1_en_r   <= 1'b1;
                    w1_addr_r <= w1_index(hh + 6'd1, 10'd0);

                    b1_en_r   <= 1'b1;
                    b1_addr_r <= hh + 6'd1;

                    x_q <= x_mem[10'd0];

                    state <= S_L1_WAIT; // prime for new hh
                end else begin
                    // move to layer2, output neuron 0
                    oo <= 4'd0;
                    hh <= 6'd0;
                    acc <= 64'sd0;

                    dbg_partial4_o0 <= 32'sd0;
                    dbg_w2_00       <= 32'sd0;

                    best_val <= -64'sd9223372036854775807;
                    best_idx <= 4'd0;

                    // set initial layer2 addresses and latch hidden_scaled
                    w2_en_r   <= 1'b1;
                    w2_addr_r <= w2_index(4'd0, 6'd0);

                    b2_en_r   <= 1'b1;
                    b2_addr_r <= 4'd0;

                    hscaled_q <= (hidden[6'd0] >>> SHIFT);

                    state <= S_L2_WAIT; // prime for w2_q
                end
            end

// ====================================================
// LAYER 2: WAIT (prime ROM)
// ====================================================
S_L2_WAIT: begin
    // keep ROMs enabled
    w2_en_r <= 1'b1;
    b2_en_r <= 1'b1;

    // Latch aligned operands for the CURRENT (oo, hh)
    // At this point, w2_q corresponds to w2_addr_r issued earlier,
    // and hscaled_q corresponds to the same hh that was issued.
    w2_use <= w2_q;
    hs_use <= hscaled_q;

    state <= S_L2_MAC;
end


           // ====================================================
// LAYER 2: MAC
// ====================================================
S_L2_MAC: begin
    // Accumulate exactly one term for current (oo,hh)
    acc <= acc_use_next;

    // Debug for output 0 only
    if (oo == 4'd0) begin
        if (hh == 6'd0) begin
            dbg_w2_00      <= hs_use;        // REG7 = HW hs0
            dbg_partial4_o0  <= {{24{w2_use[7]}}, w2_use}; // REG6 = HW w2_used sign-extended to 32
            end
    end

    if (hh == H-1) begin
        // finished final h term
        state <= S_L2_FINISHO;
    end else begin
        // Issue next h and prime again
        hh <= hh + 6'd1;

        w2_en_r   <= 1'b1;
        w2_addr_r <= w2_index(oo, hh + 6'd1);

        // Prepare matching hidden_scaled for that next hh
        hscaled_q <= (hidden[hh + 6'd1] >>> SHIFT);

        state <= S_L2_WAIT;
    end
end



            // ====================================================
            // LAYER 2: FINISH output neuron (add bias, update argmax, next o)
            // ====================================================
            S_L2_FINISHO: begin
                // score = acc + b2[o]
                // update argmax
                // Capture HW logit for class 0 only (debug)
                if (oo == 4'd0) begin
                    dbg_acc0   <= acc[31:0];
                    dbg_b20    <= b2_q[31:0];
                    dbg_score0 <= score64[31:0];
                end

                // update argmax using the same score64
                if (score64 > best_val) begin
                    best_val <= score64;
                    best_idx <= oo;
                end

                if (oo < N_OUT-1) begin
                    // next output neuron
                    oo <= oo + 4'd1;
                    hh <= 6'd0;
                    acc <= 64'sd0;

                    w2_en_r   <= 1'b1;
                    w2_addr_r <= w2_index(oo + 4'd1, 6'd0);

                    b2_en_r   <= 1'b1;
                    b2_addr_r <= (oo + 4'd1);

                    hscaled_q <= (hidden[6'd0] >>> SHIFT);

                    state <= S_L2_WAIT;
                end else begin
                    predicted <= (score64 > best_val) ? oo : best_idx;
                    state <= S_DONE;
                end
            end

            // ====================================================
            // DONE: hold done high until start is deasserted
            // ====================================================
            S_DONE: begin
                b1_en_r <= 1'b0; w1_en_r <= 1'b0; w2_en_r <= 1'b0; b2_en_r <= 1'b0;

                if (!start) begin
                    state <= S_IDLE;
                end
            end

            default: state <= S_IDLE;

            endcase
        end
    end

endmodule
