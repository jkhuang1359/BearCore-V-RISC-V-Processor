# BearCore-V 中断集成开发工作流

## 开发原则
1. **渐进式集成**：分阶段实现，每个阶段可独立验证
2. **不破坏原则**：新功能不能破坏现有功能
3. **完全测试**：每个阶段必须有完整的测试套件
4. **版本控制**：使用Git管理每个阶段

## 标准工作流程

### 步骤1：启动新阶段
```bash
# 查看当前状态
./interrupt_dev/phase_manager.sh status

# 进入下一阶段
./interrupt_dev/phase_manager.sh next

# 或直接切换到特定阶段
./interrupt_dev/scripts/switch_to_phase.sh 1
步骤2：阶段开发
在 interrupt_dev/phases/phase[阶段号]/ 中开发

创建阶段专用的核心版本

创建阶段专用的CSR版本

创建阶段测试程序

步骤3：验证测试
bash
# 编译和运行阶段测试
cd interrupt_dev/phases/phase[阶段号]
make compile
make run

# 或使用主项目的测试
make test TEST=tests/phase_test.s
步骤4：回归测试
bash
# 运行原有测试套件，确保不破坏功能
./interrupt_dev/scripts/run_regression_tests.sh
步骤5：提交结果
bash
# 提交到Git
git add .
git commit -m "阶段[阶段号]: [功能描述]"

# 或创建分支
git checkout -b feature/phase-[阶段号]-[功能名称]
阶段完成标准
每个阶段完成后必须满足：

阶段0：基准测试
所有原有测试通过

性能基线记录

波形参考保存

阶段1：中断检测
中断输入信号接口定义

中断状态寄存器可读

不影响原有指令执行

调试输出正常工作

阶段2：中断跳转
中断触发时PC跳转到mtvec

mepc正确保存中断点

mret指令返回中断点

流水线正确冲刷

阶段3：CSR支持
mie寄存器可读写

mip寄存器反映中断状态

mcause寄存器记录中断原因

中断使能控制工作

阶段4：异常处理
非法指令异常触发

内存访问异常触发

系统调用异常处理

异常与中断共存

阶段5：嵌套中断
高优先级中断可打断低优先级

中断返回恢复正确上下文

中断屏蔽功能工作

中断优先级仲裁正确

阶段6：性能优化
中断延迟测量

关键路径优化

面积评估

功耗估算

调试工具
阶段监控：./interrupt_dev/scripts/develop_monitor.sh

波形查看：保存VCD文件到 interrupt_dev/waveforms/

日志分析：查看 interrupt_dev/logs/ 中的日志

性能分析：使用性能计数器

故障排除
常见问题
编译错误：检查Verilog语法，确保generate循环变量声明正确

仿真失败：检查测试程序，确保指令正确

功能异常：查看波形，分析流水线状态

性能下降：测量关键路径，优化逻辑

调试步骤
运行最小测试程序

查看仿真波形

添加调试打印

分模块验证

回归测试验证

版本管理
Git分支策略
text
main (稳定版)
├── feature/phase-1-interrupt-detect
├── feature/phase-2-interrupt-jump
├── feature/phase-3-csr-support
└── develop (集成分支)
标签策略
v1.0-baseline：阶段0完成

v1.1-interrupt-detect：阶段1完成

v1.2-interrupt-jump：阶段2完成

v1.3-csr-support：阶段3完成

v2.0-full-interrupt：所有阶段完成
