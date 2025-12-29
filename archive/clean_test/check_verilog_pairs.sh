#!/bin/bash
echo "Verilog语法配对检查"
echo "==================="

check_file() {
    local file=$1
    echo "检查文件: $file"
    
    # 检查begin/end配对
    local begin_count=$(grep -c "begin" "$file")
    local end_count=$(grep -c "end" "$file")
    
    if [ "$begin_count" -ne "$end_count" ]; then
        echo "❌ begin/end不匹配: begin=$begin_count, end=$end_count"
        return 1
    else
        echo "✅ begin/end匹配: $begin_count 对"
    fi
    
    # 检查if/else配对（简单统计）
    local if_count=$(grep -c "\bif\b" "$file")
    local else_count=$(grep -c "\belse\b" "$file")
    
    echo "  if语句: $if_count, else语句: $else_count"
    
    # 使用iverilog进行语法检查
    echo "运行语法检查..."
    iverilog -t null "$file" 2>&1 | head -20
    
    return 0
}

# 检查当前目录的Verilog文件
for file in *.v; do
    if [ -f "$file" ]; then
        check_file "$file"
        echo ""
    fi
done
