#!/bin/bash
echo "=== RISC-V CPU 診斷工具 ==="
echo "1. 檢查信號完整性..."
echo "2. 驗證指令解碼..."
echo "3. 測試數據通路..."
echo "4. 查看波形文件..."
echo "請選擇操作 (1-4): "
read choice

case $choice in
    1)
        echo "檢查關鍵信號..."
        if [ -f "debug.vcd" ]; then
            vcd2vpd debug.vcd debug.vpd
            echo "創建了VPD文件: debug.vpd"
        else
            echo "未找到波形文件"
        fi
        ;;
    2)
        echo "驗證指令解碼..."
        echo "檢查decoder.v中的opcode定義..."
        grep -n "OP_BRANCH" decoder.v
        grep -n "7'b1100011" decoder.v
        ;;
    3)
        echo "測試數據通路..."
        echo "創建測試程序..."
        cat > test_beq.hex << 'TEST'
00100093  # addi x1, x0, 1
00100113  # addi x2, x0, 1
00808063  # beq x1, x2, 16
00000013  # nop
00000013  # nop
00000013  # nop
00500093  # 跳轉目標: addi x1, x0, 5
TEST
        echo "測試程序已創建: test_beq.hex"
        ;;
    4)
        if command -v gtkwave &> /dev/null; then
            gtkwave debug.vcd &
        else
            echo "未安裝gtkwave，請先安裝: sudo apt-get install gtkwave"
        fi
        ;;
    *)
        echo "無效選擇"
        ;;
esac
