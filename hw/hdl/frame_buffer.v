module frame_buffer(
    input clk,
    input [7:0] pixel,
    input pixel_valid,
    input write_reset,
    input [14:0] read_addr,
    output reg [7:0] read_data,
    input [14:0] read_addr_b,
    output reg [7:0] read_data_b
);

parameter SIZE = 19200;

reg [7:0] mem [0:SIZE-1];
reg [14:0] write_addr = 0;

always @(posedge clk) begin
    if(write_reset) begin
        write_addr <= 0;
    end

    if(pixel_valid && write_addr < SIZE) begin
        mem[write_addr] <= pixel;
        write_addr <= write_addr + 1;
    end

    if(read_addr < SIZE) begin
        read_data <= mem[read_addr];
    end
    else begin
        read_data <= 8'd0;
    end

    if(read_addr_b < SIZE) begin
        read_data_b <= mem[read_addr_b];
    end
    else begin
        read_data_b <= 8'd0;
    end
end

endmodule
