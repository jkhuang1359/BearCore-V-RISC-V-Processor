# BearCore-V 版本历史

## 🏷️ 版本标签

### v1.1.0 (当前版本) 🚀
**发布日期**: 2025年12月23日  
**提交**: 73e3347  
**状态**: 稳定发布

#### 新特性
✅ **完整的CSR系统实现**
  - 所有M-mode CSR寄存器支持
  - 6种CSR指令格式 (CSRRW/CSRRS/CSRRC及其立即数版本)
  - 完整的异常和中断处理机制

✅ **性能优化**
  - CSR时序问题修复
  - 分支指令数据前推优化
  - 流水线冒险处理改进
  - UART输出稳定性增强

✅ **测试验证套件**
  - CSR功能全面测试 (全部通过)
  - 异常处理流程验证
  - 性能基准测试
  - 集成回归测试

✅ **文档与工具**
  - 完整的架构设计文档
  - 用户使用指南
  - 自动化构建脚本
  - 仿真调试工具

#### 测试结果
✅ MSCRATCH基础读写测试
✅ MSTATUS MIE位控制测试
✅ MTVEC地址对齐测试
✅ MIE中断使能测试
✅ 异常寄存器测试
✅ CSR原子操作测试
✅ CSR立即数指令测试
✅ 系统指令测试 (ECALL/EBREAK)

text

#### 使用方法
```bash
# 编译CSR测试程序
make csr_simple_test

# 运行CSR功能测试
make test_csr_simple

# 查看仿真波形
make wave
v1.0.0
发布日期: 2025年12月23日
提交: 522142f
状态: 稳定发布

特性
完整的RV32IM指令集实现

5级流水线架构 (IF-ID-EX-MEM-WB)

硬件除法器支持

UART串口输出

性能计数器

完整的测试套件

指令级模拟器

性能指标
CPI: 1.0

所有测试通过

📊 版本对比
特性v1.0.0v1.1.0
RV32IM指令集✅✅
5级流水线✅✅
硬件除法器✅✅
UART输出✅✅
性能计数器✅✅
CSR系统❌✅
中断/异常处理❌✅
CSR功能测试❌✅
完整文档❌✅
🚀 升级指南
从v1.0.0升级到v1.1.0
bash
# 获取最新版本
git fetch origin
git checkout v1.1.0

# 或者使用主分支的最新提交
git checkout master
git pull origin master
编译和测试
bash
# 编译CSR测试程序
make csr_simple_test

# 运行CSR功能测试
make test_csr_simple

# 验证功能
# 输出应显示所有CSR测试通过
📁 文件结构变化
v1.0.0
text
src/
├── core.v
├── alu.v
├── decoder.v
├── reg_file.v
├── rom.v
├── data_ram.v
├── uart_tx.v
└── tb_top.v
v1.1.0 (新增/修改)
text
src/
├── csr_registers.v      # 新增: CSR寄存器组
├── exception_handler.s  # 新增: 异常处理
├── start_csr_test.s     # 新增: CSR测试启动代码
├── core.v              # 修改: 集成CSR系统
├── decoder.v           # 修改: 支持CSR指令
├── alu.v              # 修改: 增强ALU功能
└── include/test_reporter.h # 修改: 完善测试报告

tests/
├── csr_simple_test.c    # 新增: CSR测试程序
├── csr_simple_test.s    # 新增: CSR测试启动
└── 其他CSR测试文件

docs/
├── design/              # 新增: 设计文档
├── user/               # 新增: 用户指南
└── verification/       # 新增: 验证计划
🔮 未来版本计划
v1.2.0 (计划中)
缓存系统设计

分支预测优化

更多外设接口

性能进一步提升

v2.0.0 (长期计划)
S-mode和U-mode支持

页表和虚拟内存

多核扩展

高级调试功能

📞 支持
问题报告: GitHub Issues

文档: 查看docs/目录

讨论: GitHub Discussions

📄 许可证
MIT许可证 - 详见LICENSE文件

文档版本: v1.1.0
更新日期: $(date)
