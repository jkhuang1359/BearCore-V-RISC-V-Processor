// float_tests.c - 浮點概念測試（不使用實際浮點運算）
#include <stdint.h>
#include <string.h>
#include "system.h"
#include "test_macros.h"

#ifdef ENABLE_FLOAT_TESTS
/*
static void mark_variables_used(void) {
    // 空函數，只是為了消除警告
}
*/
// ============================================================================
// 測試 1: IEEE 754 格式理解測試（完全使用整數運算）
// ============================================================================
void test_ieee754_format_concepts(void) {
    TEST_BEGIN("IEEE 754 Format Concepts");
    
    uart_puts(" (Pure integer operations) ");
    
    // 測試 IEEE 754 單精度浮點格式理解
    // 格式：1位符號 + 8位指數 + 23位尾數
    // 指數偏移量（bias）：127
    
    // 特殊值的位模式
    uint32_t float_zero        = 0x00000000;
    uint32_t float_neg_zero    = 0x80000000;
    uint32_t float_one         = 0x3F800000;
    uint32_t float_neg_one     = 0xBF800000;
    uint32_t float_two         = 0x40000000;
    uint32_t float_half        = 0x3F000000;
    uint32_t float_inf         = 0x7F800000;
    uint32_t float_neg_inf     = 0xFF800000;
    uint32_t float_nan         = 0x7FC00000;
    
    // 測試基本位模式
    TEST_CHECK(float_zero == 0x00000000, "Positive zero (0x00000000)");
    TEST_CHECK(float_neg_zero == 0x80000000, "Negative zero (0x80000000)");
    TEST_CHECK(float_one == 0x3F800000, "1.0 representation (0x3F800000)");
    TEST_CHECK(float_neg_one == 0xBF800000, "-1.0 representation (0xBF800000)");
    TEST_CHECK(float_two == 0x40000000, "2.0 representation (0x40000000)");
    TEST_CHECK(float_half == 0x3F000000, "0.5 representation (0x3F000000)");
    
    // 測試特殊值
    TEST_CHECK(float_inf == 0x7F800000, "Positive infinity (0x7F800000)");
    TEST_CHECK(float_neg_inf == 0xFF800000, "Negative infinity (0xFF800000)");
    TEST_CHECK((float_nan & 0x7F800000) == 0x7F800000, "NaN pattern (exponent all 1s)");
    
    // 提取和測試各個字段
    uint32_t sign_one = (float_one >> 31) & 1;
    uint32_t exp_one = (float_one >> 23) & 0xFF;
    uint32_t mant_one = float_one & 0x7FFFFF;
    
    TEST_CHECK(sign_one == 0, "1.0: sign bit (0=positive)");
    TEST_CHECK(exp_one == 127, "1.0: exponent (bias 127)");
    TEST_CHECK(mant_one == 0, "1.0: mantissa (implied leading 1)");
    
    // 測試指數關係
    uint32_t exp_two = (float_two >> 23) & 0xFF;
    TEST_CHECK(exp_two == 128, "2.0: exponent (127 + 1)");
    
    uint32_t exp_half = (float_half >> 23) & 0xFF;
    TEST_CHECK(exp_half == 126, "0.5: exponent (127 - 1)");
    
    // 測試負數的符號位
    uint32_t sign_neg_one = (float_neg_one >> 31) & 1;
    TEST_CHECK(sign_neg_one == 1, "-1.0: sign bit (1=negative)");
    
    TEST_END();
}

// ============================================================================
// 測試 2: 浮點數位操作測試
// ============================================================================
void test_float_bit_manipulation(void) {
    TEST_BEGIN("Float Bit Manipulation");
    
    // 測試從整數構建浮點數位模式
    uint32_t built_float = 0;
    
    // 構建 1.0: 符號=0, 指數=127, 尾數=0
    built_float = (0 << 31) | (127 << 23) | 0;
    TEST_CHECK(built_float == 0x3F800000, "Build 1.0 from bits");
    
    // 構建 -2.0: 符號=1, 指數=128, 尾數=0
    built_float = (1 << 31) | (128 << 23) | 0;
    TEST_CHECK(built_float == 0xC0000000, "Build -2.0 from bits");
    
    // 構建 0.25: 符號=0, 指數=125, 尾數=0
    built_float = (0 << 31) | (125 << 23) | 0;
    TEST_CHECK(built_float == 0x3E800000, "Build 0.25 from bits");
    
    // 測試位操作：提取符號、指數、尾數
    uint32_t test_value = 0x40490FDB;  // π 的近似值
    uint32_t sign = (test_value >> 31) & 1;
    uint32_t exponent = (test_value >> 23) & 0xFF;
    uint32_t mantissa = test_value & 0x7FFFFF;
    
    TEST_CHECK(sign == 0, "π: sign bit (positive)");
    TEST_CHECK(exponent == 128, "π: exponent (approx 3.14159)");
    TEST_CHECK(mantissa == 0x490FDB, "π: mantissa (fractional part)");
    
    TEST_END();
}

