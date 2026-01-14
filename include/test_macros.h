#ifndef TEST_MACROS_H
#define TEST_MACROS_H

#include <stdint.h>

// ============================================================================
// 測試框架宏（從 main.c 移動過來）
// ============================================================================

// 首先聲明需要用到的外部變量和函數
extern volatile int test_passed;
extern volatile int test_failed;
extern volatile int test_total;
extern void uart_puts(const char *s);
extern void print_dec(int val);
extern void print_hex(uint32_t val);

// ============================================================================
// 根據配置調整測試宏
// ============================================================================
// 我們使用預設的詳細輸出版本（TEST_VERBOSITY=2）
// 如果您想支援不同詳細程度，可以在這裡添加條件編譯

#define TEST_BEGIN(name) { \
    test_total++; \
    uart_puts("\r\n["); uart_puts(name); uart_puts("] ");

#define TEST_CHECK(condition, message) \
    if (condition) { \
        uart_puts("✓ "); uart_puts(message); \
        test_passed++; \
    } else { \
        uart_puts("✗ "); uart_puts(message); \
        uart_puts(" [line "); \
        print_dec(__LINE__); \
        uart_puts("]"); \
        test_failed++; \
    }

#define TEST_END() }

#endif // TEST_MACROS_H