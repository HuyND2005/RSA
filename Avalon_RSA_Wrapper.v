module Avalon_RSA_Wrapper (
    input  wire        clk,
    input  wire        reset_n,
    
    // Giao tiếp Avalon Memory-Mapped Slave (32-bit data)
    input  wire [7:0]  avalon_address,
    input  wire        avalon_write,
    input  wire [31:0] avalon_writedata,
    input  wire        avalon_read,
    output reg  [31:0] avalon_readdata,
	 
	 output wire        done_out
);

    // --- Định nghĩa các Base Address ---
    localparam ADDR_A_BASE    = 8'd0;    // 0 đến 31
    localparam ADDR_B_BASE    = 8'd32;   // 32 đến 63
    localparam ADDR_M_BASE    = 8'd64;   // 64 đến 95
    localparam ADDR_R2_BASE   = 8'd96;   // 96 đến 127
    localparam ADDR_RES_BASE  = 8'd128;  // 128 đến 159
    localparam ADDR_CTRL_STAT = 8'd160;  // 160

    // --- Khai báo thanh ghi lớn 1024-bit ---
    reg [1023:0] flat_a;
    reg [1023:0] flat_b;
    reg [1023:0] flat_m;
    reg [1023:0] flat_r2;
    wire [1023:0] flat_result;

    // --- Tín hiệu Điều khiển ---
    reg  start_pulse;
    wire done_wire;
    reg  done_flag;

    // --- Tính toán độ dời bit (Bit Offset) dựa trên địa chỉ (5 bit cuối) ---
    // Ví dụ: địa chỉ 0 -> dịch 0 bit; địa chỉ 1 -> dịch 32 bit; địa chỉ 2 -> dịch 64 bit...
    wire [4:0] offset_word = avalon_address[4:0];
    wire [9:0] bit_shift   = {offset_word, 5'd0}; // Nhân 32 (dịch trái 5 bit)

    // 1. Logic GHI dữ liệu từ Avalon Bus
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            flat_a      <= 1024'd0;
            flat_b      <= 1024'd0;
            flat_m      <= 1024'd0;
            flat_r2     <= 1024'd0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0; // Tự động xóa xung start

            if (avalon_write) begin
                if (avalon_address >= ADDR_A_BASE && avalon_address < ADDR_A_BASE + 32)
                    flat_a[bit_shift +: 32] <= avalon_writedata; // Indexed Part-Select
                
                else if (avalon_address >= ADDR_B_BASE && avalon_address < ADDR_B_BASE + 32)
                    flat_b[bit_shift +: 32] <= avalon_writedata;
                
                else if (avalon_address >= ADDR_M_BASE && avalon_address < ADDR_M_BASE + 32)
                    flat_m[bit_shift +: 32] <= avalon_writedata;

                else if (avalon_address >= ADDR_R2_BASE && avalon_address < ADDR_R2_BASE + 32)
                    flat_r2[bit_shift +: 32] <= avalon_writedata;
                
                else if (avalon_address == ADDR_CTRL_STAT) begin
                    if (avalon_writedata[0] == 1'b1)
                        start_pulse <= 1'b1;
                end
            end
        end
    end

    // 2. Logic cờ trạng thái (Done Flag)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            done_flag <= 1'b0;
        else if (start_pulse)
            done_flag <= 1'b0; 
        else if (done_wire)
            done_flag <= 1'b1; 
    end
	 
	assign done_out = done_flag;
    // 3. Logic ĐỌC dữ liệu từ thanh ghi ra Avalon Bus
    // Dịch bit để lấy dữ liệu.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            avalon_readdata <= 32'd0;
        end else begin
            if (avalon_read) begin
                if (avalon_address >= ADDR_A_BASE && avalon_address < ADDR_A_BASE + 32)
                    avalon_readdata <= flat_a >> bit_shift;
                
                else if (avalon_address >= ADDR_B_BASE && avalon_address < ADDR_B_BASE + 32)
                    avalon_readdata <= flat_b >> bit_shift;
                
                else if (avalon_address >= ADDR_M_BASE && avalon_address < ADDR_M_BASE + 32)
                    avalon_readdata <= flat_m >> bit_shift;

                else if (avalon_address >= ADDR_R2_BASE && avalon_address < ADDR_R2_BASE + 32)
                    avalon_readdata <= flat_r2 >> bit_shift;
                
                else if (avalon_address >= ADDR_RES_BASE && avalon_address < ADDR_RES_BASE + 32)
                    avalon_readdata <= flat_result >> bit_shift;
                
                else if (avalon_address == ADDR_CTRL_STAT)
                    avalon_readdata <= {30'd0, done_flag, 1'b0};
                
                else
                    avalon_readdata <= 32'd0;
            end
        end
    end

    // --- Instantiate Khối Tầng 2 (ModExp) ---
    ModExp u_mod_exp (
        .clk      (clk),
        .rst_n    (reset_n),
        .start    (start_pulse),
        .base_in  (flat_a),      
        .exp_in   (flat_b),      
        .mod_in   (flat_m),      
        .r2_mod_n (flat_r2),     
        .result   (flat_result), 
        .done     (done_wire)    
    );

endmodule