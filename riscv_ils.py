import sys
import os
import struct
import math

# ==============================================================================
# 🗺️ BearCore-V v1.1.1 Memory Map (Updated)
# ==============================================================================
MMIO_BASE       = 0x10000000
UART_DATA_ADDR  = 0x10000000 # R/W: Data & BIST Control
UART_STATUS_ADDR= 0x10000004 # RO:  Status
MTIME_L_ADDR    = 0x10000008 # R/W: Machine Time Low
MTIME_H_ADDR    = 0x1000000C # R/W: Machine Time High
MTIMECMP_L_ADDR = 0x10000010 # R/W: Compare Low
MTIMECMP_H_ADDR = 0x10000014 # R/W: Compare High
UART_IE_ADDR    = 0x10000018 # R/W: UART Interrupt Enable (New!)

class RISCV_ILS:
    def __init__(self, rom_path):
        self.registers = [0] * 32
        # 🏆 修正：SP 設為 RAM 的頂端 (0x1f000)，符合 link.ld
        self.registers[2] = 0x00010000 

        self.uart_ie = 0
        # 🏆 新增：UART 接收隊列 (模擬 RX FIFO)
        self.rx_queue = []
        self.ram = {}       
        # CSR 寄存器
        self.csr = {
            'mstatus': 0x00000000,
            'misa': 0x40001100,  # RV32IM
            'mie': 0x00000000,
            'mtvec': 0x00000100, 
            'mscratch': 0x00000000,
            'mepc': 0x00000000,
            'mcause': 0x00000000,
            'mtval': 0x00000000,
            'mip': 0x00000000,
        }
        
        # 🏆 Timer 與週邊狀態
        self.mtime = 0
        self.mtimecmp = 0xFFFFFFFFFFFFFFFF # 預設最大值，避免一開機就中斷
        self.uart_ie = 0                   # 預設 UART 中斷全關
        
        # 中斷狀態
        self.interrupt_enabled = False     # Global MIE
        self.uart_int_pending = False      # UART 中斷等待中
        
        self.pc = 0
        self.rom = self._load_rom(rom_path)
        self.uart_output = ""
        self.halted = False
        
        # 例外處理狀態
        self.in_exception = False
        
        # 調試選項
        self.debug = False
        self.cycle_count = 0
        self.instruction_count = 0

    def queue_input(self, text):
        for char in text:
            self.rx_queue.append(ord(char))
    def _load_rom(self, path):
        rom_data = {}
        try:
            with open(path, 'r') as f:
                addr = 0
                for line in f:
                    line = line.strip()
                    if not line: continue
                    if line.startswith('@'):
                        try: addr = int(line[1:], 16)
                        except: pass
                        continue
                    try:
                        line = line.replace(' ', '')
                        if len(line) == 8:
                            rom_data[addr] = int(line, 16)
                            addr += 4
                    except: pass
        except Exception as e:
            print(f"Load ROM Error: {e}")
            sys.exit(1)
        return rom_data

    def _read_mem(self, addr, size=4):
        # 🏆 首先檢查特殊地址
        # --- MMIO 區域 ---
        if addr >= MMIO_BASE and addr <= UART_IE_ADDR + 4:
            if addr == UART_DATA_ADDR:
                # 🏆 讀取資料：從隊列彈出一個字元
                if len(self.rx_queue) > 0:
                    char_code = self.rx_queue.pop(0) # 取出最早的字
                    if self.debug: print(f"[UART_RX] CPU Read: '{chr(char_code)}'")
                    return char_code
                return 0 # 沒資料讀到 0
            elif addr == UART_STATUS_ADDR:
                # 🏆 狀態邏輯：
                # Bit 0 (TX_BUSY): 模擬器總是瞬間送完，所以永遠是 0 (Idle)
                # Bit 1 (RX_READY): 如果隊列有東西，就設為 1
                status = 0
                if len(self.rx_queue) > 0:
                    status |= 0x02 # RX_READY = 1
                return status
                return 0 
            elif addr == MTIME_L_ADDR:
                return self.mtime & 0xFFFFFFFF
            elif addr == MTIME_H_ADDR:
                return (self.mtime >> 32) & 0xFFFFFFFF
            elif addr == MTIMECMP_L_ADDR:
                return self.mtimecmp & 0xFFFFFFFF
            elif addr == MTIMECMP_H_ADDR:
                return (self.mtimecmp >> 32) & 0xFFFFFFFF
            elif addr == UART_IE_ADDR:
                return self.uart_ie # 🏆 支援讀回 IE 暫存器
            return 0
        
        # 🏆 讀取邏輯：優先檢查 RAM (是否有被修改過？)
        # 我們逐個 byte 檢查，因為寫入可能是 byte 級別的
        val = 0
        found_in_ram = False
        
        # 嘗試從 RAM 拼湊數據
        temp_val = 0
        for i in range(size):
            byte_addr = addr + i
            if byte_addr in self.ram:
                temp_val |= (self.ram[byte_addr] << (i * 8))
                found_in_ram = True
            else:
                # 如果 RAM 裡沒有，去 ROM 找找看 (唯讀數據/指令)
                # ROM 是以 4-byte 儲存的，所以要算一下
                rom_base = byte_addr & ~3
                if rom_base in self.rom:
                    rom_word = self.rom[rom_base]
                    byte_offset = byte_addr % 4
                    byte_val = (rom_word >> (byte_offset * 8)) & 0xFF
                    temp_val |= (byte_val << (i * 8))
                # 如果 ROM 也沒有，那就是 0
        
        # 符號擴展處理
        data = temp_val
        # 符號擴展 (Sign Extension)
        if size == 1: return struct.unpack('b', struct.pack('B', data & 0xFF))[0] & 0xFFFFFFFF
        elif size == 2: return struct.unpack('h', struct.pack('H', data & 0xFFFF))[0] & 0xFFFFFFFF
        return data & 0xFFFFFFFF

    # 🏆 重寫：記憶體寫入 (配合 v1.1.1 MMIO)
    def _write_mem(self, addr, data, size=4):
        # --- MMIO 區域 ---
        if addr >= MMIO_BASE and addr <= UART_IE_ADDR + 4:
            if addr == UART_DATA_ADDR:
                # 🏆 優化：只列印可見字元，過濾掉控制碼 (避免出現 )
                char_code = data & 0xFF
                if 32 <= char_code <= 126 or char_code in [10, 13]:
                    char = chr(char_code)
                    self.uart_output += char
                    if self.debug: print(f"UART TX: '{char}' (0x{data:02x})")            

            elif addr == MTIME_L_ADDR:
                # 寫入 mtime 不常見，但支援一下
                self.mtime = (self.mtime & 0xFFFFFFFF00000000) | (data & 0xFFFFFFFF)
            elif addr == MTIME_H_ADDR:
                self.mtime = (self.mtime & 0x00000000FFFFFFFF) | ((data & 0xFFFFFFFF) << 32)
            
            elif addr == MTIMECMP_L_ADDR:
                self.mtimecmp = (self.mtimecmp & 0xFFFFFFFF00000000) | (data & 0xFFFFFFFF)
            elif addr == MTIMECMP_H_ADDR:
                self.mtimecmp = (self.mtimecmp & 0x00000000FFFFFFFF) | ((data & 0xFFFFFFFF) << 32)
                if self.debug: print(f"TIMER: Set mtimecmp = 0x{self.mtimecmp:016x}")
            
            elif addr == UART_IE_ADDR:
                self.uart_ie = data & 0xFFFFFFFF
                if self.debug: print(f"UART: Set IE = 0x{self.uart_ie:x}")
                # 如果開啟 TX 中斷且 UART Idle，立即觸發 Pending
                if (self.uart_ie & 0x01):
                    self.uart_int_pending = True
                else:
                    # 如果關閉，清除 Pending (模擬 ISR 關閉中斷的動作)
                    self.uart_int_pending = False
            return
        # --- RAM 寫入 (維持原樣) ---
        for i in range(size):
            self.ram[addr + i] = (data >> (i * 8)) & 0xFF
        if self.debug and addr >= 0x1000 and addr < 0x3000:
            print(f"[MEM_WRITE] Addr={addr:#x}, Data={data:#x}")
        self.registers[0] = 0

    def _get_reg_name(self, idx):
        names = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", 
                 "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", 
                 "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]
        return names[idx]

    def print_state(self):
        print("\n--- 最終暫存器狀態 ---")
        for i in range(0, 32, 4):
            line = ""
            for j in range(4):
                if i+j < 32: line += f"x{i+j:02d} ({self._get_reg_name(i+j)}): {self.registers[i+j]:#010x}  "
            print(line)
        
        print("\n--- CSR 寄存器狀態 ---")
        for name, value in self.csr.items():
            print(f"{name}: {value:#010x}")
        
        print(f"\nUART 最終輸出: \"{self.uart_output}\"")
        print(f"總週期數: {self.cycle_count}")
        print(f"總指令數: {self.instruction_count}")

    # 🏆 新增：檢查中斷
    def _check_interrupts(self):
        # 1. 檢查 Global MIE (在 mstatus 中)
        mstatus_mie = (self.csr['mstatus'] >> 3) & 1
        if not mstatus_mie: return False

        # 2. 檢查 Timer 中斷 (Cause 7, bit 7 of mie/mip)
        timer_int = False
        if self.mtime >= self.mtimecmp:
            timer_int = True
        
        # 3. 檢查 UART 中斷 (Cause 16, bit 16 of mie)
        # 這裡簡化模擬：只要 uart_int_pending 為真且 mie[16] 開啟就觸發
        uart_int = False
        mie_uart = (self.csr['mie'] >> 16) & 1

        # 🏆 觸發條件更新：
        # 1. TX 中斷: (Pending=True) AND (TX_IE=1)
        # 2. RX 中斷: (Queue > 0) AND (RX_IE=1)
        tx_trigger = self.uart_int_pending and (self.uart_ie & 0x01)
        rx_trigger = (len(self.rx_queue) > 0) and (self.uart_ie & 0x02)
        
        if (tx_trigger or rx_trigger) and mie_uart:
            uart_int = True

        # 4. 優先權仲裁
        # 假設 UART (External) 優先於 Timer
        if uart_int:
            self._handle_interrupt(16) # 🏆 觸發 16 號中斷
            return True
        elif timer_int and ((self.csr['mie'] >> 7) & 1):
            self._handle_interrupt(7)
            return True
        
        return False
    # 🏆 新增：處理例外
    def _handle_exception(self, cause, tval=0):
        # 保存當前狀態
        self.csr['mepc'] = self.pc
        self.csr['mcause'] = cause
        self.csr['mtval'] = tval
        
        # 更新 mstatus
        old_mie = (self.csr['mstatus'] >> 3) & 1
        self.csr['mstatus'] &= ~0x8  # 清除 MIE
        self.csr['mstatus'] &= ~0x80  # 清除 MPIE
        if old_mie:
            self.csr['mstatus'] |= 0x80  # 設置 MPIE = 1
        
        # 跳轉到例外處理程序
        self.pc = self.csr['mtvec']
        self.in_exception = True
        
        if self.debug:
            print(f"[EXCEPTION] PC={self.csr['mepc']:#x}, Cause={cause:#x}, TVAL={tval:#x}")

    # 🏆 新增：處理中斷
    def _handle_interrupt(self, cause):
        # 中斷處理類似例外，但 mcause 最高位為 1
        self._handle_exception(0x80000000 | cause)
        
        # 清除中斷暫存
        if cause == 7:  # 定時器中斷
            self.timer_int_pending = False
        elif cause == 3:  # 軟體中斷
            self.software_int_pending = False
        elif cause == 11:  # 外部中斷
            self.external_int_pending = False
        elif cause == 16: #串列埠中斷
            self.uart_int_pending = False

    def run(self, max_cycles=150000):
        print(f"--- RISC-V ILS 模擬啟動 (載入 {len(self.rom)} 條指令) ---")
        self.cycle_count = 0
        
        # 設置起始 PC
        self.pc = 0
        print(f"起始 PC: {self.pc:#x}")
        
        # 顯示 ROM 中的前幾條指令
        print("\nROM 中的前 10 條指令:")
        for i in range(0, min(10 * 4, max(self.rom.keys()) + 4), 4):
            if i in self.rom:
                print(f"  0x{i:08x}: {self.rom[i]:08x}")
            else:
                print(f"  0x{i:08x}: (未定義)")
        
        # 設置例外處理程序地址
        if 0x100 in self.rom:
            print(f"例外向量表 (0x100) 的指令: {self.rom[0x100]:08x}")
        
        while self.cycle_count < max_cycles and not self.halted:
            # 🏆 更新定時器
            self.mtime += 1
            
            # 讀取指令
            if self.pc in self.rom:
                inst = self.rom[self.pc]
            else:
                # 如果 PC 不在 ROM 中，檢查是否為有效的記憶體位置
                if self.pc < 0x10000:  # 假設 ROM 在低 64KB
                    inst = 0
                    print(f"[WARN] PC {self.pc:#x} 不在 ROM 中，指令設為 0")
                else:
                    # 可能是記憶體映射 I/O，跳過
                    inst = 0
            
            # 執行指令
            self._execute_instruction(inst)
            self.cycle_count += 1
            
            # 🏆 週期性狀態報告
            if self.cycle_count % 100000 == 0:
                print(f"週期 {self.cycle_count}, PC={self.pc:#x}")
        
        print(f"\n--- 模擬結束: {self.cycle_count} 週期 ---")
        self.print_state()

    def _execute_instruction(self, inst):
        if self.cycle_count < 20:
                opcode = inst & 0x7F
                print(f"[EXEC {self.cycle_count:3d}] PC={self.pc:#08x}, Inst={inst:#010x}, Opcode={opcode:#04x}")
        
        opcode = inst & 0x7F
        rd = (inst >> 7) & 0x1F
        funct3 = (inst >> 12) & 0x7
        rs1 = (inst >> 15) & 0x1F
        rs2 = (inst >> 20) & 0x1F
        funct7 = (inst >> 25) & 0x7F
        csr_addr = (inst >> 20) & 0xFFF
        
        pc_next = self.pc + 4
        
        val_rs1 = self.registers[rs1]
        val_rs2 = self.registers[rs2]

        # 🏆 更新指令計數
        self.instruction_count += 1

        # LUI
        if opcode == 0b0110111: 
            self.registers[rd] = ((inst >> 12) << 12) & 0xFFFFFFFF
        
        # AUIPC
        elif opcode == 0b0010111: 
            self.registers[rd] = (self.pc + ((inst >> 12) << 12)) & 0xFFFFFFFF
        
        # JAL
        elif opcode == 0b1101111:
            self.registers[rd] = self.pc + 4
            imm = ((inst >> 21) & 0x3FF) << 1 | ((inst >> 20) & 1) << 11 | ((inst >> 12) & 0xFF) << 12 | ((inst >> 31) & 1) << 20
            if imm & 0x100000: imm |= 0xFFE00000
            pc_next = (self.pc + imm) & 0xFFFFFFFF
        
        # JALR
        elif opcode == 0b1100111:
            imm = (inst >> 20)
            if imm & 0x800: imm |= 0xFFFFF000
            self.registers[rd] = self.pc + 4
            pc_next = (val_rs1 + imm) & ~1 & 0xFFFFFFFF
        
        # Branch
        elif opcode == 0b1100011:
            imm = ((inst >> 8) & 0xF) << 1 | ((inst >> 25) & 0x3F) << 5 | ((inst >> 7) & 1) << 11 | ((inst >> 31) & 1) << 12
            if imm & 0x1000: imm |= 0xFFFFE000
            take = False
            if funct3 == 0: take = (val_rs1 == val_rs2)
            elif funct3 == 1: take = (val_rs1 != val_rs2)
            elif funct3 == 4: take = (val_rs1 < val_rs2)
            elif funct3 == 5: take = (val_rs1 >= val_rs2)
            elif funct3 == 6: take = ((val_rs1 & 0xFFFFFFFF) < (val_rs2 & 0xFFFFFFFF))
            elif funct3 == 7: take = ((val_rs1 & 0xFFFFFFFF) >= (val_rs2 & 0xFFFFFFFF))
            if take: pc_next = (self.pc + imm) & 0xFFFFFFFF
        
        # Load
        elif opcode == 0b0000011:
            imm = (inst >> 20)
            if imm & 0x800: imm |= 0xFFFFF000
            addr = (val_rs1 + imm) & 0xFFFFFFFF
            if funct3 == 0: self.registers[rd] = self._read_mem(addr, 1) & 0xFFFFFFFF
            elif funct3 == 1: self.registers[rd] = self._read_mem(addr, 2) & 0xFFFFFFFF
            elif funct3 == 2: self.registers[rd] = self._read_mem(addr, 4) & 0xFFFFFFFF
            elif funct3 == 4: self.registers[rd] = self._read_mem(addr, 1) & 0xFF
            elif funct3 == 5: self.registers[rd] = self._read_mem(addr, 2) & 0xFFFF
        
        # Store
        elif opcode == 0b0100011:
            imm = ((inst >> 7) & 0x1F) | ((inst >> 25) << 5)
            if imm & 0x800: imm |= 0xFFFFF000
            addr = (val_rs1 + imm) & 0xFFFFFFFF
            if funct3 == 0: self._write_mem(addr, val_rs2, 1)
            elif funct3 == 1: self._write_mem(addr, val_rs2, 2)
            elif funct3 == 2: self._write_mem(addr, val_rs2, 4)
        
        # ALU Imm
        elif opcode == 0b0010011:
            imm = (inst >> 20)
            if imm & 0x800: imm |= 0xFFFFF000
            if funct3 == 0: self.registers[rd] = (val_rs1 + imm) & 0xFFFFFFFF
            elif funct3 == 2: self.registers[rd] = 1 if val_rs1 < imm else 0
            elif funct3 == 3: self.registers[rd] = 1 if (val_rs1 & 0xFFFFFFFF) < (imm & 0xFFFFFFFF) else 0
            elif funct3 == 4: self.registers[rd] = (val_rs1 ^ imm) & 0xFFFFFFFF
            elif funct3 == 6: self.registers[rd] = (val_rs1 | imm) & 0xFFFFFFFF
            elif funct3 == 7: self.registers[rd] = (val_rs1 & imm) & 0xFFFFFFFF
            elif funct3 == 1: self.registers[rd] = (val_rs1 << (imm & 0x1F)) & 0xFFFFFFFF
            elif funct3 == 5:
                if imm & 0x400: # SRAI
                    sign = val_rs1 & 0x80000000
                    res = val_rs1 >> (imm & 0x1F)
                    if sign: res |= (0xFFFFFFFF << (32 - (imm & 0x1F)))
                    self.registers[rd] = res & 0xFFFFFFFF
                else: self.registers[rd] = (val_rs1 >> (imm & 0x1F)) & 0xFFFFFFFF
        
        # ALU Reg
        elif opcode == 0b0110011:
            # 🏆 情況 A: M-Extension (乘除法) - funct7 == 0x01
            if funct7 == 0x01: 
                # 準備有號數 (Signed) 與無號數 (Unsigned) 的值
                s_rs1 = self.registers[rs1]
                if s_rs1 & 0x80000000: s_rs1 -= 0x100000000
                
                s_rs2 = self.registers[rs2]
                if s_rs2 & 0x80000000: s_rs2 -= 0x100000000
                
                u_rs1 = self.registers[rs1]
                u_rs2 = self.registers[rs2]

                if funct3 == 0:   # MUL (Lower 32-bit)
                    self.registers[rd] = (s_rs1 * s_rs2) & 0xFFFFFFFF
                elif funct3 == 1: # MULH (Upper 32-bit Signed)
                    self.registers[rd] = ((s_rs1 * s_rs2) >> 32) & 0xFFFFFFFF
                elif funct3 == 2: # MULHSU (Upper 32-bit, RS1 Signed * RS2 Unsigned)
                    self.registers[rd] = ((s_rs1 * u_rs2) >> 32) & 0xFFFFFFFF
                elif funct3 == 3: # MULHU (Upper 32-bit Unsigned)
                    self.registers[rd] = ((u_rs1 * u_rs2) >> 32) & 0xFFFFFFFF
                elif funct3 == 4: # DIV (Signed)
                    if s_rs2 == 0: 
                        self.registers[rd] = 0xFFFFFFFF # 除以 0 定義為 -1
                    elif s_rs1 == -2147483648 and s_rs2 == -1: # Overflow case
                        self.registers[rd] = -2147483648 & 0xFFFFFFFF
                    else:
                        self.registers[rd] = int(s_rs1 / s_rs2) & 0xFFFFFFFF
                elif funct3 == 5: # DIVU (Unsigned)
                    if u_rs2 == 0:
                        self.registers[rd] = 0xFFFFFFFF
                    else:
                        self.registers[rd] = (u_rs1 // u_rs2) & 0xFFFFFFFF
                elif funct3 == 6: # REM (Signed)
                    if s_rs2 == 0:
                        self.registers[rd] = u_rs1 # 除以 0 餘數等於被除數
                    elif s_rs1 == -2147483648 and s_rs2 == -1:
                        self.registers[rd] = 0
                    else:
                        # 使用 math.fmod 處理 Python 負數餘數行為差異
                        import math
                        self.registers[rd] = int(math.fmod(s_rs1, s_rs2)) & 0xFFFFFFFF
                elif funct3 == 7: # REMU (Unsigned)
                    if u_rs2 == 0:
                        self.registers[rd] = u_rs1
                    else:
                        self.registers[rd] = (u_rs1 % u_rs2) & 0xFFFFFFFF

            # 🏆 情況 B: 標準 R-Type (加減位移邏輯) - funct7 == 0x00 或 0x20
            else:
                if funct3 == 0: 
                    if funct7 == 0: self.registers[rd] = (val_rs1 + val_rs2) & 0xFFFFFFFF # ADD
                    else: self.registers[rd] = (val_rs1 - val_rs2) & 0xFFFFFFFF           # SUB
                elif funct3 == 1: self.registers[rd] = (val_rs1 << (val_rs2 & 0x1F)) & 0xFFFFFFFF # SLL
                elif funct3 == 2: self.registers[rd] = 1 if (struct.unpack('i', struct.pack('I', val_rs1))[0] < struct.unpack('i', struct.pack('I', val_rs2))[0]) else 0 # SLT (Signed)
                elif funct3 == 3: self.registers[rd] = 1 if (val_rs1 < val_rs2) else 0 # SLTU (Unsigned)
                elif funct3 == 4: self.registers[rd] = (val_rs1 ^ val_rs2) & 0xFFFFFFFF # XOR
                elif funct3 == 5:
                    if funct7 == 0x20: # SRA (算術右移)
                        sign = val_rs1 & 0x80000000
                        res = val_rs1 >> (val_rs2 & 0x1F)
                        if sign: res |= (0xFFFFFFFF << (32 - (val_rs2 & 0x1F)))
                        self.registers[rd] = res & 0xFFFFFFFF
                    else: self.registers[rd] = (val_rs1 >> (val_rs2 & 0x1F)) & 0xFFFFFFFF # SRL
                elif funct3 == 6: self.registers[rd] = (val_rs1 | val_rs2) & 0xFFFFFFFF # OR
                elif funct3 == 7: self.registers[rd] = (val_rs1 & val_rs2) & 0xFFFFFFFF # AND
        
        # 🏆 新增：系統指令 (CSR, ECALL, EBREAK, MRET)
        elif opcode == 0b1110011:
            if funct3 == 0:  # ECALL, EBREAK, MRET
                if inst == 0x00000073:  # ECALL
                    self._handle_exception(11)  # 環境呼叫例外
                    return
                elif inst == 0x00100073:  # EBREAK
                    self._handle_exception(3)   # 斷點例外
                    return
                elif inst == 0x30200073:  # MRET
                    # 從例外返回
                    old_pc = self.pc
                    self.pc = self.csr['mepc']
                    
                    # 恢復 mstatus
                    old_mpie = (self.csr['mstatus'] >> 7) & 1
                    self.csr['mstatus'] &= ~0x80  # 清除 MPIE
                    if old_mpie:
                        self.csr['mstatus'] |= 0x8  # 設置 MIE = MPIE
                    
                    self.in_exception = False
                    
                    if self.debug:
                        print(f"[MRET] Return to PC={self.pc:#x} from {old_pc:#x}")
                    return
            
            # CSR 指令
            elif funct3 >= 1 and funct3 <= 7:
                # 讀取 CSR 值
                csr_value = 0
                if csr_addr == 0x300:  # mstatus
                    csr_value = self.csr['mstatus']
                elif csr_addr == 0x304:  # mie
                    csr_value = self.csr['mie']
                elif csr_addr == 0x305:  # mtvec
                    csr_value = self.csr['mtvec']
                elif csr_addr == 0x340:  # mscratch
                    csr_value = self.csr['mscratch']
                elif csr_addr == 0x341:  # mepc
                    csr_value = self.csr['mepc']
                elif csr_addr == 0x342:  # mcause
                    csr_value = self.csr['mcause']
                elif csr_addr == 0x343:  # mtval
                    csr_value = self.csr['mtval']
                elif csr_addr == 0x344:  # mip
                    csr_value = self.csr['mip']
                else:
                    # 未知 CSR
                    csr_value = 0
                
                # 寫入值
                write_value = 0
                if funct3 in [1, 5]:  # CSRRW, CSRRWI
                    write_value = val_rs1 if funct3 == 1 else rs1
                elif funct3 in [2, 6]:  # CSRRS, CSRRSI
                    write_value = csr_value | (val_rs1 if funct3 == 2 else rs1)
                elif funct3 in [3, 7]:  # CSRRC, CSRRCI
                    write_value = csr_value & ~(val_rs1 if funct3 == 3 else rs1)
                
                # 更新 CSR
                if csr_addr == 0x300:  # mstatus
                    self.csr['mstatus'] = write_value
                    # 更新中斷使能狀態
                    self.interrupt_enabled = (write_value & 0x8) != 0
                elif csr_addr == 0x304:  # mie
                    self.csr['mie'] = write_value
                elif csr_addr == 0x305:  # mtvec
                    self.csr['mtvec'] = write_value & ~0x3  # 對齊到 4 位元組
                elif csr_addr == 0x340:  # mscratch
                    self.csr['mscratch'] = write_value
                elif csr_addr == 0x341:  # mepc
                    self.csr['mepc'] = write_value & ~0x1  # 清除最低位
                elif csr_addr == 0x342:  # mcause
                    self.csr['mcause'] = write_value
                elif csr_addr == 0x343:  # mtval
                    self.csr['mtval'] = write_value
                elif csr_addr == 0x344:  # mip
                    self.csr['mip'] = write_value
                
                # 寫回結果到寄存器
                self.registers[rd] = csr_value
                
                if self.debug:
                    print(f"[CSR] {csr_addr:#x} = {write_value:#x}, rd=x{rd} <- {csr_value:#x}")
        
        else:
            # 非法指令例外
            if self.debug:
                print(f"Illegal instruction: {opcode:#b} at PC={self.pc:#x}")
            self._handle_exception(2, inst)  # 非法指令例外
            return

        # x0 永遠為 0
        self.registers[0] = 0
        self.pc = pc_next

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='RISC-V Instruction Level Simulator')
    parser.add_argument('--rom', default='firmware.hex', help='ROM file path')
    parser.add_argument('--max-cycles', type=int, default=500000, help='Maximum cycles')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    args = parser.parse_args()
    
    ROM_FILE = args.rom
    if os.path.exists(ROM_FILE):
        sim = RISCV_ILS(ROM_FILE)
        sim.debug = args.debug
        
        print(f"--- RISC-V ILS 模擬啟動 (Test 31 BIST Patch) ---")
        
        menu_fed = False
        test_32_fed = False
        
        try:
            while sim.cycle_count < args.max_cycles and not sim.halted:
                sim.mtime += 1
                
                # 1. 🍞 餵食 Main Menu (2萬週期)
                if not menu_fed and sim.cycle_count == 20000:
                    if sim.debug: print(f"\n[SIM_EVENT] Cycle {sim.cycle_count}: Injecting 'a' for Main Menu...")
                    sim.queue_input("a")
                    menu_fed = True

                # 2. 🍞 餵食 Test 32 (偵測 IE=2)
                if not test_32_fed and sim.uart_ie == 0x2 and sim.cycle_count > 50000:
                    if sim.debug: print(f"\n[SIM_EVENT] Cycle {sim.cycle_count}: Detected Test 32 Ready! Injecting 'a'...")
                    sim.queue_input("a")
                    test_32_fed = True
                
                # 3. 👂 檢查中斷 (確保 CPU 聽到)
                if sim._check_interrupts():
                    pass # 中斷發生，PC 已自動跳轉

                # 4. 執行指令
                if sim.pc in sim.rom:
                    inst = sim.rom[sim.pc]
                    sim._execute_instruction(inst)
                    sim.cycle_count += 1
                else:
                    break
                    
        except KeyboardInterrupt:
            print("\nUser Interrupted")
        
        sim.print_state()
        
    else:
        print(f"Firmware not found: {ROM_FILE}")
        sys.exit(1)