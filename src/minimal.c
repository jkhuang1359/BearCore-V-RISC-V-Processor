// 使用 main 函數
int main() {
    volatile unsigned int *uart = (unsigned int*)0x10000000;
    *uart = 'H';
    *uart = 'e';
    *uart = 'l';
    *uart = 'l';
    *uart = 'o';
    *uart = '\n';
    while(1);
    return 0;
}
