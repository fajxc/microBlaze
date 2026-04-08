module uart_rx(
    input clk,
    input rx,
    output reg [7:0] data = 0,
    output reg valid = 0
);

parameter CLKS_PER_BIT = 868;
localparam HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;

reg [1:0] state = 0;
reg [15:0] clk_count = 0;
reg [2:0] bit_index = 0;
reg [7:0] shift_reg = 0;

localparam RX_IDLE  = 2'd0;
localparam RX_START = 2'd1;
localparam RX_DATA  = 2'd2;
localparam RX_STOP  = 2'd3;

always @(posedge clk) begin
    valid <= 0;

    case(state)
        RX_IDLE: begin
            clk_count <= 0;
            bit_index <= 0;
            if(!rx) begin
                state <= RX_START;
            end
        end

        RX_START: begin
            if(clk_count == HALF_CLKS_PER_BIT) begin
                clk_count <= 0;
                if(!rx) begin
                    state <= RX_DATA;
                end
                else begin
                    state <= RX_IDLE;
                end
            end
            else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        RX_DATA: begin
            if(clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 0;
                shift_reg[bit_index] <= rx;
                if(bit_index == 3'd7) begin
                    bit_index <= 0;
                    state <= RX_STOP;
                end
                else begin
                    bit_index <= bit_index + 1'b1;
                end
            end
            else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        RX_STOP: begin
            if(clk_count == CLKS_PER_BIT-1) begin
                clk_count <= 0;
                data <= shift_reg;
                valid <= 1;
                state <= RX_IDLE;
            end
            else begin
                clk_count <= clk_count + 1'b1;
            end
        end

        default: state <= RX_IDLE;
    endcase
end

endmodule
