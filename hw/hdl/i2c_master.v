module i2c_master(
    input clk,
    input start,
    input [7:0] reg_addr,
    input [7:0] reg_data,
    output reg done,
    inout sda,
    output reg scl
);

parameter CLK_DIV = 250;

reg [15:0] clk_cnt = 0;
reg tick = 0;

always @(posedge clk) begin
    if(clk_cnt == CLK_DIV) begin
        clk_cnt <= 0;
        tick <= 1;
    end else begin
        clk_cnt <= clk_cnt + 1;
        tick <= 0;
    end
end

reg sda_out = 1;
assign sda = sda_out ? 1'bz : 0;

reg [5:0] state = 0;
reg [3:0] bit_cnt;
reg [7:0] shift_reg;

always @(posedge clk) begin

if(tick) begin

case(state)

0: begin
    done <= 0;
    scl <= 1;
    sda_out <= 1;
    if(start) state <= 1;
end

1: begin // START
    sda_out <= 0;
    state <= 2;
    shift_reg <= 8'h42;
    bit_cnt <= 7;
end

2: begin // send device address
    scl <= 0;
    sda_out <= shift_reg[bit_cnt];
    state <= 3;
end

3: begin
    scl <= 1;
    if(bit_cnt == 0) state <= 4;
    else begin
        bit_cnt <= bit_cnt - 1;
        state <= 2;
    end
end

4: begin // send reg addr
    scl <= 0;
    shift_reg <= reg_addr;
    bit_cnt <= 7;
    state <= 5;
end

5: begin
    sda_out <= shift_reg[bit_cnt];
    scl <= 1;
    if(bit_cnt == 0) state <= 6;
    else bit_cnt <= bit_cnt - 1;
end

6: begin // send reg data
    scl <= 0;
    shift_reg <= reg_data;
    bit_cnt <= 7;
    state <= 7;
end

7: begin
    sda_out <= shift_reg[bit_cnt];
    scl <= 1;
    if(bit_cnt == 0) state <= 8;
    else bit_cnt <= bit_cnt - 1;
end

8: begin // STOP
    scl <= 1;
    sda_out <= 1;
    done <= 1;
    state <= 0;
end

endcase
end
end

endmodule





//module i2c_master(
//    input clk,
//    input start,
//    input [7:0] reg_addr,
//    input [7:0] reg_data,
//    output reg done,
//    inout sda,
//    output scl
//);

//parameter CLK_DIV = 250;

//reg [15:0] clk_count = 0;
//reg scl_reg = 1;
//assign scl = scl_reg;

//reg sda_reg = 1;
//assign sda = sda_reg ? 1'bz : 0;

//reg [5:0] state = 0;
//reg [7:0] shift_reg;
//reg [3:0] bit_cnt;

//always @(posedge clk) begin

//    if(clk_count == CLK_DIV) begin
//        clk_count <= 0;
//        scl_reg <= ~scl_reg;
//    end else
//        clk_count <= clk_count + 1;

//    if(start && state == 0) begin
//        state <= 1;
//        done <= 0;
//    end

//    if(scl_reg == 0 && clk_count == 0) begin
//        case(state)

//        1: begin // START
//            sda_reg <= 0;
//            state <= 2;
//            shift_reg <= 8'h42; // device addr
//            bit_cnt <= 7;
//        end

//        2: begin
//            sda_reg <= shift_reg[bit_cnt];
//            if(bit_cnt == 0) state <= 3;
//            else bit_cnt <= bit_cnt - 1;
//        end

//        3: begin
//            shift_reg <= reg_addr;
//            bit_cnt <= 7;
//            state <= 4;
//        end

//        4: begin
//            sda_reg <= shift_reg[bit_cnt];
//            if(bit_cnt == 0) state <= 5;
//            else bit_cnt <= bit_cnt - 1;
//        end

//        5: begin
//            shift_reg <= reg_data;
//            bit_cnt <= 7;
//            state <= 6;
//        end

//        6: begin
//            sda_reg <= shift_reg[bit_cnt];
//            if(bit_cnt == 0) state <= 7;
//            else bit_cnt <= bit_cnt - 1;
//        end

//        7: begin // STOP
//            sda_reg <= 1;
//            state <= 0;
//            done <= 1;
//        end

//        endcase
//    end
//end

//endmodule