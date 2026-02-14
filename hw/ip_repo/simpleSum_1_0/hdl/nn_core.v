`timescale 1ns / 1ps

module nn_core #(
    parameter integer N_IN  = 784,
    parameter integer N_OUT = 10
)(
    input  wire        clk,
    input  wire        rst,

    // control
    input  wire        start,
    output reg         done,

    // pixel write port from AXI regs
    input  wire        pix_we,
    input  wire [9:0]  pix_addr,   // 0..783
    input  wire [7:0]  pix_data,   // 0..255

    // b1: 32-bit, depth 32
    output wire        b1_en,
    output wire [4:0]  b1_addr,
    input  wire [31:0] b1_dout,

    // w1: 8-bit, depth 25088
    output wire        w1_en,
    output wire [14:0] w1_addr,
    input  wire [7:0]  w1_dout,

    // w2: 8-bit, depth 320
    output wire        w2_en,
    output wire [8:0]  w2_addr,
    input  wire [7:0]  w2_dout,

    // b2: 32-bit, depth 10
    output wire        b2_en,
    output wire [3:0]  b2_addr,
    input  wire [31:0] b2_dout,

    // result
    output reg  [3:0]  predicted
);

    // ------------------------------------------------------------
    // Pixel buffer (unused for this test, but kept)
    // ------------------------------------------------------------
    reg [7:0] x_mem [0:N_IN-1];

    always @(posedge clk) begin
        if (!rst && pix_we) begin
            if (pix_addr < N_IN)
                x_mem[pix_addr] <= pix_data;
        end
    end

    // ------------------------------------------------------------
    // For this test: always read address 0 from each ROM
    // ------------------------------------------------------------
    assign b1_en   = 1'b1;
    assign b1_addr = 5'd0;

    assign b2_en   = 1'b1;
    assign b2_addr = 4'd0;

    assign w1_en   = 1'b1;
    assign w1_addr = 15'd0;

    assign w2_en   = 1'b1;
    assign w2_addr = 9'd0;

    // ------------------------------------------------------------
    // Cycle which memory we report on each start
    // 0: b1, 1: b2, 2: w1, 3: w2
    // ------------------------------------------------------------
    reg [1:0] which;
    reg start_d;

    always @(posedge clk) begin
        if (rst) begin
            predicted <= 4'd0;
            done      <= 1'b0;
            start_d   <= 1'b0;
            which     <= 2'd0;
        end else begin
            done    <= 1'b0;
            start_d <= start;

            // advance selection on each start assertion
            if (start) begin
                which <= which + 2'd1;
            end

            // 1 cycle after start, BRAM data should be valid
            if (start_d) begin
                case (which)
                    2'd0: predicted <= b1_dout[3:0];
                    2'd1: predicted <= b2_dout[3:0];
                    2'd2: predicted <= w1_dout[3:0];
                    2'd3: predicted <= w2_dout[3:0];
                    default: predicted <= 4'd0;
                endcase
                done <= 1'b1;
            end
        end
    end

endmodule
