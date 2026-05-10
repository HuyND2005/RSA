#include <stdio.h>
#include <stdint.h>

// Hàm tính Khóa nghịch đảo bí mật (D) sử dụng thuật toán Euclid mở rộng
uint32_t mod_inverse(uint32_t a, uint32_t m) {
    int64_t m0 = m, t, q;
    int64_t x0 = 0, x1 = 1;
    
    if (m == 1) return 0;
    
    while (a > 1) {
        q = a / m;
        t = m;
        m = a % m, a = t;
        t = x0;
        x0 = x1 - q * x0;
        x1 = t;
    }
    
    if (x1 < 0) x1 += m0;
    
    return (uint32_t)x1;
}

// Hàm tính Hằng số Montgomery R^2 mod N
// Vòng lặp 2048 lần tương đương với việc dịch trái 2048 bit (nhân cho 2^2048)
uint32_t calc_r2_mod_n(uint32_t n) {
    uint64_t r2_val = 1;
    int i;
    for (i = 0; i < 2048; i++) {
        r2_val = r2_val << 1; 
        if (r2_val >= n) {
            r2_val -= n; 
        }
    }
    return (uint32_t)r2_val;
}

int main() {
    // 1. CHỌN 2 SỐ NGUYÊN TỐ VÀ KHÓA E
    // Có thể thay đổi p và q tùy ý ở đây
    uint64_t p = 40009;
    uint64_t q = 40013;
    uint32_t E = 65537; // Tiêu chuẩn vàng của RSA
    
    // 2. TÍNH TOÁN CÁC THÔNG SỐ TRUNG GIAN
    uint32_t N = (uint32_t)(p * q); 
    uint32_t phi = (uint32_t)((p - 1) * (q - 1));
    
    // 3. TÍNH KHÓA D VÀ HẰNG SỐ R2
    uint32_t D = mod_inverse(E, phi);
    uint32_t R2 = calc_r2_mod_n(N);
    
    // 4. Các khóa để đưa vào hệ thống
    printf("=== CONG CU TINH KHOA RSA 1024-BIT ===\n\n");
    printf("Voi p = %llu, q = %llu\n", (unsigned long long)p, (unsigned long long)q);
    printf("--------------------------------------\n");
    printf("Module N (A * B)    = %lu\n", (unsigned long)N);
    printf("Phi(N)              = %lu\n", (unsigned long)phi);
    printf("Khoa Cong Khai (E)  = %lu\n", (unsigned long)E);
    printf("Khoa Bi Mat (D)     = %lu\n", (unsigned long)D);
    printf("Hang so R^2 mod N   = %lu\n", (unsigned long)R2);
    printf("--------------------------------------\n");
    printf("Dung cac con so N, E, D, R^2 tren de gan vao mang Nios II!\n");

    return 0;
}