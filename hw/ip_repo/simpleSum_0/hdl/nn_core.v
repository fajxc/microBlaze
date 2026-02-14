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

    // ---- BD-provided b1 ROM interface ----
    output wire        b1_en,
    output wire [4:0]  b1_addr,
    input  wire [31:0] b1_dout,

    // result
    output reg  [3:0]  predicted
);

    reg [7:0] x_mem [0:N_IN-1];

    always @(posedge clk) begin
        if (!rst && pix_we) begin
            if (pix_addr < N_IN)
                x_mem[pix_addr] <= pix_data;
        end
    end

    assign b1_en   = 1'b1;
    assign b1_addr = 5'd0;

    reg start_d;

    always @(posedge clk) begin
        if (rst) begin
            predicted <= 4'd0;
            done      <= 1'b0;
            start_d   <= 1'b0;
        end else begin
            done    <= 1'b0;
            start_d <= start;

            if (start_d) begin
                predicted <= b1_dout[3:0];
                done      <= 1'b1;
            end
        end
    end

endmodule
