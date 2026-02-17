`timescale 1ns / 1ps

module nn_core #(
    parameter integer N_IN  = 784,
    parameter integer N_OUT = 10,
    parameter integer H     = 32,
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

    output reg  [3:0]  predicted
);

    // ============================================================
    // Pixel buffer
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
    // 1-cycle ROM pipeline
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
    // Storage
    // ============================================================
    reg signed [63:0] a1 [0:H-1];
    
    reg signed [63:0] acc;

    reg [9:0] i;
    reg [5:0] j;
    reg [3:0] k;

    reg signed [63:0] best_val;
    reg [3:0] best_idx;

    reg start_d;
    wire start_pulse = start & ~start_d;

    always @(posedge clk) begin
        if (rst) start_d <= 1'b0;
        else     start_d <= start;
    end

    // ============================================================
    // Address helpers
    // ============================================================
    function [14:0] w1_index;
        input [5:0] jj;
        input [9:0] ii;
        begin
            w1_index = jj * 15'd784 + ii;
        end
    endfunction

    function [8:0] w2_index;
        input [3:0] kk;
        input [5:0] jj;
        begin
            w2_index = kk * 9'd32 + jj[4:0];
        end
    endfunction

    reg [7:0]         x_prev;
    reg signed [31:0] a1s_prev;

    wire signed [15:0] mul_w1x = $signed(w1_q) * $signed({1'b0, x_prev});
    wire signed [39:0] mul_w2a = $signed(w2_q) * $signed(a1s_prev);

    wire signed [63:0] score_k = acc + $signed(b2_q);

    wire better_k = (score_k > best_val);
    wire signed [63:0] best_val_next = better_k ? score_k : best_val;
    wire [3:0] best_idx_next = better_k ? k : best_idx;

    // ============================================================
    // FSM
    // ============================================================
    localparam S_IDLE       = 4'd0,
               S_L1_PRIME   = 4'd1,
               S_L1_MAC     = 4'd2,
               S_L1_STORE   = 4'd3,
               S_L2_PRIME   = 4'd4,
               S_L2_MAC     = 4'd5,
               S_L2_FINISHK = 4'd6,
               S_DONE       = 4'd7;

    reg [3:0] state;
    integer t;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            done  <= 1'b0;
            predicted <= 4'd0;

            // IMPORTANT: default ROM enables OFF at reset, we turn ON when starting
            b1_en_r <= 1'b0; 
            w1_en_r <= 1'b0;
            w2_en_r <= 1'b0;
            b2_en_r <= 1'b0;
            
            b1_addr_r <= 5'd0;
            w1_addr_r <= 15'd0;
            w2_addr_r <= 9'd0;
            b2_addr_r <= 4'd0;

            i <= 10'd0;
            j <= 10'd0;
            k <= 10'd0;
            
            acc <= 64'sd0;
            
            best_val <= -64'sd9223372036854775807;
            best_idx <= 4'd0;
            
            x_prev <= 8'd0;
            a1s_prev <= 32'sd0;

            for (t=0; t<H; t=t+1)
                a1[t] <= 64'sd0;

        end else begin
            done <= 1'b0;

            case (state)

            // ================= IDLE =================
            S_IDLE: begin
             b1_en_r <= 1'b0;
             w1_en_r <= 1'b0; 
             w2_en_r <= 1'b0; 
             b2_en_r <= 1'b0;
                if (start_pulse) begin
                    j <= 6'd0;
                    i <= 10'd0;
                    acc <= 64'sd0;

                    // Enable L1 ROMs
                    b1_en_r <= 1;
                    b1_addr_r <= 5'd0;
                    
                    w1_en_r <= 1'b1;
                    w1_addr_r <= w1_index(6'd0, 10'd0);

                 
                    x_prev    <= x_mem[10'd0];

                    state <= S_L1_PRIME;
                end
            end

            // ================= L1 PRIME =================
            S_L1_PRIME: begin
                b1_en_r <= 1'b1; 
                b1_addr_r <= j[4:0];
                state <= S_L1_MAC;
            end

            // ================= L1 MAC =================
            S_L1_MAC: begin
                b1_en_r <= 1'b1; 
                b1_addr_r <= j[4:0];
                
                acc <= acc + $signed({{48{mul_w1x[15]}}, mul_w1x});

                if (i < N_IN-1) begin
                    i <= i + 10'd1;
                    w1_addr_r <= w1_index(j, i+10'd1);
                    x_prev <= x_mem[i+10'd1];
                end else begin
                    state <= S_L1_STORE;
                end
            end

            // ================= L1 STORE =================
            S_L1_STORE: begin
                if ((acc + $signed(b1_q)) > 0) 
                a1[j] <= (acc + $signed(b1_q)); 
                else 
                a1[j] <= 64'sd0;

                if (j < H-1) begin
                    j <= j + 6'd1;
                    i <= 10'd0;
                    acc <= 64'sd0;
                    
                    b1_en_r <= 1'b1; 
                    b1_addr_r <= j[4:0] + 5'd1;
                    
                    w1_en_r <= 1'b1; 
                    w1_addr_r <= w1_index(j + 6'd1, 10'd0); 
                    x_prev <= x_mem[10'd0];


                    state <= S_L1_PRIME;
                end else begin
                    //start layer 2
                    k <= 4'd0; 
                    j <= 6'd0; 
                    acc <= 64'sd0;

                    best_val <= -64'sd9223372036854775807;
                    best_idx <= 0;

                    b2_en_r <= 1'b1; 
                    b2_addr_r <= 4'd0;

                    w2_en_r <= 1'b1; 
                    w2_addr_r <= w2_index(4'd0, 6'd0);
                    
                    a1s_prev <= a1[6'd0] >>> SHIFT;

                    state <= S_L2_PRIME;
                end
            end

            // ================= L2 PRIME =================
            S_L2_PRIME: begin
            b2_en_r <= 1'b1; 
            b2_addr_r <= k;
                state <= S_L2_MAC;
            end

            // ================= L2 MAC =================
            S_L2_MAC: begin
            b2_en_r <= 1'b1; 
            b2_addr_r <= k;
                
                acc <= acc + $signed({{24{mul_w2a[39]}}, mul_w2a});

                if (j < (H-1)) begin
                    j <= j + 6'd1;
                    w2_en_r <= 1'b1; 
                    w2_addr_r <= w2_index(k, j + 6'd1); 
                    a1s_prev <= a1[j + 6'd1] >>> SHIFT;
                end else begin
                    state <= S_L2_FINISHK;
                end
            end

            // ================= ARGMAX =================
            S_L2_FINISHK: begin
                best_val <= best_val_next;
                best_idx <= best_idx_next;

                if (k < N_OUT-1) begin
                    k <= k + 4'd1;
                    j <= 6'd0;
                    acc <= 64'sd0;

                    b2_en_r <= 1'b1; 
                    b2_addr_r <= k + 4'd1; 
                    
                    w2_en_r <= 1'b1; 
                    w2_addr_r <= w2_index(k + 4'd1, 6'd0);
                     
                    a1s_prev <= a1[6'd0] >>> SHIFT; 
                    
                    state <= S_L2_PRIME;
                    
                end else begin
                    predicted <= best_idx_next;
                    done <= 1'b1;
                    state <= S_DONE;
                end
            end

            S_DONE: begin
                done <= 1'b1; 
                b1_en_r <= 1'b0; 
                w1_en_r <= 1'b0; 
                w2_en_r <= 1'b0; 
                b2_en_r <= 1'b0; 
                if (!start) begin 
                done <= 1'b0; 
                state <= S_IDLE;
            end
            end
default: state <= S_IDLE;
            endcase
        end
    end

endmodule
