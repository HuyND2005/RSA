`timescale 1ns / 1ps

module tb_ModExp();

    // --- Khai báo tín hiệu Testbench ---
    reg           clk;
    reg           rst_n;
    reg           start;
    reg  [1023:0] base_in;
    reg  [1023:0] exp_in;
    reg  [1023:0] mod_in;
    reg  [1023:0] r2_mod_n;
    
    wire [1023:0] result;
    wire          done;

    // --- Gọi (Instantiate) Module cần test ---
    ModExp uut (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .base_in  (base_in),
        .exp_in   (exp_in),
        .mod_in   (mod_in),
        .r2_mod_n (r2_mod_n),
        .result   (result),
        .done     (done)
    );

    // --- Khởi tạo Xung Clock (Chu kỳ 10ns -> 100MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Kịch bản Mô phỏng ---
    initial begin
        // 1. Khởi tạo giá trị ban đầu
        rst_n    = 1'b0;
        start    = 1'b0;
        base_in  = 1024'd0;
        exp_in   = 1024'd0;
        mod_in   = 1024'd0;
        r2_mod_n = 1024'd0;

        // 2. Thả Reset
        #20;
        rst_n = 1'b1;
        #20;

        $display("========================================");
        $display("BAT DAU MO PHONG KHOI ModExp (RSA CORE)");
        $display("========================================");

        // 3. Nạp dữ liệu bài toán: 5^3 mod 13
        base_in  = 1024'd134279032;   // A = 5
        exp_in   = 1024'd111186689;   // B = 3 
        mod_in   = 1024'd1600880117;  // N = 13
        r2_mod_n = 1024'd509951013;   // R^2 mod N = 9 (với R = 2^1024)

        $display("Du lieu dau vao:");
        $display(" - Base (A)      = %0d", base_in);
        $display(" - Exponent (B)  = %0d", exp_in);
        $display(" - Modulus (N)   = %0d", mod_in);
        $display(" - R^2 mod N     = %0d", r2_mod_n);

        // 4. Phát xung Start (Rộng 1 chu kỳ clock)
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        $display("\nDang tinh toan... (Qua trinh nay se ton khoang vai nghin clock)");

        // 5. Chờ tín hiệu Done bật lên
        wait (done == 1'b1);
        
        // 6. Kiểm tra kết quả
        $display("\n========================================");
        $display("TINH TOAN HOAN TAT!");
        $display("Ket qua phan cung : %0d", result);
    /*   $display("Ket qua ky vong   : 8");
        
        if (result == 1024'd8) begin
            $display("=> [PASSED] Module hoat dong CHINH XAC!");
        end else begin
            $display("=> [FAILED] Ket qua sai!");
        end */
        $display("========================================");

        // Kết thúc mô phỏng
        #50;
        $finish;
    end

endmodule