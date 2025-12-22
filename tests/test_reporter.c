// src/test_reporter.c
#include "test_reporter.h"

// UART 地址定義
#define UART_DATA    (*((volatile unsigned int*)0x10000000))
#define UART_STATUS  (*((volatile unsigned int*)0x10000004))

// 🏆 發送單個字元
void uart_putc(char c) {
    while (UART_STATUS & 1); // 等待 UART 空閒
    UART_DATA = c;
}

// 🏆 發送字串
void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str++);
    }
}

// 🏆 打印整數
void uart_print_int(unsigned int n) {
    char buffer[11];
    int i = 0;
    
    if (n == 0) {
        uart_putc('0');
        return;
    }
    
    // 轉換為字符串（反向）
    while (n > 0) {
        buffer[i++] = '0' + (n % 10);
        n /= 10;
    }
    
    // 反向輸出
    for (int j = i - 1; j >= 0; j--) {
        uart_putc(buffer[j]);
    }
}

// 🏆 定時器中斷處理函數
void timer_interrupt_handler(void) {
    uart_puts("[TIMER] Interrupt received!\n");
}

// 🏆 啟用中斷
void enable_interrupts(void) {
    asm volatile("csrsi mstatus, 0x8");
}

// 🏆 禁用中斷
void disable_interrupts(void) {
    asm volatile("csrci mstatus, 0x8");
}

// 🏆 等待中斷
void wait_for_interrupt(void) {
    asm volatile("wfi");
}