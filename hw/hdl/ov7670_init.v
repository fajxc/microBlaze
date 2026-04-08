module ov7670_init(
    input clk,
    input start,
    output reg done,
    output reg i2c_start,
    output reg [7:0] reg_addr,
    output reg [7:0] reg_data,
    input i2c_done
);

reg [5:0] index = 0;
reg busy = 0;

reg [15:0] rom [0:11];

reg [18:0] delay_cnt = 0;
reg delay_active = 0;

parameter DELAY_MAX = 19'd2500;
localparam ROM_LAST = 11;

initial begin
    rom[0]  = 16'h1280; // COM7: reset
    rom[1]  = 16'h1204; // COM7: RGB output
    rom[2]  = 16'h40D0; // COM15: RGB565 full range
    rom[3]  = 16'h3D00; // COM13: disable color bar

    // Low-light profile: allow AEC/AGC/AWB, reduce pixel clock for longer exposure,
    // and keep gain ceiling moderate to avoid excessive noise.
    rom[4]  = 16'h13E7; // COM8: FASTAEC + AEC + AGC + AWB
    rom[5]  = 16'h1103; // CLKRC: divide internal clock (lower fps, better low-light)
    rom[6]  = 16'h1438; // COM9: moderate AGC gain ceiling (less grain than max gain)

    // Image tone tuning for handwritten digits.
    rom[7]  = 16'h5520; // BRIGHT
    rom[8]  = 16'h5660; // CONTRAS

    // Slightly tighter UV saturation to reduce chroma noise leaking into gray conversion.
    rom[9]  = 16'h4F80; // MTX1
    rom[10] = 16'h5080; // MTX2
    rom[11] = 16'h5180; // MTX3
end

always @(posedge clk) begin
    if(start && !busy && !done) begin
        busy <= 1;
        index <= 0;
        done <= 0;
        i2c_start <= 0;
        delay_active <= 0;
    end

    if(busy && !i2c_start && !delay_active) begin
        reg_addr <= rom[index][15:8];
        reg_data <= rom[index][7:0];
        i2c_start <= 1;
    end

    if(i2c_done) begin
        i2c_start <= 0;
        if(index == 0) begin
            delay_active <= 1;
            delay_cnt <= 0;
        end
        else if(index == ROM_LAST) begin
            busy <= 0;
            done <= 1;
        end
        else begin
            index <= index + 1;
        end
    end

    if(delay_active) begin
        if(delay_cnt < DELAY_MAX) begin
            delay_cnt <= delay_cnt + 1;
        end
        else begin
            delay_active <= 0;
            index <= 1;
        end
    end
end

endmodule
