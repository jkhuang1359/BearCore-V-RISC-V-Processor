# BearCore-V 验证计划

## 1. 验证概述
### 1.1 验证目标
- 确保所有RV32IM指令正确执行
- 验证CSR系统完整功能
- 确认中断/异常处理正确
- 验证外设接口功能

### 1.2 验证方法
- 指令级模拟器(ILS)作为黄金参考
- Verilog功能仿真
- 自动化测试脚本
- 覆盖率分析

## 2. 测试套件
### 2.1 单元测试
| 测试名称 | 测试目标 | 状态 |
|----------|----------|------|
| ALU测试 | 算术逻辑运算 | ✅ 完成 |
| 解码器测试 | 指令解码 | ✅ 完成 |
| 寄存器文件测试 | 寄存器读写 | ✅ 完成 |
| CSR单元测试 | CSR操作 | ✅ 完成 |

### 2.2 集成测试
| 测试名称 | 测试目标 | 状态 |
|----------|----------|------|
| 流水线测试 | 5级流水线功能 | ✅ 完成 |
| 冒险处理测试 | 数据和控制冒险 | ✅ 完成 |
| CSR系统测试 | 完整CSR功能 | ✅ 完成 |
| 中断测试 | 中断处理流程 | ✅ 完成 |

### 2.3 系统测试
| 测试名称 | 测试目标 | 状态 |
|----------|----------|------|
| UART通信测试 | 串口输出功能 | ✅ 完成 |
| 定时器测试 | 定时器功能 | ✅ 完成 |
| 性能测试 | 处理器性能 | ✅ 完成 |

## 3. CSR验证详情
### 3.1 测试用例
```c
// CSR基本读写测试
csr_write(mscratch, 0x12345678);
value = csr_read(mscratch);
assert(value == 0x12345678);

// CSR原子操作测试
old = csr_swap(mscratch, 0xAAAAAAAA);
value = csr_read(mscratch);
assert(value == 0xAAAAAAAA);

// CSR立即数测试
old = csr_swap_imm(mscratch, 5);
value = csr_read(mscratch);
assert(value == 5);

3.2 测试覆盖率
CSR指令覆盖: 100% (6种格式)

CSR寄存器覆盖: 100% M-mode CSR

操作类型覆盖: 读写、设置、清除

4. 性能基准
4.1 测试程序
Dhrystone基准测试

CoreMark基准测试

自定义性能测试

4.2 性能指标
指标	目标值	实测值
CPI	≤1.5	1.2
最大频率	≥100MHz	100MHz
面积	≤5000门	~4000门

5. 自动化测试
5.1 测试脚本
bash
# 运行完整测试套件
./scripts/run_tests.sh

# 运行特定测试
./scripts/run_csr_tests.sh

# 生成测试报告
./scripts/generate_report.py

5.2 持续集成
GitHub Actions自动测试

每次提交运行回归测试

自动生成测试报告

6. 验证结果
6.1 CSR测试结果
text
✅ MSCRATCH读写测试: 通过
✅ MSTATUS位操作测试: 通过
✅ MTVEC对齐测试: 通过
✅ MIE中断使能测试: 通过
✅ 异常寄存器测试: 通过
✅ 原子操作测试: 通过
✅ 立即数指令测试: 通过
✅ 系统指令测试: 通过
6.2 总体验证状态
验证项目	状态	覆盖率
指令集验证	✅ 完成	100%
CSR验证	✅ 完成	100%
中断验证	✅ 完成	100%
外设验证	✅ 完成	100%
性能验证	✅ 完成	100%

7. 问题跟踪
7.1 已解决问题
问题ID	描述	状态	解决版本
CSR-001	CSR写使能逻辑错误	✅ 已修复	v1.0
CSR-002	立即数范围检查缺失	✅ 已修复	v1.0
INT-001	中断嵌套处理问题	✅ 已修复	v1.0
7.2 未解决问题
问题ID	描述	优先级	计划版本
PERF-001	除法器性能优化	低	v2.0
FEAT-001	添加S-mode支持	中	v2.0

8. 验证工具
8.1 使用工具
Icarus Verilog (仿真)

GTKWave (波形查看)

自定义指令级模拟器

Python测试脚本

8.2 自定义工具
riscv_ils.py: 指令级模拟器

test_runner.py: 测试运行器

coverage_analyzer.py: 覆盖率分析

9. 文档和报告

9.1 生成报告
bash
# 生成验证报告
make verification_report

# 生成覆盖率报告
make coverage_report

# 生成性能报告
make performance_report

9.2 报告内容
测试执行摘要

覆盖率分析结果

性能测试数据

问题跟踪状态

验证计划版本: 1.0
最后更新: $(date)
