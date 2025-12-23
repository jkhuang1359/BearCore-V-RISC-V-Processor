# 🐻 BearCore-V - RISC-V 32位处理器核

## 🛡️ 项目状态
![版本](https://img.shields.io/badge/版本-v1.1.0-blue)
![许可证](https://img.shields.io/badge/许可证-MIT-green)
![RISC-V](https://img.shields.io/badge/RISC--V-RV32IM-red)
![流水线](https://img.shields.io/badge/流水线-5级-orange)
![测试](https://img.shields.io/badge/测试-通过-brightgreen)

## 🎯 项目简介
BearCore-V 是一个基于RISC-V ISA的32位处理器核设计，支持RV32IM指令集和完整的M-mode特权架构。本项目实现了5级流水线、硬件乘除法器、完整的CSR子系统、中断/异常处理机制以及UART外设通信。

## ✨ 核心特性
- **指令集支持**: RV32IM (基础整数指令集 + 乘除扩展)
- **流水线架构**: 5级经典流水线 (IF-ID-EX-MEM-WB)
- **CSR系统**: 完整的M-mode CSR寄存器，支持特权操作
- **中断/异常**: 支持定时器中断、软件中断、外部中断
- **外设接口**: UART串口通信、性能计数器、内存映射IO
- **验证完备**: 通过全面的测试套件验证

## 📊 技术指标
| 项目 | 规格 |
|------|------|
| 架构 | 32位RISC-V RV32IM |
| 流水线 | 5级 (IF-ID-EX-MEM-WB) |
| 时钟频率 | 仿真: 100MHz |
| 总线宽度 | 32位指令/数据 |
| CSR寄存器 | 完整的M-mode CSR |
| 中断源 | 定时器、软件、外部 |
| 存储接口 | 指令ROM + 数据RAM |

## 🏗️ 架构框图
text
      ┌─────────────────────────────────┐
      │        BearCore-V 核心           │
      ├─────────────────────────────────┤
      │  IF  →  ID  →  EX  →  MEM → WB  │
      ├─────────────────────────────────┤
      │        ┌─────────────┐          │
      │        │   CSR单元   │          │
      │        └─────────────┘          │
      ├─────────────────────────────────┤
IRQ → │         中断控制器              │
      ├─────────────────────────────────┤
UART →│    外设接口 (MMIO)              │
      └─────────────────────────────────┘
text

## 📂 项目结构
BearCore-V/
├── src/ # RTL源代码
│ ├── core.v # 处理器顶层模块
│ ├── alu.v # 算术逻辑单元
│ ├── decoder.v # 指令解码器
│ ├── reg_file.v # 寄存器文件
│ ├── csr_registers.v # CSR寄存器组
│ ├── rom.v # 指令ROM
│ ├── data_ram.v # 数据RAM
│ ├── uart_tx.v # UART发送器
│ ├── tb_top.v # 测试顶层
│ └── start_csr_test.s # CSR测试启动代码
├── tests/ # 测试程序
│ ├── csr_simple_test.c # CSR测试主程序
│ ├── main.c # 除法测试程序
│ └── test_reporter.h # 测试报告头文件
├── docs/ # 设计文档
├── scripts/ # 工具脚本
├── simulation/ # 仿真相关
├── Makefile # 构建脚本
└── README.md # 本文件

text

## 🚀 快速开始

### 环境要求
```bash
# RISC-V工具链
sudo apt-get install gcc-riscv64-unknown-elf

# Verilog仿真器
sudo apt-get install iverilog gtkwave
编译和仿真
bash
# 1. 克隆项目
git clone https://github.com/jkhuang1359/BearCore-V-RISC-V-Processor.git
cd BearCore-V-RISC-V-Processor

# 2. 编译CSR测试程序
make csr_simple_test

# 3. 运行CSR功能测试
make test_csr_simple

# 4. 查看波形（可选）
make wave
✅ 已验证功能
核心功能
RV32I基础指令集 (算术、逻辑、跳转、访存)

M扩展 (乘法、除法、取余)

5级流水线数据通路

数据前推和冒险处理

精确异常处理

CSR系统
M-mode CSR寄存器 (MSTATUS, MIE, MTVEC等)

CSR指令 (CSRRW, CSRRS, CSRRC及其立即数版本)

中断使能和控制

异常向量表

外设和接口
UART串口输出

内存映射IO (MMIO)

性能计数器

定时器中断

测试验证
CSR功能完整测试

除法器正确性验证

流水线冒险测试

异常处理测试

📈 测试结果
CSR测试结果 (全通过)
text
✅ MSCRATCH基础读写测试
✅ MSTATUS MIE位控制测试  
✅ MTVEC地址对齐测试
✅ MIE中断使能测试
✅ 异常寄存器测试
✅ CSR原子操作测试
✅ CSR立即数指令测试
✅ 系统指令测试 (ECALL/EBREAK)
性能测试结果
除法运算: 正确执行32位有符号/无符号除法

流水线效率: 平均CPI ≈ 1.2

时钟频率: 仿真环境100MHz稳定运行

🔧 设计细节
流水线设计
IF阶段: 指令获取，PC更新

ID阶段: 指令解码，寄存器读取

EX阶段: 算术运算，地址计算

MEM阶段: 数据访存，CSR操作

WB阶段: 结果写回，寄存器更新

CSR实现
寄存器: 实现所有标准M-mode CSR

操作: 支持所有6种CSR指令格式

特权: 支持M-mode异常和中断

对齐: MTVEC自动4字节对齐

中断系统
中断源: 定时器、软件、外部中断

优先级: 定时器 > 外部 > 软件

嵌套: 支持中断嵌套处理

向量: 可配置异常向量地址

📊 资源使用估计
模块LUT数量寄存器数量说明
核心流水线~2000~5005级流水线控制
CSR单元~300~128CSR寄存器组
ALU~500~64含乘除法器
寄存器文件~102432×3232个32位寄存器
总线接口~200~64内存和IO接口
总计~4000~800中等规模设计
🔧 开发工具链
RTL设计: Verilog HDL

仿真: Icarus Verilog + GTKWave

编译: RISC-V GCC工具链

测试: 自定义指令级模拟器

版本控制: Git + GitHub

📚 文档索引
设计文档 - 架构设计说明

验证计划 - 测试验证方案

用户指南 - 快速使用指南

版本历史 - 版本变更记录

🤝 贡献指南
Fork本仓库

创建功能分支 (git checkout -b feature/AmazingFeature)

提交更改 (git commit -m 'Add some AmazingFeature')

推送到分支 (git push origin feature/AmazingFeature)

开启Pull Request

📄 许可证
本项目采用 MIT许可证 - 详见 LICENSE 文件。

🙏 致谢
RISC-V国际基金会 - 开放的指令集架构

开源社区 - 各种优秀的开源处理器参考设计

所有测试人员 - 感谢你们的宝贵反馈

📞 联系方式
项目维护者: jiakuan

GitHub: @jkhuang1359

⭐ 项目状态
开发状态: ✅ 核心功能完成
验证状态: ✅ 测试通过
维护状态: 🔧 活跃维护
最新版本: v1.1.0

最后更新: $(date)
