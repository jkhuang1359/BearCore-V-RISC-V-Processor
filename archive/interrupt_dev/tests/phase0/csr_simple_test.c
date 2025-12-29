// 简单的CSR测试
int main() {
    unsigned int mstatus;
    
    // 读取mstatus
    asm volatile("csrr %0, mstatus" : "=r"(mstatus));
    
    // 简单的检查：如果mstatus读取成功（非零值），认为是成功的
    // 注意：实际应根据硬件实现调整
    if (mstatus != 0) {
        return 0;  // 成功
    } else {
        return 1;  // 失败
    }
}
