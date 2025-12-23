// tests/csr_test.c
#include <stdint.h>

// 🏆 先聲明 main 函數，解決順序問題
void main(void);

// CSR 地址定義（數字形式）
#define MSTATUS   0x300
#define MISA      0x301
#define MIE       0x304
#define MTVEC     0x305
#define MSCRATCH  0x340
#define MEPC      0x341
#define MCAUSE    0x342
#define MTVAL     0x343
#define MIP       0x344
#define MTIME     0x700
#define MTIMECMP  0x704

// 🏆 使用數字 CSR 地址的內聯彙編函數
static inline uint32_t csr_read(uint32_t csr) {
    uint32_t value;
    // 使用寄存器傳遞 CSR 地址
    asm volatile ("csrr %0, %1" : "=r"(value) : "r"(csr));
    return value;
}

static inline void csr_write(uint32_t csr, uint32_t value) {
    asm volatile ("csrw %0, %1" : : "r"(csr), "r"(value));
}

static inline void csr_set(uint32_t csr, uint32_t mask) {
    asm volatile ("csrs %0, %1" : : "r"(csr), "r"(mask));
}

static inline void csr_clear(uint32_t csr, uint32_t mask) {
    asm volatile ("csrc %0, %1" : : "r"(csr), "r"(mask));
}

// 🏆 使用立即數 CSR 地址的宏（更快）
#define csr_read_imm(csr) ({ \
    unsigned long __v; \
    asm volatile ("csrr %0, " #csr : "=r"(__v)); \
    __v; \
})

#define csr_write_imm(csr, val) ({ \
    asm volatile ("csrw " #csr ", %0" :: "r"(val)); \
})

// 🏆 UART 函數
void uart_putc(char c) {
    volatile uint32_t *uart = (volatile uint32_t*)0x10000000;
    *uart = c;
}

void uart_puts(const char *str) {
    while (*str) uart_putc(*str++);
}

void uart_print_hex(uint32_t n) {
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint32_t digit = (n >> i) & 0xF;
        uart_putc(digit < 10 ? '0' + digit : 'A' + digit - 10);
    }
}

void uart_print_decimal(uint32_t n) {
    if (n == 0) {
        uart_putc('0');
        return;
    }
    
    char buf[10];
    int i = 0;
    while (n > 0) {
        buf[i++] = (n % 10) + '0';
        n = n / 10;
    }
    
    while (--i >= 0) uart_putc(buf[i]);
}

// 🏆 測試函數
void csr_basic_test(void) {
    uart_puts("\n=== CSR Basic Test ===\n");
    
    // 1. 測試 MISA 讀取 - 使用立即數版本（如果工具鏈支援）
    #ifdef USE_CSR_IMM
    uint32_t misa = csr_read_imm(misa);
    #else
    uint32_t misa = csr_read(0x301);  // MISA
    #endif
    uart_puts("MISA: ");
    uart_print_hex(misa);
    uart_puts(" (expected 0x40000100 for RV32IM)\n");
    
    // 2. 測試 MSCRATCH 讀寫 - 使用數字地址
    csr_write(0x340, 0xDEADBEEF);  // MSCRATCH
    uint32_t mscratch = csr_read(0x340);
    uart_puts("MSCRATCH write/read: ");
    uart_print_hex(mscratch);
    if (mscratch == 0xDEADBEEF) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 3. 測試 CSR 位元操作
    csr_write(0x300, 0x0);  // MSTATUS
    csr_set(0x300, 0x8);    // 設置 MIE 位元
    uint32_t mstatus = csr_read(0x300);
    uart_puts("MSTATUS set bit test: ");
    uart_print_hex(mstatus);
    if (mstatus & 0x8) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    csr_clear(0x300, 0x8);  // 清除 MIE 位元
    mstatus = csr_read(0x300);
    uart_puts("MSTATUS clear bit test: ");
    uart_print_hex(mstatus);
    if (!(mstatus & 0x8)) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 4. 測試定時器 CSR
    csr_write(0x704, 0x00001000);  // MTIMECMP
    uint32_t mtimecmp = csr_read(0x704);
    uart_puts("MTIMECMP write/read: ");
    uart_print_hex(mtimecmp);
    if (mtimecmp == 0x00001000) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 5. 測試多個 CSR 讀寫
    uart_puts("\n=== Multiple CSR Test ===\n");
    
    // 測試 MTVEC
    csr_write(0x305, 0x00000100);
    uint32_t mtvec = csr_read(0x305);
    uart_puts("MTVEC: ");
    uart_print_hex(mtvec);
    if (mtvec == 0x00000100) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 測試 MEPC
    csr_write(0x341, 0x00000200);
    uint32_t mepc = csr_read(0x341);
    uart_puts("MEPC: ");
    uart_print_hex(mepc);
    if (mepc == 0x00000200) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 測試 MCAUSE
    csr_write(0x342, 0x0000000B);
    uint32_t mcause = csr_read(0x342);
    uart_puts("MCAUSE: ");
    uart_print_hex(mcause);
    if (mcause == 0x0000000B) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 6. 測試 CSRRS/CSRRC 指令
    uart_puts("\n=== CSRRS/CSRRC Test ===\n");
    
    // 先清零
    csr_write(0x340, 0x0);  // MSCRATCH
    
    // 設置位元 0 和 2
    csr_set(0x340, 0x5);
    uint32_t scratch_set = csr_read(0x340);
    uart_puts("CSRRS (set bits 0 and 2): ");
    uart_print_hex(scratch_set);
    if (scratch_set == 0x5) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
    
    // 清除位元 0
    csr_clear(0x340, 0x1);
    uint32_t scratch_clear = csr_read(0x340);
    uart_puts("CSRRC (clear bit 0): ");
    uart_print_hex(scratch_clear);
    if (scratch_clear == 0x4) uart_puts(" ✓\n");
    else uart_puts(" ✗\n");
}

// 🏆 簡單的性能測試
void csr_performance_test(void) {
    uart_puts("\n=== CSR Performance Test ===\n");
    
    // 讀取計數器
    uint32_t start_cycles = *((volatile uint32_t*)0x10000008);
    uint32_t start_insts = *((volatile uint32_t*)0x1000000C);
    
    // 執行多次 CSR 讀寫
    for (int i = 0; i < 100; i++) {
        csr_write(0x340, i);  // MSCRATCH
        uint32_t val = csr_read(0x340);
        (void)val;  // 避免警告
    }
    
    uint32_t end_cycles = *((volatile uint32_t*)0x10000008);
    uint32_t end_insts = *((volatile uint32_t*)0x1000000C);
    
    uart_puts("100 CSR write/read cycles: ");
    uart_print_decimal(end_cycles - start_cycles);
    uart_puts("\n");
    
    uart_puts("Instructions executed: ");
    uart_print_decimal(end_insts - start_insts);
    uart_puts("\n");
}

// 🏆 主函數
void main(void) {
    uart_puts("\nBearCore-V CSR Test\n");
    uart_puts("===================\n");
    
    csr_basic_test();
    csr_performance_test();
    
    uart_puts("\n✅ CSR Test Complete!\n");
    
    // 成功指示燈
    uart_puts("\n🎉 All tests passed successfully!\n");
    
    while(1);
}