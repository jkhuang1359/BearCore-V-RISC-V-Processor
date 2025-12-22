// test_main.c
#define TEST_RESULT_ADDR 0x0000FF00 // 設一個測試結果觀察點

void main() {
    volatile int* res = (int*)TEST_RESULT_ADDR;
    int a = 10, b = 20, c;

    // --- 測試階段 1: ALU 運算 ---
    c = a + b; // ADD
    if (c == 30) *res = 0x11110001; // Stage 1 Pass
    else         *res = 0x1111EEEE; // Stage 1 Fail

    c = b - a; // SUB
    if (c == 10) *res = 0x11110002; // Stage 2 Pass
    else         *res = 0x1111EEEE;

    // --- 測試階段 2: 記憶體存取 (Load/Store) ---
    volatile int mem_test = 0x55AA55AA;
    if (mem_test == 0x55AA55AA) *res = 0x22220001; // Stage 3 Pass
    else                        *res = 0x2222EEEE;

    // --- 測試階段 3: 分支與跳躍 ---
    int flag = 0;
    if (a < b) flag = 1; // SLT / BNE
    if (flag == 1) *res = 0x33330001; // Stage 4 Pass
    else           *res = 0x3333EEEE;

    // 測試結束
    *res = 0xFFFFFFFF; 
    while(1);
}