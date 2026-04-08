module camera_preprocess_28x28(
    input clk,
    input start,
    output reg busy = 0,
    output reg done = 0,
    output reg [14:0] read_addr = 0,
    input [7:0] read_data,
    output reg pixel_valid = 0,
    output reg [9:0] pixel_index = 0,
    output reg [7:0] pixel_data = 0
);

localparam FRAME_W = 8'd160;
localparam FRAME_H = 7'd120;
localparam OUT_SIZE = 5'd28;
localparam INNER_SIZE = 5'd20;
localparam INNER_START = 5'd4;
localparam INNER_END = 5'd23;
localparam SCAN_THRESHOLD = 8'd95;
localparam OUTPUT_THRESHOLD = 8'd150;
localparam MIN_BOX_W = 8'd10;
localparam MIN_BOX_H = 7'd10;
localparam PAD = 8'd2;

localparam IDLE         = 4'd0;
localparam SCAN_ISSUE   = 4'd1;
localparam SCAN_WAIT    = 4'd2;
localparam SCAN_SAMPLE  = 4'd3;
localparam PREP_BOX     = 4'd4;
localparam SAMPLE_MUL   = 4'd5;
localparam SAMPLE_DIV   = 4'd6;
localparam SAMPLE_ADDR  = 4'd7;
localparam SAMPLE_WAIT  = 4'd8;
localparam SAMPLE_EMIT  = 4'd9;
localparam ADVANCE_OUT  = 4'd10;

reg [3:0] state = IDLE;

reg [7:0] scan_x = 0;
reg [6:0] scan_y = 0;
reg found_dark = 0;
reg [7:0] min_x = 0;
reg [7:0] max_x = 0;
reg [6:0] min_y = 0;
reg [6:0] max_y = 0;

reg valid_box = 0;
reg [7:0] box_x0 = 0;
reg [6:0] box_y0 = 0;
reg [7:0] box_size = 8'd1;

reg [4:0] out_x = 0;
reg [4:0] out_y = 0;

reg [4:0] inner_x = 0;
reg [4:0] inner_y = 0;
reg [7:0] box_size_minus_1 = 0;
reg [15:0] scaled_x_mul_reg = 0;
reg [15:0] scaled_y_mul_reg = 0;
reg [7:0] sample_x_reg = 0;
reg [6:0] sample_y_reg = 0;

wire scan_dark_pixel = (read_data < SCAN_THRESHOLD);
wire sample_dark_pixel = (read_data < OUTPUT_THRESHOLD);
wire [14:0] scan_addr = ({8'd0, scan_y} << 7) + ({8'd0, scan_y} << 5) + scan_x;
wire [8:0] sample_strength = sample_dark_pixel ? ((OUTPUT_THRESHOLD - read_data) << 1) : 9'd0;

reg [8:0] bbox_w = 0;
reg [7:0] bbox_h = 0;
reg [8:0] side_calc = 0;
reg [8:0] size_calc = 0;
reg signed [10:0] center_x = 0;
reg signed [10:0] center_y = 0;
reg signed [10:0] box_x_calc = 0;
reg signed [10:0] box_y_calc = 0;

