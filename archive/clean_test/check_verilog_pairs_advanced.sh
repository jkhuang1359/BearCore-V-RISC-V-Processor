#!/bin/bash
echo "高級Verilog語法配對檢查"
echo "========================"

check_file_advanced() {
    local file=$1
    echo "檢查文件: $file"
    
    # 更精確的begin/end配對檢查
    local line_num=1
    local indent=0
    local errors=0
    local in_comment=0
    local last_nonempty_line=""
    
    while IFS= read -r line; do
        # 處理多行註釋
        if [[ $line =~ "/*" ]] && [[ ! $line =~ "*/" ]]; then
            in_comment=1
        fi
        if [[ $line =~ "*/" ]]; then
            in_comment=0
        fi
        
        if [ $in_comment -eq 0 ]; then
            # 移除單行註釋
            clean_line=$(echo "$line" | sed 's/\/\/.*$//')
            
            # 計算begin和end
            local begin_count=$(echo "$clean_line" | grep -o "\bbegin\b" | wc -l)
            local end_count=$(echo "$clean_line" | grep -o "\bend\b" | wc -l)
            
            # 簡單的縮進檢查（用於顯示）
            local spaces=$(echo "$clean_line" | grep -o '^[[:space:]]*' | wc -c)
            local current_indent=$((spaces / 2))
            
            # 檢查配對
            if [ $begin_count -gt 0 ] || [ $end_count -gt 0 ]; then
                echo "  第$line_num行: indent=$current_indent, begin=$begin_count, end=$end_count"
                if [[ $clean_line =~ "\bbegin\b.*\bend\b" ]] || [[ $clean_line =~ "\bend\b.*\bbegin\b" ]]; then
                    echo "    ⚠️  同一行有begin和end，可能導致計數不準"
                fi
            fi
            
            # 記錄最後的非空行
            if [ -n "$(echo "$clean_line" | tr -d '[:space:]')" ]; then
                last_nonempty_line="$line_num: $clean_line"
            fi
        fi
        
        ((line_num++))
    done < "$file"
    
    # 顯示文件最後幾行
    echo "  文件結尾檢查:"
    tail -5 "$file" | nl -ba | sed 's/^/    /'
    
    echo ""
}

# 檢查當前目錄的Verilog文件
for file in *.v; do
    if [ -f "$file" ]; then
        check_file_advanced "$file"
    fi
done

echo "檢查完成"
echo ""
echo "建議："
echo "1. 使用標準縮進（2或4空格）"
echo "2. 避免在同一行寫begin和end"
echo "3. 使用編輯器的括號高亮功能"
