# --- build_fpga.tcl (Final Fixed) ---
set project_name "bearcore_fpga"
# 請確認這是您板子的型號 (Basys 3)
set part_name "xc7a35tcpg236-1" 

# 1. 建立專案
create_project -force $project_name ./vivado_fpga -part $part_name

# 2. 加入 RTL 原始碼
add_files [glob ./src/*.v]

# 3. 🏆 關鍵修正：加入韌體並設定屬性
# 將 firmware.hex 加入 sources_1 (給綜合用) 和 sim_1 (給模擬用)
add_files -fileset sources_1 ./firmware.hex
add_files -fileset sim_1 ./firmware.hex

# 🔥 重點：告訴 Vivado 這是一個 Memory File
# 這樣它才會在 Synthesis 時被正確複製到 run directory
set_property file_type {Memory File} [get_files ./firmware.hex]

# 4. 加入 XDC 約束檔
add_files -fileset constrs_1 ./constraints.xdc

# 5. 設定 Top Module
set_property top core [get_filesets sources_1]

# 6. 開始綜合 (Synthesis)
puts "\n--- \[Vivado\] Starting Synthesis... ---"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
# 檢查綜合是否成功
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "❌ Synthesis Failed!"
    exit 1
}

# 7. 開始實作 (Implementation)
puts "\n--- \[Vivado\] Starting Implementation... ---"
launch_runs impl_1 -jobs 4
wait_on_run impl_1
# 檢查實作是否成功
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "❌ Implementation Failed!"
    exit 1
}

# 8. 產生 Bitstream
puts "\n--- \[Vivado\] Generating Bitstream... ---"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# ========================================================
# 9. 📊 產生期末成績單
# ========================================================
open_run impl_1

puts "\n============================================="
puts "       🐻 BearCore-V FPGA Report Card       "
puts "============================================="

set timing_paths [get_timing_paths -max_paths 1 -nworst 1 -setup]

if {[llength $timing_paths] > 0} {
    set wns [get_property SLACK $timing_paths]
    puts "🎯 Target Clock: 40 MHz (25.000 ns)"

    if {$wns < 0} {
        puts "❌ TIMING FAILED! WNS: $wns ns"
        puts "   -> Circuit is too slow. Try lowering frequency or optimizing ALU."
    } else {
        puts "✅ TIMING PASSED! WNS: $wns ns"
        puts "   -> Perfect! Your core can run at 100MHz."
    }
} else {
    puts "⚠️  WARNING: No timing paths found!"
    puts "   -> It implies logic was optimized away (empty ROM?)"
}

# 檢查資源使用量
set util_report [report_utilization -return_string]
if {[regexp {Slice LUTs\s*\|\s*(\d+)} $util_report -> luts]} {
    regexp {Slice Registers\s*\|\s*(\d+)} $util_report -> regs
    puts "---------------------------------------------"
    puts "📦 Resource Usage:"
    puts "   - Slice LUTs: $luts"
    puts "   - Registers:  $regs"
}
puts "============================================="

close_project
quit