always @(posedge clk) begin
    done <= 0;
    pixel_valid <= 0;

    case(state)
        IDLE: begin
            busy <= 0;
            if(start) begin
                busy <= 1;
                found_dark <= 0;
                valid_box <= 0;
                min_x <= FRAME_W - 1;
                max_x <= 0;
                min_y <= FRAME_H - 1;
                max_y <= 0;
                scan_x <= 0;
                scan_y <= 0;
                read_addr <= 0;
                state <= SCAN_ISSUE;
            end
        end

        SCAN_ISSUE: begin
            read_addr <= scan_addr;
            state <= SCAN_WAIT;
        end

        SCAN_WAIT: begin
            state <= SCAN_SAMPLE;
        end

        SCAN_SAMPLE: begin
            if(scan_dark_pixel) begin
                found_dark <= 1'b1;
                if(scan_x < min_x) min_x <= scan_x;
                if(scan_x > max_x) max_x <= scan_x;
                if(scan_y < min_y) min_y <= scan_y;
                if(scan_y > max_y) max_y <= scan_y;
            end

            if(scan_x == FRAME_W - 1) begin
                scan_x <= 0;
                if(scan_y == FRAME_H - 1) begin
                    state <= PREP_BOX;
                end else begin
                    scan_y <= scan_y + 1'b1;
                    state <= SCAN_ISSUE;
                end
            end else begin
                scan_x <= scan_x + 1'b1;
                state <= SCAN_ISSUE;
            end
        end

        PREP_BOX: begin
            if(found_dark && ((max_x - min_x + 1'b1) >= MIN_BOX_W) && ((max_y - min_y + 1'b1) >= MIN_BOX_H)) begin
                bbox_w = max_x - min_x + 1'b1;
                bbox_h = max_y - min_y + 1'b1;
                side_calc = (bbox_w > bbox_h) ? bbox_w : {1'b0, bbox_h};
                size_calc = side_calc + {1'b0, PAD, 1'b0};

                if(size_calc > FRAME_W)
                    size_calc = FRAME_W;
                if(size_calc > FRAME_H)
                    size_calc = FRAME_H;
                if(size_calc == 0)
                    size_calc = 1;

                center_x = ({3'd0, min_x} + {3'd0, max_x}) >>> 1;
                center_y = ({4'd0, min_y} + {4'd0, max_y}) >>> 1;

                box_x_calc = center_x - ($signed({2'd0, size_calc}) >>> 1);
                box_y_calc = center_y - ($signed({2'd0, size_calc}) >>> 1);

                if(box_x_calc < 0)
                    box_x_calc = 0;
                if(box_y_calc < 0)
                    box_y_calc = 0;
                if(box_x_calc + $signed({2'd0, size_calc}) > FRAME_W)
                    box_x_calc = FRAME_W - size_calc;
                if(box_y_calc + $signed({2'd0, size_calc}) > FRAME_H)
                    box_y_calc = FRAME_H - size_calc;

                box_x0 <= box_x_calc[7:0];
                box_y0 <= box_y_calc[6:0];
                box_size <= size_calc[7:0];
                box_size_minus_1 <= (size_calc > 0) ? (size_calc[7:0] - 1'b1) : 8'd0;
                valid_box <= 1'b1;
            end else begin
                box_x0 <= 0;
                box_y0 <= 0;
                box_size <= 8'd1;
                box_size_minus_1 <= 0;
                valid_box <= 1'b0;
            end

            out_x <= 0;
            out_y <= 0;
            state <= SAMPLE_MUL;
        end

        SAMPLE_MUL: begin
            if(valid_box && (out_x >= INNER_START) && (out_x <= INNER_END) &&
               (out_y >= INNER_START) && (out_y <= INNER_END)) begin
                inner_x <= out_x - INNER_START;
                inner_y <= out_y - INNER_START;
                scaled_x_mul_reg <= (out_x - INNER_START) * box_size_minus_1;
                scaled_y_mul_reg <= (out_y - INNER_START) * box_size_minus_1;
            end
            state <= SAMPLE_DIV;
        end

        SAMPLE_DIV: begin
            if(valid_box && (out_x >= INNER_START) && (out_x <= INNER_END) &&
               (out_y >= INNER_START) && (out_y <= INNER_END)) begin
                sample_x_reg <= box_x0 + (scaled_x_mul_reg / 16'd19);
                sample_y_reg <= box_y0 + (scaled_y_mul_reg / 16'd19);
            end
            state <= SAMPLE_ADDR;
        end

        SAMPLE_ADDR: begin
            if(valid_box && (out_x >= INNER_START) && (out_x <= INNER_END) &&
               (out_y >= INNER_START) && (out_y <= INNER_END)) begin
                read_addr <= ({8'd0, sample_y_reg} << 7) + ({8'd0, sample_y_reg} << 5) + sample_x_reg;
            end
            state <= SAMPLE_WAIT;
        end

        SAMPLE_WAIT: begin
            state <= SAMPLE_EMIT;
        end

        SAMPLE_EMIT: begin
            pixel_valid <= 1'b1;
            pixel_index <= (out_y * 6'd28) + out_x;

            if(valid_box && (out_x >= INNER_START) && (out_x <= INNER_END) &&
               (out_y >= INNER_START) && (out_y <= INNER_END)) begin
                pixel_data <= sample_strength[8] ? 8'hFF : sample_strength[7:0];
            end else begin
                pixel_data <= 8'd0;
            end

            state <= ADVANCE_OUT;
        end

        ADVANCE_OUT: begin
            if(out_x == OUT_SIZE - 1) begin
                out_x <= 0;
                if(out_y == OUT_SIZE - 1) begin
                    out_y <= 0;
                    busy <= 0;
                    done <= 1'b1;
                    state <= IDLE;
                end else begin
                    out_y <= out_y + 1'b1;
                    state <= SAMPLE_MUL;
                end
            end else begin
                out_x <= out_x + 1'b1;
                state <= SAMPLE_MUL;
            end
        end

        default: begin
            state <= IDLE;
        end
    endcase
end

endmodule
