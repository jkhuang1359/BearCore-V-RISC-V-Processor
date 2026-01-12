## 1. 時脈訊號 (Clock signal) - 對應板子上的 100MHz 晶振
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
# 這裡定義時脈約束，告訴 Vivado 我們要跑 100MHz (10ns)
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports clk]

## 2. 重置訊號 (Reset) - 對應板子上的 Switch 0
# rst_n 是低電位重置 (Active Low)
# Switch 下撥 (0) = 重置, 上撥 (1) = 正常運作
set_property PACKAGE_PIN V17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## 3. UART (USB-RS232 Interface)
# 注意：這是從 FPGA 的角度看
# uart_rx_i (FPGA 收) <--- 接到 ---> USB-UART TX
set_property PACKAGE_PIN B18 [get_ports uart_rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_i]

# uart_tx_o (FPGA 送) ---> 接到 ---> USB-UART RX
set_property PACKAGE_PIN A18 [get_ports uart_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_o]

## 4. (選用) 設定組態電壓，避免寫入時報錯
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]