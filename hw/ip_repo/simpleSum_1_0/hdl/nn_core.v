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

    // result
    output reg  [3:0]  predicted
);

    // ------------------------------------------------------------
    // Pixel buffer (simple internal memory)
    // ------------------------------------------------------------
    reg [7:0] x_mem [0:N_IN-1];

    always @(posedge clk) begin
        if (rst) begin
            // no need to clear x_mem for this test
        end else if (pix_we) begin
            if (pix_addr < N_IN)
                x_mem[pix_addr] <= pix_data;
        end
    end
    
// ------------------------------------------------------------
// Weight and bias memories (loaded at bitstream time)
// ------------------------------------------------------------
reg signed [7:0]  w1_flat [0:32*784-1];
reg signed [7:0]  w2_flat [0:10*32-1];
reg signed [31:0] b1 [0:31];
reg signed [31:0] b2 [0:9];

initial begin
    $readmemh("src/w1.mem", w1_flat);
    $readmemh("src/w2.mem", w2_flat);
    $readmemh("src/b1.mem", b1);
    $readmemh("src/b2.mem", b2);
end
always @(posedge clk) begin
    if (rst) begin
        predicted <= 0;
        done <= 0;
    end else if (start) begin
        predicted <= 4'hF; // read real bias from mem
        done <= 1;
    end else begin
        done <= 0;
    end
end


endmodule
