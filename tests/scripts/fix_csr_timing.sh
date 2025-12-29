#!/bin/bash
# fix_csr_timing.sh

echo "=== 修復 CSR 時序問題 ==="

# 備份原始文件
cp src/core.v src/core.v.backup.timing.$(date +%s)

# 1. 修復CSR寫數據的時序問題
echo "修復CSR寫數據時序..."
cat > csr_timing_fix.patch << 'EOF'
--- a/src/core.v
+++ b/src/core.v
@@ -78,6 +78,7 @@ module core(
     reg [1:0] mem_csr_op;
     reg mem_csr_use_imm;
     reg [11:0] mem_csr_addr;    
+    reg [31:0] mem_csr_wdata;  // 新增：在MEM階段保存CSR寫入數據
 
     // MEM/WB 流水線寄存器中的 CSR 相關信號
     reg wb_is_csr, wb_is_system;
@@ -262,6 +263,7 @@ module core(
             mem_is_csr <= ex_is_csr;
             mem_is_system <= ex_is_system;
             mem_csr_op <= ex_csr_op;
+            mem_csr_wdata <= (ex_csr_use_imm) ? ex_imm : fwd_rs1;  // 在EX階段計算，MEM階段使用
             mem_csr_use_imm <= ex_csr_use_imm;
             mem_csr_addr <= ex_csr_addr;            
         end
@@ -430,10 +432,10 @@ module core(
                         wb_alu_result;
 
     // 5. CSR 寫入數據選擇
-    wire [31:0] csr_wdata_temp = ex_csr_use_imm  ? ex_imm : fwd_rs1;
-    assign csr_wdata = csr_wdata_temp;
+    // CSR寫入數據現在在MEM階段使用mem_csr_wdata
+    assign csr_wdata = mem_csr_wdata;
     assign csr_we = mem_is_csr && (mem_csr_op == 2'b00 || |csr_wdata);
-    
+
     // 調試寄存器寫入
     always @(posedge clk) begin
         if (wb_reg_wen && wb_rd_addr == 5'b01011) begin  // a1 是 x11
@@ -460,7 +462,7 @@ module core(
 
     // 調試 CSR 數據流
     always @(posedge clk) begin
-        if (ex_is_csr && ex_csr_addr == 12'h340) begin
+        if (mem_is_csr && mem_csr_addr == 12'h340) begin
             $display("[CSR-FLOW-DEBUG] EX stage: csr_wdata=0x%h, ex_csr_use_imm=%b, fwd_rs1=0x%h, ex_imm=0x%h",
                     csr_wdata, ex_csr_use_imm, fwd_rs1, ex_imm);
         end
@@ -476,37 +478,16 @@ module core(
         end
     end    
 
-    // ========== 關鍵 CSR 調試 ==========
+    // ========== 修正後的CSR調試 ==========
     always @(posedge clk) begin
-        // 追蹤 CSR 指令在流水線中的流動
-        if (id_is_csr) begin
-            $display("[PIPELINE-CSR] ID: addr=0x%h, rs1=%d, rd=%d, imm=%b, op=%b",
-                    id_csr_addr, id_rs1_addr, id_rd_addr, id_csr_use_imm, id_csr_op);
+        if (mem_is_csr && mem_csr_addr == 12'h340) begin
+            $display("[CSR-MEM-DEBUG] addr=0x340, wdata=0x%h, we=%b, op=%b, mem_csr_wdata=0x%h",
+                    mem_csr_addr, csr_wdata, csr_we, mem_csr_op, mem_csr_wdata);
         end
         
-        if (ex_is_csr) begin
-            $display("[PIPELINE-CSR] EX: addr=0x%h, wdata=0x%h, we=%b, fwd_rs1=0x%h",
-                    ex_csr_addr, csr_wdata, csr_we, fwd_rs1);
+        if (csr_we && mem_csr_addr == 12'h340) begin
+            $display(">>> CSR ACTUAL WRITE: 0x%h -> CSR[0x340]", csr_wdata);
         end
-        
-        if (mem_is_csr) begin
-            $display("[PIPELINE-CSR] MEM: addr=0x%h, rdata=0x%h, we=%b, reg_wen=%b",
-                    mem_csr_addr, csr_rdata, csr_we, mem_reg_wen);
-            if (csr_we) begin
-                $display(">>> CSR ACTUAL WRITE: 0x%h -> CSR[0x%h]", csr_wdata, mem_csr_addr);
-            end
-        end
-        
-        // 追蹤寄存器寫入
-        if (wb_reg_wen && wb_rd_addr == 11) begin
-            $display("[REG-TRACE] a1 written: 0x%h at PC=0x%h", wb_reg_wdata, wb_pc);
-        end
-    end
-
-    // 實時監控 CSR 狀態
-    always @(posedge clk) begin
-        static integer csr_340_value = 0;
-        if (csr_we && mem_csr_addr == 12'h340) begin
-            csr_340_value = csr_wdata;
-            $display("!!! CSR[0x340] UPDATED: 0x%h (was 0x%h)", csr_wdata, csr_340_value);
-        end
     end    
                         
 endmodule
EOF

# 應用patch
if patch -p1 -i csr_timing_fix.patch; then
    echo "Patch應用成功"
else
    echo "Patch應用失敗，手動修復..."
    # 手動修復關鍵部分
    sed -i '78a\    reg [31:0] mem_csr_wdata;  // 新增：在MEM階段保存CSR寫入數據' src/core.v
    
    # 在EX/MEM流水線寄存器中添加mem_csr_wdata
    sed -i '/mem_csr_op <= ex_csr_op;/a\            mem_csr_wdata <= (ex_csr_use_imm) ? ex_imm : fwd_rs1;' src/core.v
    
    # 修改csr_wdata賦值
    sed -i 's/wire \[31:0\] csr_wdata_temp = ex_csr_use_imm  ? ex_imm : fwd_rs1;\n    assign csr_wdata = csr_wdata_temp;/    assign csr_wdata = mem_csr_wdata;/' src/core.v
fi

# 2. 修復CSR模塊的地址問題
echo "檢查CSR模塊連接..."
# CSR模塊使用csr_addr，但這個信號在ID階段生成，應該使用mem階段的地址
sed -i 's/\.csr_addr(csr_addr),/\.csr_addr(mem_csr_addr),/' src/core.v

# 3. 創建增強測試程序
echo "創建增強測試程序..."
cat > tests/enhanced_csr_test.s << 'EOF'
.section .text.init
.global _start

_start:
    li t0, 0x10000000  # UART地址
    
    # 開始標記
    li t1, 'S'
    sw t1, 0(t0)
    
    # 測試1: 寫入寄存器後立即使用（測試前推）
    li a1, 0x12345678
    
    # 插入更多的nop確保數據可用
    nop
    nop
    nop
    nop
    nop
    nop
    
    # 寫入CSR
    csrw 0x340, a1
    
    # 寫入標記
    li t1, 'W'
    sw t1, 0(t0)
    
    # 讀取CSR
    csrr a2, 0x340
    
    # 讀取標記
    li t1, 'R'
    sw t1, 0(t0)
    
    # 比較
    beq a1, a2, test1_pass
    
test1_fail:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j test2
    
test1_pass:
    li t1, '1'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
test2:
    # 測試2: 直接寫入立即數到CSR
    csrwi 0x340, 0x89ABCDEF
    
    # 讀取並驗證
    csrr a3, 0x340
    li t2, 0x89ABCDEF
    beq a3, t2, test2_pass
    
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'F'
    sw t1, 0(t0)
    j end
    
test2_pass:
    li t1, '2'
    sw t1, 0(t0)
    li t1, 'P'
    sw t1, 0(t0)
    
end:
    li t1, '\n'
    sw t1, 0(t0)
    j end
EOF

# 4. 重新編譯和測試
echo "重新編譯..."
make clean
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
    -ffreestanding -T link.ld tests/enhanced_csr_test.s -o firmware.elf
riscv64-unknown-elf-objcopy -O binary firmware.elf firmware.bin
od -An -t x4 -w4 -v firmware.bin | tr -d ' ' > firmware.hex

echo "運行模擬測試..."
echo "========================================"
iverilog -g2012 -o wave.vvp -f files.f && vvp wave.vvp | head -100
echo "========================================"

echo "修復完成！"