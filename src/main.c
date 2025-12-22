#include "test_reporter.h"

// 🏆 字串反轉演算法
void reverse_string(char *str) {
    int len = 0;
    while (str[len] != '\0') len++;

    int start = 0;
    int end = len - 1;
    char temp;

    while (start < end) {
        temp = str[start];
        str[start] = str[end];
        str[end] = temp;
        
        start++;
        end--;
    }
}

void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str);
        str++;
    }
}

// 🏆 使用硬體除法器的新版本
void uart_print_decimal(unsigned int n) {
    if (n == 0) {
        uart_putc('0');
        return;
    }

    char buf[10];
    int i = 0;

    // 使用硬體除法器（現在正常了）
    while (n > 0) {
        buf[i++] = (n % 10) + '0';
        n = n / 10;
    }

    while (--i >= 0) uart_putc(buf[i]);
}

void *memcpy(void *dest, const void *src, unsigned int n) {
    char *d = dest;
    const char *s = src;
    for (unsigned int i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}

void uart_print_hex(unsigned int n) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        unsigned int digit = (n >> i) & 0xF;
        if (digit < 10) uart_putc('0' + digit);
        else uart_putc('A' + digit - 10);
    }
}

void comprehensive_div_test(void) {
    uart_puts("\n=== Comprehensive Divider Test ===\n");
    
    // 使用可管理的測試數字
    unsigned int tests[][4] = {
        {4, 2, 2, 0},
        {100, 3, 33, 1},
        {0, 5, 0, 0},
        {65535, 256, 255, 255},
        {1000, 7, 142, 6},  // 替換大數字測試
        {123456, 789, 156, 372},
    };
    
    for (int i = 0; i < 6; i++) {
        unsigned int a = tests[i][0];
        unsigned int b = tests[i][1];
        unsigned int expected_div = tests[i][2];
        unsigned int expected_rem = tests[i][3];
        
        unsigned int div_result = a / b;
        unsigned int rem_result = a % b;
        
        uart_puts("Test ");
        uart_print_decimal(i+1);
        uart_puts(": ");
        uart_print_decimal(a);
        uart_puts(" / ");
        uart_print_decimal(b);
        uart_puts(" = ");
        uart_print_decimal(div_result);
        
        if (div_result == expected_div) {
            uart_puts(" ✓");
        } else {
            uart_puts(" ✗ (expected ");
            uart_print_decimal(expected_div);
            uart_puts(")");
        }
        
        uart_puts(", rem = ");
        uart_print_decimal(rem_result);
        
        if (rem_result == expected_rem) {
            uart_puts(" ✓");
        } else {
            uart_puts(" ✗ (expected ");
            uart_print_decimal(expected_rem);
            uart_puts(")");
        }
        
        uart_puts("\n");
    }
    
    // 除以零測試
    uart_puts("\nDivide by zero test:\n");
    unsigned int a = 100, b = 0;
    unsigned int div_result = a / b;
    unsigned int rem_result = a % b;
    
    uart_puts("100 / 0 = ");
    if (div_result == 0xFFFFFFFF) uart_puts("0xFFFFFFFF ✓");
    else uart_puts("ERROR ✗");
    
    uart_puts(", 100 % 0 = ");
    if (rem_result == 100) uart_puts("100 ✓");
    else uart_puts("ERROR ✗");
    
    uart_puts("\n");
}

void main() {
    uart_puts("BearCore-V Divider Test\n");
    comprehensive_div_test();
    
    // 性能測試
    uart_puts("\n=== Performance Test ===\n");
    char test_str[] = "BearCore-V";
    
    unsigned int start_cycles = *((volatile unsigned int*)0x10000008);
    unsigned int start_insts  = *((volatile unsigned int*)0x1000000C);
    
    // 反轉字串
    reverse_string(test_str);
    
    unsigned int end_cycles = *((volatile unsigned int*)0x10000008);
    unsigned int end_insts  = *((volatile unsigned int*)0x1000000C);
    
    unsigned int total_cycles = end_cycles - start_cycles;
    unsigned int total_insts  = end_insts - start_insts;
    
    uart_puts("Reversed string: ");
    uart_puts(test_str);
    uart_puts("\n");
    
    uart_puts("Cycles: "); uart_print_decimal(total_cycles); uart_puts("\n");
    uart_puts("Insts: "); uart_print_decimal(total_insts); uart_puts("\n");
    uart_puts("CPI: ");
    
    // 簡單的CPI計算（避免複雜除法）
    if (total_insts > 0) {
        unsigned int cpi = total_cycles / total_insts;
        uart_print_decimal(cpi);
    } else {
        uart_puts("N/A");
    }
    uart_puts("\n");
    
    while(1);
}