// src/include/test_reporter.h
#ifndef TEST_REPORTER_H
#define TEST_REPORTER_H

#include <stdint.h>

// UART 函数声明
void uart_putc(char c);
void uart_puts(const char *str);
void uart_print_hex(unsigned int n);
void uart_print_decimal(unsigned int n);

// 定時器相關函數
void timer_interrupt_handler(void);

// 中斷控制函數
void enable_interrupts(void);
void disable_interrupts(void);
void wait_for_interrupt(void);

// CSR 操作宏 - 修正版本
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

// CSR 原子操作宏
#define csr_swap(csr, val) ({ \
    unsigned long __v; \
    asm volatile ("csrrw %0, " #csr ", %1" : "=r"(__v) : "r"(val)); \
    __v; \
})

#define csr_read_set(csr, val) ({ \
    unsigned long __v; \
    asm volatile ("csrrs %0, " #csr ", %1" : "=r"(__v) : "r"(val)); \
    __v; \
})

#define csr_read_clear(csr, val) ({ \
    unsigned long __v; \
    asm volatile ("csrrc %0, " #csr ", %1" : "=r"(__v) : "r"(val)); \
    __v; \
})

// 立即数版本
#define csr_swap_imm(csr, imm) ({ \
    unsigned long __v; \
    asm volatile ("csrrwi %0, " #csr ", %1" : "=r"(__v) : "i"(imm)); \
    __v; \
})

#define csr_read_set_imm(csr, imm) ({ \
    unsigned long __v; \
    asm volatile ("csrrsi %0, " #csr ", %1" : "=r"(__v) : "i"(imm)); \
    __v; \
})

#define csr_read_clear_imm(csr, imm) ({ \
    unsigned long __v; \
    asm volatile ("csrrci %0, " #csr ", %1" : "=r"(__v) : "i"(imm)); \
    __v; \
})

// CSR 寄存器地址定义
#define CSR_MSTATUS   0x300
#define CSR_MISA      0x301
#define CSR_MIE       0x304
#define CSR_MTVEC     0x305
#define CSR_MSCRATCH  0x340
#define CSR_MEPC      0x341
#define CSR_MCAUSE    0x342
#define CSR_MTVAL     0x343
#define CSR_MIP       0x344

// 内联汇编宏
#define ECALL() asm volatile("ecall")
#define EBREAK() asm volatile("ebreak")
#define WFI() asm volatile("wfi")

#endif // TEST_REPORTER_H