module uart_tx(
    input clk,
    input start,
    input [7:0] data,
    output reg tx = 1,
    output reg busy = 0
);

parameter CLKS_PER_BIT = 868;

reg [3:0] bit_index = 0;
reg [15:0] clk_count = 0;
reg [9:0] shift_reg;

always @(posedge clk) begin
    if(start && !busy) begin
        busy <= 1;
        shift_reg <= {1'b1, data, 1'b0};
        bit_index <= 0;
        clk_count <= 0;
        tx <= 1'b0;
    end
    else if(busy) begin
        if(clk_count < CLKS_PER_BIT-1) begin
            clk_count <= clk_count + 1'b1;
        end
        else begin
            clk_count <= 0;
            if(bit_index == 4'd8) begin
                tx <= 1'b1;
                bit_index <= bit_index + 1'b1;
            end
            else if(bit_index == 4'd9) begin
                tx <= 1'b1;
                busy <= 0;
                bit_index <= 0;
            end
            else begin
                bit_index <= bit_index + 1'b1;
                tx <= shift_reg[bit_index + 1'b1];
            end
        end
    end
end

endmodule
