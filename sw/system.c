#include "system.h"

void system_init(void) {
    // 禁用所有中斷
    disable_interrupts();
    
    // 初始化 UART（如果需要設定波特率等）
    // UART_BAUD = ...;
    
    // 初始化 GPIO
    // GPIO_OUTPUT = 0;
    // GPIO_ENABLE = 0xFFFFFFFF;
    
    // 初始化 timer
    MTIMECMP_L = 0xFFFFFFFF;
    MTIMECMP_H = 0xFFFFFFFF;
}

void delay_ms(uint32_t ms) {
    uint64_t target = get_time_us() + (ms * 1000);
    while (get_time_us() < target);
}

void delay_us(uint32_t us) {
    uint64_t target = get_time_us() + us;
    while (get_time_us() < target);
}

uint64_t get_time_us(void) {
    uint64_t time;
    uint32_t hi, lo;
    
    // 讀取 64 位時間計數器
    do {
        hi = MTIME_H;
        lo = MTIME_L;
    } while (hi != MTIME_H);  // 防止溢出
    
    time = ((uint64_t)hi << 32) | lo;
    
    // 假設時鐘頻率為 100MHz，轉換為微秒
    return time / 100;
}

void enable_interrupts(void) {
    csr_set(mstatus, 1 << 3);  // MIE
}

void disable_interrupts(void) {
    csr_clear(mstatus, 1 << 3);  // MIE
}