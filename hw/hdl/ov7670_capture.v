module ov7670_capture(
    input pclk,
    input vsync,
    input href,
    input [7:0] data,
    output reg [7:0] pixel,
    output reg pixel_valid
);

// OV7670 is configured for RGB565. Convert each sampled RGB565 pixel to
// an 8-bit grayscale estimate using the 6-bit green channel.
// Downsample by 4x in both axes -> 160x120 from 640x480 timing.
reg [9:0] x = 0;
reg [8:0] y = 0;
reg href_d = 0;
reg byte_toggle = 0;
reg [7:0] byte1 = 0;
reg [5:0] g6;

always @(posedge pclk) begin
    pixel_valid <= 0;
    href_d <= href;

    if(vsync) begin
        x <= 0;
        y <= 0;
        byte_toggle <= 0;
    end
    else if(!href) begin
        byte_toggle <= 0;
        x <= 0;

        if(href_d && y < 479) begin
            y <= y + 1;
        end
    end
    else begin
        byte_toggle <= ~byte_toggle;

        if(!byte_toggle) begin
            byte1 <= data;
        end
        else begin
            if((x[1:0] == 2'b00) && (y[1:0] == 2'b00)) begin
                // RGB565:
                //   byte1 = RRRRRGGG
                //   data  = GGGBBBBB
                // Use green channel as grayscale proxy.
                g6 = {byte1[2:0], data[7:5]};
                pixel <= {g6, g6[5:4]};
                pixel_valid <= 1;
            end

            if(x < 639) begin
                x <= x + 1;
            end
        end
    end
end

endmodule