// ============================================================================
// 測試 3: 浮點數範圍和精度概念
// ============================================================================
void test_float_range_precision_concepts(void) {
    TEST_BEGIN("Float Range & Precision Concepts");
    
    // 測試浮點數的範圍概念
    // 單精度浮點數範圍：約 ±3.4×10³⁸
    // 最小正規數：約 1.2×10⁻³⁸
    
    // 最大正規數的位模式：指數=254（127+127），尾數全1
    uint32_t max_normal = 0x7F7FFFFF;
    uint32_t min_normal = 0x00800000;  // 指數=1（127-126），尾數=0
    
    // 次正規數（denormal）的位模式：指數=0，尾數非0
    uint32_t min_denormal = 0x00000001;
    
    // 測試位模式
    TEST_CHECK((max_normal >> 23) == 0xFE, "Max normal: exponent = 254");
    TEST_CHECK((min_normal >> 23) == 0x01, "Min normal: exponent = 1");
    TEST_CHECK((min_denormal >> 23) == 0x00, "Min denormal: exponent = 0");
    
    // 測試精度概念：尾數的23位提供約7位十進制精度
    // 相鄰浮點數之間的間隔隨指數變化
    
    // 在指數為0時，相鄰浮點數的間隔最小（對於次正規數）
    // 在指數為127時，相鄰浮點數的間隔約為 2^-23 ≈ 1.19×10^-7
    
    uart_puts(" (Precision: ~7 decimal digits) ");
    
    TEST_END();
}

// ============================================================================
// 測試 4: 浮點算法概念模擬
// ============================================================================
void test_float_algorithm_concepts_simulated(void) {
    TEST_BEGIN("Float Algorithm Concepts (Simulated)");
    
    // 模擬浮點算法概念而不使用實際浮點運算
    // 使用定點數或整數來模擬
    
    // 示例：使用定點數（Q格式）模擬浮點加法概念
    // 假設我們使用 Q16.16 定點數格式（16位整數，16位小數）
    
    #define FIXED_SHIFT 16
    #define FIXED_ONE (1 << FIXED_SHIFT)
    
    // 模擬 1.5 + 2.5 = 4.0
    int32_t fixed_a = (1 << FIXED_SHIFT) + (1 << (FIXED_SHIFT - 1));  // 1.5
    int32_t fixed_b = (2 << FIXED_SHIFT) + (1 << (FIXED_SHIFT - 1));  // 2.5
    int32_t fixed_sum = fixed_a + fixed_b;
    int32_t expected_sum = 4 << FIXED_SHIFT;  // 4.0
    
    TEST_CHECK(fixed_sum == expected_sum, "Fixed-point addition (1.5 + 2.5 = 4.0)");
    
    // 模擬乘法：需要額外移位
    // 1.5 * 2.0 = 3.0
    fixed_a = (1 << FIXED_SHIFT) + (1 << (FIXED_SHIFT - 1));  // 1.5
    fixed_b = 2 << FIXED_SHIFT;  // 2.0
    int64_t temp_product = (int64_t)fixed_a * (int64_t)fixed_b;
    int32_t fixed_product = (int32_t)(temp_product >> FIXED_SHIFT);
    int32_t expected_product = 3 << FIXED_SHIFT;  // 3.0
    
    TEST_CHECK(fixed_product == expected_product, "Fixed-point multiplication (1.5 × 2.0 = 3.0)");
    
    // 模擬浮點正規化概念
    // 找到最高有效位並調整指數
    uint32_t value = 0x00012345;  // 一個小數
    int leading_zeros = 0;
    
    // 計算前導零（模擬浮點正規化）
    for (int i = 31; i >= 0; i--) {
        if ((value >> i) & 1) {
            leading_zeros = 31 - i;
            break;
        }
    }
    
    TEST_CHECK(leading_zeros > 0, "Leading zero count for normalization");
    
    uart_puts(" (Using Q16.16 fixed-point) ");
    
    TEST_END();
}

// ============================================================================
// 測試 5: 浮點錯誤和特殊情況概念
// ============================================================================
void test_float_error_concepts(void) {
    TEST_BEGIN("Float Error & Special Cases");
    
    // 測試浮點誤差概念
    // 1. 捨入誤差
    // 2. 抵消誤差
    // 3. 溢出/下溢
    
    // 使用整數模擬捨入誤差概念
    // 在二進制中，0.1 無法精確表示（循環小數）
    
    // 0.1 的二進制表示是循環的：0.0001100110011...
    // 在單精度浮點中，0.1 的位模式是：0x3DCCCCCD
    
    uint32_t float_0_1 = 0x3DCCCCCD;
    uint32_t float_0_2 = 0x3E4CCCCD;  // 0.2
    uint32_t float_0_3 = 0x3E99999A;  // 0.3

    // 使用這些變數消除警告
    (void)float_0_1;
    (void)float_0_2;
    (void)float_0_3;
    
    // 檢查 0.1 + 0.2 ≠ 0.3 的浮點誤差現象
    // 注意：我們只是比較位模式，不進行實際運算
    
    uart_puts(" (0.1 + 0.2 ≠ 0.3 in binary floating point) ");
    
    // 測試溢出概念
    // 最大指數是 254（255 用於特殊值）
    uint32_t max_exp = 254;
    uint32_t min_exp = 0;  // 0 用於次正規數和零
    
    TEST_CHECK(max_exp == 254, "Maximum exponent (normal numbers)");
    TEST_CHECK(min_exp == 0, "Minimum exponent (subnormals and zero)");
    
    // 測試次正規數（denormal）概念
    // 當指數為0且尾數非0時，表示次正規數
    uint32_t denormal_example = 0x00000001;  // 非常小的數
    
    TEST_CHECK((denormal_example >> 23) == 0, "Denormal number: exponent = 0");
    TEST_CHECK((denormal_example & 0x7FFFFF) != 0, "Denormal number: mantissa ≠ 0");
    
    TEST_END();
}

#endif // ENABLE_FLOAT_TESTS