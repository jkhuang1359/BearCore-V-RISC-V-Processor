// src/trap_handler.c
#include "test_reporter.h"

void handle_trap(unsigned int mcause, unsigned int mepc, unsigned int mtval) {
    // 檢查是否為中斷
    if (mcause & 0x80000000) {
        // 中斷處理
        unsigned int int_id = mcause & 0x7FFFFFFF;
        
        switch (int_id) {
            case 3:
                uart_puts("[INT] Software interrupt\n");
                break;
            case 7:
                // 🏆 定時器中斷
                timer_interrupt_handler();
                break;
            case 11:
                uart_puts("[INT] External interrupt\n");
                break;
            default:
                uart_puts("[INT] Unknown interrupt: ");
                uart_print_int(int_id);
                uart_putc('\n');
                break;
        }
    } else {
        // 例外處理
        uart_puts("[EXCEPTION] Cause: ");
        uart_print_int(mcause);
        uart_puts(" at PC=");
        uart_print_int(mepc);
        uart_puts(" tval=");
        uart_print_int(mtval);
        uart_putc('\n');
        
        // 根據例外類型處理
        switch (mcause) {
            case 2: // 非法指令
                uart_puts("Illegal instruction\n");
                mepc += 4; // 跳過非法指令
                asm volatile ("csrw mepc, %0" :: "r"(mepc));
                break;
            case 3: // 斷點
                uart_puts("Breakpoint\n");
                mepc += 4; // 繼續執行
                asm volatile ("csrw mepc, %0" :: "r"(mepc));
                break;
            case 11: // ECALL
                uart_puts("ECALL\n");
                mepc += 4; // 繼續執行
                asm volatile ("csrw mepc, %0" :: "r"(mepc));
                break;
            default:
                uart_puts("Unhandled exception\n");
                while(1); // 停止執行
        }
    }
}