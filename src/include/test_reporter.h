// src/include/test_reporter.h
#ifndef TEST_REPORTER_H
#define TEST_REPORTER_H

#include <stdint.h>

// UART 函數聲明
void uart_putc(char c);
void uart_puts(const char *str);
void uart_print_int(unsigned int n);

// 定時器相關函數
void timer_interrupt_handler(void);

// 中斷控制函數
void enable_interrupts(void);
void disable_interrupts(void);
void wait_for_interrupt(void);

// 內聯彙編宏
#define ECALL() asm volatile("ecall")
#define EBREAK() asm volatile("ebreak")
#define WFI() asm volatile("wfi")

// CSR 操作宏
#define csr_read(csr) ({ \
    unsigned long __v; \
    asm volatile ("csrr %0, " #csr : "=r"(__v)); \
    __v; \
})

#define csr_write(csr, val) ({ \
    asm volatile ("csrw " #csr ", %0" :: "r"(val)); \
})

#define csr_set(csr, val) ({ \
    asm volatile ("csrs " #csr ", %0" :: "r"(val)); \
})

#define csr_clear(csr, val) ({ \
    asm volatile ("csrc " #csr ", %0" :: "r"(val)); \
})

#endif // TEST_REPORTER_H