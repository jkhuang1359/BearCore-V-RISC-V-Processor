BearCore-V 快速开始指南
1. 环境搭建
1.1 安装依赖
bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    iverilog \
    gtkwave \
    gcc-riscv64-unknown-elf \
    make \
    python3 \
    python3-pip

# 安装Python依赖
pip3 install numpy matplotlib
1.2 获取代码
bash
# 克隆仓库
git clone https://github.com/yourusername/bearcore-v.git
cd bearcore-v

# 检查目录结构
ls -la
2. 首次使用
2.1 编译测试程序
bash
# 编译CSR测试程序
make csr_simple_test

# 查看生成的文件
ls -la firmware.*
2.2 运行仿真
bash
# 运行CSR测试仿真
make test_csr_simple

# 或者运行主测试仿真
make sim
2.3 查看波形
bash
# 生成波形文件
make wave

# 查看波形
gtkwave cpu.vcd

3. 编写测试程序
3.1 基本程序结构
c
#include <stdint.h>

// UART地址定义
#define UART_DATA   0x10000000
#define UART_STATUS 0x10000004

// UART输出函数
void uart_putc(char c) {
    volatile uint32_t *status = (uint32_t*)UART_STATUS;
    volatile uint32_t *data = (uint32_t*)UART_DATA;
    while (*status & 1);  // 等待UART空闲
    *data = c;
}

void main() {
    uart_putc('H');
    uart_putc('e');
    uart_putc('l');
    uart_putc('l');
    uart_putc('o');
    uart_putc('!');
    uart_putc('\n');
    
    while(1);  // 无限循环
}
3.2 CSR操作示例
c
// CSR读取函数
static inline uint32_t csr_read_mscratch(void) {
    uint32_t value;
    asm volatile ("csrr %0, mscratch" : "=r"(value));
    return value;
}

// CSR写入函数
static inline void csr_write_mscratch(uint32_t value) {
    asm volatile ("csrw mscratch, %0" :: "r"(value));
}

// 使用示例
void test_csr(void) {
    uint32_t original = csr_read_mscratch();
    csr_write_mscratch(0x12345678);
    uint32_t readback = csr_read_mscratch();
    // readback 应该为 0x12345678
}

4. 调试技巧
4.1 查看仿真输出
仿真会在终端输出UART发送的字符，这是主要的调试输出方式。

4.2 使用波形调试
bash
# 1. 生成带调试信息的仿真
make wave

# 2. 打开GTKWave
gtkwave cpu.vcd

# 3. 添加关键信号
# - pc: 程序计数器
# - if_inst: 当前指令
# - reg_file信号
# - csr相关信号
4.3 常见问题
Q: 仿真没有输出？
A: 检查UART地址是否正确，确认测试程序正确编译。

Q: CSR操作没有效果？
A: 检查CSR地址是否正确，查看CSR写使能信号。

Q: 程序死循环？
A: 检查分支指令是否正确，查看PC变化。

5. 性能分析
5.1 查看性能计数器
c
// 读取性能计数器
volatile uint32_t *cycle_cnt = (uint32_t*)0x10000008;
volatile uint32_t *inst_cnt = (uint32_t*)0x1000000C;

void measure_performance(void) {
    uint32_t start_cycles = *cycle_cnt;
    uint32_t start_insts = *inst_cnt;
    
    // 执行测试代码...
    
    uint32_t end_cycles = *cycle_cnt;
    uint32_t end_insts = *inst_cnt;
    
    uint32_t total_cycles = end_cycles - start_cycles;
    uint32_t total_insts = end_insts - start_insts;
    float cpi = (float)total_cycles / total_insts;
}
5.2 性能优化建议
减少分支: 分支指令会导致流水线停顿

利用流水线: 安排无关指令填充延迟槽

合理使用CSR: CSR操作相对较慢，避免频繁操作

6. 扩展开发
6.1 添加新指令
在decoder.v中添加指令解码

在alu.v中添加运算逻辑

更新流水线控制逻辑

6.2 添加新CSR
在csr_registers.v中添加寄存器定义

添加读写逻辑

更新解码器识别新CSR地址

6.3 添加新外设
定义MMIO地址空间

在core.v中添加外设接口

编写驱动程序

7. 实用脚本
7.1 自动化测试
bash
# 运行所有测试
./scripts/run_all_tests.sh

# 运行特定测试
./scripts/run_test.sh tests/csr_simple_test.c
7.2 代码检查
bash
# 检查Verilog语法
iverilog -tnull src/*.v

# 检查C代码语法
riscv64-unknown-elf-gcc -fsyntax-only tests/*.c

8. 获取帮助
8.1 文档资源
架构设计: docs/design/architecture.md

验证计划: docs/verification/testplan.md

API参考: docs/api/

8.2 问题反馈
查看GitHub Issues

提交新Issue

查阅常见问题解答

8.3 社区支持
GitHub Discussions

RISC-V官方论坛

邮件列表

9. 示例项目
9.1 简单测试项目
bash
# 创建新测试目录
mkdir -p my_tests
cd my_tests

# 编写测试程序
cat > test_hello.c << 'EOF'
#include <stdint.h>

#define UART_DATA   0x10000000
#define UART_STATUS 0x10000004

void uart_putc(char c) {
    volatile uint32_t *status = (uint32_t*)UART_STATUS;
    volatile uint32_t *data = (uint32_t*)UART_DATA;
    while (*status & 1);
    *data = c;
}

void main() {
    const char *msg = "Hello from my test!\n";
    while (*msg) uart_putc(*msg++);
    while(1);
}


# 编译和运行
make test_hello
make sim
用户指南版本: 1.0
最后更新: $(date)