#ifndef TEST_REPORTER_H
#define TEST_REPORTER_H

#define UART_DATA    0x10000000
#define UART_STATUS  0x10000004
#define PERF_CYCLES  0x10000008
#define PERF_INSTRS  0x1000000C

#define PERF_INSTRS  0x1000000C

static inline unsigned int get_instrs() {
    return *(volatile unsigned int*)PERF_INSTRS;
}

// 🏆 1. 讀取週期計數器
static inline unsigned int get_cycles() {
    return *(volatile unsigned int*)PERF_CYCLES;
}

// 🏆 2. 基本字元輸出
static inline void uart_putc(char c) {
    volatile unsigned int *status = (volatile unsigned int *)UART_STATUS;
    volatile unsigned int *data   = (volatile unsigned int *)UART_DATA;
    while (*status & 1); 
    *data = c;
}

// 🏆 3. 字串輸出 (修正 undefined reference)

// 🏆 4. 十六進位印出 (印出 Cycles 數字)
static inline void uart_print_int(unsigned int n) {
    
    for (int i = 7; i >= 0; i--) {
        int digit = (n >> (i * 4)) & 0xF;
        uart_putc(digit < 10 ? '0' + digit : 'A' + (digit - 10));
    }

}


#endif