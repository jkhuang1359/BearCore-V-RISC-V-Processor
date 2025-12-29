#!/bin/bash
echo "運行仿真..."
vvp debug.vvp
echo "仿真完成！"
echo "波形文件: debug.vcd"
echo "查看波形: gtkwave debug.vcd"
