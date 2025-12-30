# --- run_vivado.tcl (Fixed) ---
# 定義專案名稱與晶片型號
set project_name "bearcore_verify"
set part_name "xc7a35tcpg236-1"

# 1. 建立記憶體中的專案 (In-Memory Project)
create_project -force $project_name ./vivado_temp -part $part_name

# 2. 加入 RTL 原始碼
# (注意：這裡使用 glob 可能會抓到不該抓的，建議明確指定或確保 src 目錄乾淨)
add_files [glob ./src/*.v]
add_files ./tests/bench/tb_top.v

add_files -fileset sim_1 ./firmware.hex
set_property file_type {Memory File} [get_files ./firmware.hex]

# 3. 設定 Top Module
set_property top tb_top [get_filesets sim_1]

# 4. 啟動模擬 (Behavioral Simulation)
# 🏆 修正：加上反斜線 \[ \] 避免 Tcl 誤判為指令
puts "\n--- \[Vivado\] Launching Simulation... ---"
launch_simulation

# 5. 執行模擬直到 $finish
# -notrace 可以減少雜訊
run all

# 6. 關閉專案
close_project
quit