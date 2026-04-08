module clock_gen(
    input clk100,
    output reg clk12 = 0
);

reg [2:0] counter = 0;

always @(posedge clk100) begin
    counter <= counter + 1;
    if(counter == 3) begin
        clk12 <= ~clk12;
        counter <= 0;
    end
end

endmodule