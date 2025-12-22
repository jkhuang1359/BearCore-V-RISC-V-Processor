import sys
import os

# UART 輸出地址 (這是唯一特殊的地址)
UART_BASE_ADDRESS = 0x10000000

class RISCV_ILS:
    def __init__(self, rom_path):
        self.registers = [0] * 32
        # 初始 SP 設個大概，反正 start.s 會覆蓋它
        self.registers[2] = 0x10000000 
        
        # 🏆 核心升級：使用字典 (Dictionary) 作為 RAM
        # 這稱為「稀疏記憶體」，不管程式寫入 0x1000 還是 0x80000000，通通都能存！
        # 這樣就不用擔心 Linker 把變數亂放導致寫入失敗了。
        self.ram = {} 
        
        self.pc = 0
        self.rom = self._load_rom(rom_path)
        self.uart_output = ""
        self.halted = False

    def _load_rom(self, path):
        rom_data = {}
        current_addr = 0
        try:
            with open(path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line: continue
                    if line.startswith('@'):
                        try:
                            current_addr = int(line[1:], 16)
                            continue
                        except: continue
                    parts = line.split()
                    i = 0
                    while i + 3 < len(parts):
                        try:
                            b0 = int(parts[i], 16)
                            b1 = int(parts[i+1], 16)
                            b2 = int(parts[i+2], 16)
                            b3 = int(parts[i+3], 16)
                            instruction = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
                            rom_data[current_addr] = instruction
                            current_addr += 4
                            i += 4
                        except: pass
        except Exception as e:
            print(f"Error loading ROM: {e}")
            sys.exit(1)
        return rom_data

    def _read_mem(self, addr, size=4):
        # 1. 讀取邏輯：優先檢查 RAM (是否有被修改過？)
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
        
        data = temp_val

        # 符號擴展處理
        if size == 1 and (data & 0x80): return data | 0xFFFFFF00
        if size == 2 and (data & 0x8000): return data | 0xFFFF0000
        return data

    def _write_mem(self, addr, data, size=4):
        # UART 特殊處理
        if addr == UART_BASE_ADDRESS and size == 1:
            char = chr(data & 0xFF)
            self.uart_output += char
            print(f"UART TX: '{char}'") 
            return
            
        # 2. 寫入邏輯：直接寫入 RAM 字典
        # 這樣無論地址是 0x1000 (Global) 還是 0x10001000 (Stack)，都能寫入
        for i in range(size):
            self.ram[addr + i] = (data >> (i * 8)) & 0xFF
            
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
        print(f"\nUART 最終輸出: \"{self.uart_output}\"")

    def run(self, max_cycles=150000):
        print(f"--- RISC-V ILS 模擬啟動 (載入 {len(self.rom)} 條指令) ---")
        cycle = 0
        # 確保從 ROM 最小地址開始執行
        if self.pc not in self.rom and self.pc == 0 and self.rom:
            self.pc = min(self.rom.keys())

        while cycle < max_cycles and not self.halted:
            # 讀取指令：直接呼叫 _read_mem，確保一致性
            inst = self._read_mem(self.pc, 4)
            # 如果讀全是 0，且不在 ROM 中，可能跑飛了
            if inst == 0 and self.pc not in self.rom:
                 # 寬容處理：如果是 0，視為 nop (addi x0, x0, 0)
                 pass
            
            self._execute_instruction(inst)
            cycle += 1
            
        print(f"\n--- 模擬結束: {cycle} Cycles ---")
        self.print_state()

    def _execute_instruction(self, inst):
    # 在 load/store 指令處添加詳細日誌
        if opcode == 0b0000011:  # Load
            print(f"[LOAD] PC={self.pc:#x}, Addr={addr:#x}, Value={data:#x}")
        elif opcode == 0b0100011:  # Store
            print(f"[STORE] PC={self.pc:#x}, Addr={addr:#x}, Value={val_rs2:#x}")
        
        # 如果訪問特定地址範圍
        if addr >= 0x10000 and addr < 0x11000:
            print(f"[MEM_DEBUG] Access to test area: {addr:#x}")      
              
        opcode = inst & 0x7F
        rd = (inst >> 7) & 0x1F
        funct3 = (inst >> 12) & 0x7
        rs1 = (inst >> 15) & 0x1F
        rs2 = (inst >> 20) & 0x1F
        
        pc_next = self.pc + 4
        
        val_rs1 = self.registers[rs1]
        val_rs2 = self.registers[rs2]

        # LUI
        if opcode == 0b0110111: self.registers[rd] = ((inst >> 12) << 12) & 0xFFFFFFFF
        # AUIPC
        elif opcode == 0b0010111: self.registers[rd] = (self.pc + ((inst >> 12) << 12)) & 0xFFFFFFFF
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
            elif funct3 == 6: take = ((val_rs1&0xFFFFFFFF) < (val_rs2&0xFFFFFFFF))
            elif funct3 == 7: take = ((val_rs1&0xFFFFFFFF) >= (val_rs2&0xFFFFFFFF))
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
            elif funct3 == 3: self.registers[rd] = 1 if (val_rs1&0xFFFFFFFF) < (imm&0xFFFFFFFF) else 0
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
            if funct7 == 0x01: 
                if funct3 == 0:   # MUL
                    self.registers[rd] = (val_rs1 * val_rs2) & 0xFFFFFFFF
                elif funct3 == 4: # DIV
                    if val_rs2 == 0: self.registers[rd] = 0xFFFFFFFF
                    else: self.registers[rd] = int(val_rs1 / val_rs2) & 0xFFFFFFFF
                elif funct3 == 6: # REM
                    if val_rs2 == 0: self.registers[rd] = val_rs1
                    else: self.registers[rd] = (val_rs1 % val_rs2) & 0xFFFFFFFF            
            # 🏆 原本的標準 R-type 邏輯 (funct7 == 0x00 或 0x20)    
            elif funct3 == 0: 
                if funct7 == 0: self.registers[rd] = (val_rs1 + val_rs2) & 0xFFFFFFFF
                else: self.registers[rd] = (val_rs1 - val_rs2) & 0xFFFFFFFF
            elif funct3 == 1: self.registers[rd] = (val_rs1 << (val_rs2 & 0x1F)) & 0xFFFFFFFF
            elif funct3 == 2: self.registers[rd] = 1 if val_rs1 < val_rs2 else 0
            elif funct3 == 3: self.registers[rd] = 1 if (val_rs1&0xFFFFFFFF) < (val_rs2&0xFFFFFFFF) else 0
            elif funct3 == 4: self.registers[rd] = (val_rs1 ^ val_rs2) & 0xFFFFFFFF
            elif funct3 == 5:
                if funct7 == 0x20: # SRA
                    sign = val_rs1 & 0x80000000
                    res = val_rs1 >> (val_rs2 & 0x1F)
                    if sign: res |= (0xFFFFFFFF << (32 - (val_rs2 & 0x1F)))
                    self.registers[rd] = res & 0xFFFFFFFF
                else: self.registers[rd] = (val_rs1 >> (val_rs2 & 0x1F)) & 0xFFFFFFFF
            elif funct3 == 6: self.registers[rd] = (val_rs1 | val_rs2) & 0xFFFFFFFF
            elif funct3 == 7: self.registers[rd] = (val_rs1 & val_rs2) & 0xFFFFFFFF
        elif opcode == 0b1110011:
            print("System Call/Break reached. Halting.")
            self.halted = True
            return
        else:
            print(f"Unknown Opcode: {opcode:#b} at PC={self.pc:#x}")
            self.halted = True
            return

        self.registers[0] = 0
        self.pc = pc_next

if __name__ == "__main__":
    ROM_FILE = os.path.join(os.path.dirname(__file__), 'firmware.hex')
    if os.path.exists(ROM_FILE):
        sim = RISCV_ILS(ROM_FILE)
        sim.run()
    else:
        print("Firmware not found. Run 'make' first.")