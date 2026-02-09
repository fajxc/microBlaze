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
    // Simple "compute" FSM
    // - When start goes high: wait a little, then output predicted
    // - predicted is just the low 4 bits of pixel 0
    // - done stays high until start goes low (re-arm)
    // ------------------------------------------------------------
    localparam S_IDLE = 2'd0;
    localparam S_WAIT = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg [7:0] wait_ctr;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            done      <= 1'b0;
            predicted <= 4'd0;
            wait_ctr  <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done     <= 1'b0;
                    wait_ctr <= 8'd0;
                    if (start) begin
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    // just burn some cycles so you can see it isn't instant
                    wait_ctr <= wait_ctr + 1;
                    if (wait_ctr == 8'd50) begin
                        predicted <= x_mem[0][3:0]; // show pixel0 low nibble
                        done      <= 1'b1;
                        state     <= S_DONE;
                    end
                end

                S_DONE: begin
                    // hold done until start drops (so SW can re-run)
                    if (!start) begin
                        done  <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
