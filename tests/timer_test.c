// firmware/timer_test.c
#include "test_reporter.h"

// 定時器地址定義
#define MTIME       (*((volatile unsigned int*)0x2000000))
#define MTIMECMP    (*((volatile unsigned int*)0x2000008))

// 定時器中斷計數器
volatile int timer_interrupt_count = 0;

// 定時器中斷處理函數
void timer_interrupt_handler() {
    timer_interrupt_count++;
    
    uart_puts("[TIMER] Interrupt #");
    uart_print_int(timer_interrupt_count);
    uart_puts(" at mtime=");
    uart_print_int(MTIME);
    uart_putc('\n');
    
    // 設置下一個中斷（每 1000000 個時鐘周期，約 10ms @ 100MHz）
    MTIMECMP = MTIME + 1000000;
    
    // 清除中斷暫存位
    // 注意：在我們的實現中，中斷會在 MTIME >= MTIMECMP 時自動清除
}

void timer_test() {
    uart_puts("=== Timer Test ===\n");
    
    // 1. 顯示當前定時器值
    uart_puts("Initial mtime: ");
    uart_print_int(MTIME);
    uart_putc('\n');
    
    uart_puts("Initial mtimecmp: ");
    uart_print_int(MTIMECMP);
    uart_putc('\n');
    
    // 2. 設置定時器中斷（1ms 後，假設時鐘 100MHz）
    MTIMECMP = MTIME + 100000;  // 1ms
    
    uart_puts("Set mtimecmp to: ");
    uart_print_int(MTIMECMP);
    uart_puts(" (1ms from now)\n");
    
    // 3. 啟用定時器中斷
    // 設置 mie.MTIE (Machine Timer Interrupt Enable)
    asm volatile("csrsi mie, 0x80");  // 第 7 位是 MTIE
    
    // 4. 啟用全域中斷
    asm volatile("csrsi mstatus, 0x8");  // 設置 MIE
    
    uart_puts("Timer interrupts enabled\n");
    
    // 5. 等待中斷
    uart_puts("Waiting for timer interrupts...\n");
    
    int last_count = 0;
    for (int i = 0; i < 100; i++) {
        // 簡單延遲
        for (volatile int j = 0; j < 10000; j++);
        
        // 檢查是否收到中斷
        if (timer_interrupt_count > last_count) {
            uart_puts(".");
            last_count = timer_interrupt_count;
        }
        
        // 如果收到 5 次中斷就停止
        if (timer_interrupt_count >= 5) {
            break;
        }
    }
    
    // 6. 禁用中斷
    asm volatile("csrci mstatus, 0x8");   // 清除 MIE
    asm volatile("csrci mie, 0x80");      // 清除 MTIE
    
    uart_puts("\nTimer test completed\n");
    uart_puts("Total interrupts received: ");
    uart_print_int(timer_interrupt_count);
    uart_putc('\n');
}

void main() {
    // 設置例外向量表
    asm volatile("la t0, trap_handler");
    asm volatile("csrw mtvec, t0");
    
    uart_puts("System started\n");
    
    // 運行定時器測試
    timer_test();
    
    uart_puts("=== All tests completed ===\n");
    
    while(1) {
        // 空閒循環
        asm volatile("wfi");  // 等待中斷
    }
}