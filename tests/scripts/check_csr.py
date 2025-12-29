import re
import sys

def verify_mscratch_result(log_file):
    # 定義匹配模式，對應 main.c 裡的輸出格式
    success_pattern = r"CSR Success: 0x([0-9A-Fa-f]+)"
    fail_pattern = r"CSR FAILED! Read: 0x([0-9A-Fa-f]+)"
    expected_val = "DEADBEEF"
    
    found = False
    print(f"--- 正在分析 {log_file} ---")
    
    try:
        with open(log_file, 'r') as f:
            for line in f:
                # 1. 檢查是否成功讀寫
                success_match = re.search(success_pattern, line)
                if success_match:
                    found = True
                    read_val = success_match.group(1).upper()
                    if read_val == expected_val:
                        print(f"✅ [驗證通過] mscratch 讀寫正確: 0x{read_val}")
                        return True
                    else:
                        print(f"❌ [數值錯誤] 讀回 0x{read_val}，但預期為 0x{expected_val}")
                        return False
                
                # 2. 檢查硬體是否回報失敗
                fail_match = re.search(fail_pattern, line)
                if fail_match:
                    found = True
                    read_val = fail_match.group(1).upper()
                    print(f"❌ [硬體回報失敗] CSR 測試未通過，讀到值: 0x{read_val}")
                    return False
        
        if not found:
            print("⚠️ [警告] 在日誌中找不到 CSR 測試相關訊息。")
            print("   這通常代表 CPU 在執行到 CSR 測試前就已經跑飛或卡死了。")
            print("   請檢查 core.v 的 div_stall 邏輯是否已修復。")
            return False
            
    except FileNotFoundError:
        print(f"❌ [錯誤] 找不到 {log_file}，請先執行 make sim。")
        return False

if __name__ == "__main__":
    # 預設檢查 simulation.log
    if not verify_mscratch_result("simulation.log"):
        sys.exit(1) # 回傳錯誤碼給 Makefile