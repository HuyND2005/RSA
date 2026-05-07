`timescale 1ns / 1ps

module ModExp(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    input  wire [1023:0] base_in,  // Bản mã / Bản rõ (A)
    input  wire [1023:0] exp_in,   // Khóa (B)
    input  wire [1023:0] mod_in,   // Module (N)
    input  wire [1023:0] r2_mod_n, // Hằng số R^2 mod N (tính sẵn từ phần mềm)
    
    output reg  [1023:0] result,
    output reg           done
);

    // --- Khai báo các trạng thái (FSM) ---
    localparam IDLE         = 4'd0;
    localparam CALC_A_BAR   = 4'd1;  // Tính A_bar = Mont(A, R^2)
    localparam WAIT_A_BAR   = 4'd2;
    localparam CALC_RES_BAR = 4'd3;  // Tính Res_bar = Mont(1, R^2)
    localparam WAIT_RES_BAR = 4'd4;
    localparam LOOP_CHECK   = 4'd5;  // Kiểm tra bit của số mũ
    localparam SQUARE       = 4'd6;  // Bình phương: Res_bar = Mont(Res_bar, Res_bar)
    localparam WAIT_SQUARE  = 4'd7;
    localparam MULTIPLY     = 4'd8;  // Nhân: Res_bar = Mont(Res_bar, A_bar)
    localparam WAIT_MULT    = 4'd9;
    localparam POST_CALC    = 4'd10; // Đưa về số thường: Result = Mont(Res_bar, 1)
    localparam WAIT_POST    = 4'd11;
    localparam DONE         = 4'd12;

    reg [3:0] state;

    // --- Các thanh ghi lưu trữ nội bộ ---
    reg [1023:0] a_bar;
    reg [1023:0] res_bar;
    reg [1023:0] exp_reg;
    reg [1023:0] mod_reg;
    reg [10:0]   bit_idx;  // Đếm từ 1023 lùi về 0 (dùng 11 bit để chứa giá trị âm khi thoát lặp)

    // --- Dây tín hiệu giao tiếp với Module 1 (Montgomery Multiplier) ---
    reg           mul_start;
    reg  [1023:0] mul_a;
    reg  [1023:0] mul_b;
    wire [1023:0] mul_result;
    wire          mul_done;

    // Gọi (Instantiate) Module 1 đã thiết kế trước đó
    MontgomeryMul u_multiplier (
        .clk   (clk),
        .rst_n (rst_n),
        .start (mul_start),
        .a     (mul_a),
        .b     (mul_b),
        .m     (mod_reg),     // Module không đổi trong suốt quá trình
        .result(mul_result),
        .done  (mul_done)
    );

    // --- Máy trạng thái điều khiển (Controller FSM) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            mul_start   <= 1'b0;
            done        <= 1'b0;
            bit_idx     <= 11'd1023; // Bắt đầu quét từ bit cao nhất (MSB)
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        exp_reg <= exp_in;
                        mod_reg <= mod_in;
                        state   <= CALC_A_BAR;
                    end
                end

                // --- 1. Chuyển A vào miền Montgomery ---
                CALC_A_BAR: begin
                    mul_a     <= base_in;
                    mul_b     <= r2_mod_n;
                    mul_start <= 1'b1;     // Cấp xung start cho Khối nhân
                    state     <= WAIT_A_BAR;
                end
                WAIT_A_BAR: begin
                    mul_start <= 1'b0;     // Tắt xung start
                    if (mul_done) begin
                        a_bar <= mul_result; // Lưu lại A_bar
                        state <= CALC_RES_BAR;
                    end
                end

                // --- 2. Khởi tạo Result = 1 trong miền Montgomery ---
                CALC_RES_BAR: begin
                    mul_a     <= 1024'd1;
                    mul_b     <= r2_mod_n;
                    mul_start <= 1'b1;
                    state     <= WAIT_RES_BAR;
                end
                WAIT_RES_BAR: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        res_bar <= mul_result; // Lưu lại Res_bar (thực chất bằng R mod N)
                        bit_idx <= 11'd1023;   // Đặt lại bộ đếm để quét bit
                        state   <= LOOP_CHECK;
                    end
                end

                // --- 3. Vòng lặp duyệt từng bit của khóa (Bình phương & Nhân) ---
                LOOP_CHECK: begin
                    // Nếu bộ đếm cuộn vòng qua 0 (thành số âm/giá trị lớn trên 11 bit)
                    // Hoặc đơn giản là if (bit_idx == 11'h7FF)
                    if (bit_idx[10] == 1'b1) begin 
                        state <= POST_CALC; // Đã quét hết bit, thoát vòng lặp
                    end else begin
                        state <= SQUARE;    // Luôn luôn thực hiện Bình phương
                    end
                end

                SQUARE: begin
                    mul_a     <= res_bar;
                    mul_b     <= res_bar;
                    mul_start <= 1'b1;
                    state     <= WAIT_SQUARE;
                end
                WAIT_SQUARE: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        res_bar <= mul_result;
                        // Kiểm tra xem bit hiện tại của khóa có bằng 1 không?
                        if (exp_reg[bit_idx] == 1'b1) begin
                            state <= MULTIPLY; // Bit = 1 -> Thực hiện Nhân
                        end else begin
                            bit_idx <= bit_idx - 1'b1; // Bit = 0 -> Bỏ qua Nhân, giảm index
                            state   <= LOOP_CHECK;
                        end
                    end
                end

                MULTIPLY: begin
                    mul_a     <= res_bar;
                    mul_b     <= a_bar;
                    mul_start <= 1'b1;
                    state     <= WAIT_MULT;
                end
                WAIT_MULT: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        res_bar <= mul_result;
                        bit_idx <= bit_idx - 1'b1; // Giảm index để xét bit tiếp theo
                        state   <= LOOP_CHECK;
                    end
                end

                // --- 4. Thoát khỏi miền Montgomery ---
                POST_CALC: begin
                    mul_a     <= res_bar;
                    mul_b     <= 1024'd1;     // Nhân với 1
                    mul_start <= 1'b1;
                    state     <= WAIT_POST;
                end
                WAIT_POST: begin
                    mul_start <= 1'b0;
                    if (mul_done) begin
                        result <= mul_result; // Kết quả cuối cùng!
                        state  <= DONE;
                    end
                end

                DONE: begin
                    done  <= 1'b1;
                    state <= IDLE; // Quay về chờ chu kỳ tính toán mới
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule