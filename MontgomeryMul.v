module MontgomeryMul(
    input  wire          clk,
    input  wire          rst_n,    // Reset tích c?c m?c th?p
    input  wire          start,    // Tín hi?u b?t ??u tính toán
    input  wire [1023:0] a,        // Toán h?ng A
    input  wire [1023:0] b,        // Toán h?ng B
    input  wire [1023:0] m,        // Module M
    output reg  [1023:0] result,   // K?t qu?
    output reg           done      // C? báo hoàn thành
);

    // --- Khai báo FSM States ---
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_CALC_INIT  = 3'd1;
    localparam STATE_CALC_ADD   = 3'd2;
    localparam STATE_CALC_SHIFT = 3'd3;
    localparam STATE_NORM_INIT  = 3'd4;
    localparam STATE_NORM_SUB   = 3'd5;
    localparam STATE_DONE       = 3'd6;

    reg [2:0] state;

    // --- Khai báo thanh ghi ?? r?ng 1056-bit (33 chu k? x 32 bit) ---
    reg [1055:0] S;
    reg [1055:0] S_sub;    // Thanh ghi t?m l?u k?t qu? c?a S - M
    reg [1055:0] A_reg;
    reg [1055:0] B_reg;
    reg [1055:0] M_reg;

    reg [10:0] count;      // B? ??m vòng l?p chính (1 ??n 1024)
    reg [5:0]  word_idx;   // B? ??m chu k? x? lý t? 32-bit (0 ??n 32)

    reg       a_i;
    reg       q_i;
    reg [1:0] carry;       // C? nh? phép c?ng (c?ng 3 toán h?ng có th? d? 2 bit)
    reg       borrow;      // C? m??n phép tr?

    // --- Kh?i t? h?p (Combinational Logic) x? lý 32-bit m?i chu k? ---
    wire [31:0] current_s = S[31:0]; // Luôn l?y 32 bit th?p nh?t do ?ã d?ch xoay vòng
    
    // 1. Phép tính C?NG (CALC_ADD)
    wire [31:0] current_b = a_i ? B_reg[31:0] : 32'd0;
    wire [31:0] current_m = q_i ? M_reg[31:0] : 32'd0;
    wire [33:0] word_sum  = current_s + current_b + current_m + carry;

    // 2. Phép tính TR? (NORM_SUB)
    wire [31:0] norm_m    = M_reg[31:0]; 
    wire [32:0] word_sub  = current_s - norm_m - borrow;

    // --- Kh?i tu?n t? (Sequential Logic) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= STATE_IDLE;
            S       <= 1056'd0;
            S_sub   <= 1056'd0;
            A_reg   <= 1056'd0;
            B_reg   <= 1056'd0;
            M_reg   <= 1056'd0;
            count   <= 11'd1;     // Yêu c?u ph?n c?ng: kh?i t?o index vòng l?p t?i 1
            word_idx<= 6'd0;
            result  <= 1024'd0;
            done    <= 1'b0;
            carry   <= 2'd0;
            borrow  <= 1'b0;
            a_i     <= 1'b0;
            q_i     <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        A_reg <= {32'd0, a}; // Pad 32 bit 0 lên cao nh?t
                        B_reg <= {32'd0, b};
                        M_reg <= {32'd0, m};
                        S     <= 1056'd0;
                        count <= 11'd1;      // Kh?i t?o ??m = 1
                        state <= STATE_CALC_INIT;
                    end
                end

                STATE_CALC_INIT: begin
                    if (count <= 11'd1024) begin // Ki?m tra gi?i h?n 1024
                        word_idx <= 6'd0;
                        carry    <= 2'd0;
                        a_i      <= A_reg[0];
                        q_i      <= S[0] ^ (A_reg[0] & B_reg[0]);
                        state    <= STATE_CALC_ADD;
                    end else begin
                        state    <= STATE_NORM_INIT;
                    end
                end

                STATE_CALC_ADD: begin
                    // ??a k?t qu? t?ng 32-bit vào MSB và d?ch xoay ph?i
                    S     <= {word_sum[31:0], S[1055:32]};
                    B_reg <= {B_reg[31:0],    B_reg[1055:32]};
                    M_reg <= {M_reg[31:0],    M_reg[1055:32]};
                    
                    carry <= word_sum[33:32]; // L?u c? nh? cho chu k? ti?p theo

                    if (word_idx == 6'd32) begin
                        // ?ã ch?y ?? 33 vòng (0 -> 32), d? li?u ?ã v? ?úng v? trí
                        state <= STATE_CALC_SHIFT;
                    end else begin
                        word_idx <= word_idx + 1'b1;
                    end
                end

                STATE_CALC_SHIFT: begin
                    S     <= S >> 1;       // Chia 2 toàn b? vector S
                    A_reg <= A_reg >> 1;   // D?ch ?? l?y bit ti?p theo c?a A
                    count <= count + 1'b1; // T?ng index l?p
                    state <= STATE_CALC_INIT;
                end

                STATE_NORM_INIT: begin
                    word_idx <= 6'd0;
                    borrow   <= 1'b0;
                    state    <= STATE_NORM_SUB;
                end

                STATE_NORM_SUB: begin
                    // L?u k?t qu? tr? t?ng ph?n và xoay các thanh ghi
                    S_sub <= {word_sub[31:0], S_sub[1055:32]};
                    S     <= {S[31:0],        S[1055:32]}; 
                    M_reg <= {M_reg[31:0],    M_reg[1055:32]};
                    
                    borrow <= word_sub[32]; // L?u c? m??n

                    if (word_idx == 6'd32) begin
                        state <= STATE_DONE;
                    end else begin
                        word_idx <= word_idx + 1'b1;
                    end
                end

                STATE_DONE: begin
                    // Ki?m tra c? m??n sau chu k? tr? cu?i cùng
                    if (borrow) begin
                        result <= S[1023:0];     // S < M, gi? nguyên S
                    end else begin
                        result <= S_sub[1023:0]; // S >= M, l?y S ?ã tr?
                    end
                    done  <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule