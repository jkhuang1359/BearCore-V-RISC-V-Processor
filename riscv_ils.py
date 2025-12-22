import sys
import os
import struct

# UART 輸出地址 (這是唯一特殊的地址)
UART_BASE_ADDRESS = 0x10000000

# 🏆 新增：定時器地址
TIMER_BASE_ADDRESS = 0x20000000
TIMER_MTIME_ADDR   = TIMER_BASE_ADDRESS
TIMER_MTIMECMP_ADDR = TIMER_BASE_ADDRESS + 0x8

class RISCV_ILS:
    def __init__(self, rom_path):
        self.registers = [0] * 32
        # 初始 SP 設個大概，反正 start.s 會覆蓋它
        self.registers[2] = 0x00008000  # 🏆 修正為 0x00008000
        
        # 🏆 核心升級：使用字典 (Dictionary) 作為 RAM
        # 這稱為「稀疏記憶體」，不管程式寫入 0x1000 還是 0x80000000，通通都能存！
        # 這樣就不用擔心 Linker 把變數亂放導致寫入失敗了。
        self.ram = {} 
        
        # 🏆 新增：CSR 寄存器
        self.csr = {
            'mstatus': 0x00000000,
            'misa': 0x40001100,  # RV32IM
            'mie': 0x00000000,
            'mtvec': 0x00000100,  # 例外向量表地址
            'mscratch': 0x00000000,
            'mepc': 0x00000000,
            'mcause': 0x00000000,
            'mtval': 0x00000000,
            'mip': 0x00000000,
        }
        
        # 🏆 新增：定時器
        self.mtime = 0
        self.mtimecmp = 0xFFFFFFFF
        
        # 🏆 新增：中斷狀態
        self.interrupt_enabled = False
        self.timer_int_pending = False
        self.external_int_pending = False
        self.software_int_pending = False
        
        self.pc = 0
        self.rom = self._load_rom(rom_path)
        self.uart_output = ""
        self.halted = False
        
        # 🏆 新增：例外處理狀態
        self.in_exception = False
        self.exception_handler = 0x100  # 預設例外處理地址
        
        # 🏆 新增：調試選項
        self.debug = False
        self.cycle_count = 0
        self.instruction_count = 0

    def _load_rom(self, path):
        rom_data = {}
        try:
            with open(path, 'r') as f:
                addr = 0
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    
                    # 檢查是否為地址標記（@開頭）
                    if line.startswith('@'):
                        try:
                            addr = int(line[1:], 16)
                        except ValueError:
                            print(f"[ROM] 警告: 第 {line_num} 行無效的地址標記: {line}")
                        continue
                    
                    # 處理指令行（8個十六進位字符）
                    try:
                        # 移除所有空格，確保是8個字符
                        line = line.replace(' ', '')
                        if len(line) != 8:
                            print(f"[ROM] 警告: 第 {line_num} 行長度不為8: {line}")
                            continue
                        
                        instruction = int(line, 16)
                        rom_data[addr] = instruction
                        
                        # 調試輸出前幾條指令
                        if addr < 0x20:
                            print(f"[ROM] 地址 {addr:#08x}: {instruction:08x}")
                        
                        addr += 4
                    except ValueError:
                        print(f"[ROM] 警告: 第 {line_num} 行無效的十六進位數字: {line}")
            
            print(f"[ROM] 從 {path} 加載了 {len(rom_data)} 條指令")
            
            # 如果沒有指令，打印警告
            if len(rom_data) == 0:
                print(f"[ROM] 錯誤: 沒有加載到任何指令!")
                print(f"[ROM] 文件內容範例 (前10行):")
                with open(path, 'r') as f:
                    for i, line in enumerate(f):
                        if i >= 10:
                            break
                        print(f"  {i}: {line.strip()}")
            
        except Exception as e:
            print(f"加載 ROM 錯誤: {e}")
            sys.exit(1)
        return rom_data

    def _read_mem(self, addr, size=4):
        # 🏆 首先檢查特殊地址
        if addr == UART_BASE_ADDRESS:  # UART 數據寄存器
            return 0  # 讀取 UART 數據寄存器返回 0
        elif addr == UART_BASE_ADDRESS + 4:  # UART 狀態寄存器
            return 0  # 總是返回不忙
        elif addr == TIMER_MTIME_ADDR:  # mtime 寄存器
            return self.mtime & 0xFFFFFFFF
        elif addr == TIMER_MTIMECMP_ADDR:  # mtimecmp 寄存器
            return self.mtimecmp
        
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
        
        data = temp_val

        # 符號擴展處理
        if size == 1:
            return struct.unpack('b', struct.pack('B', data & 0xFF))[0] & 0xFFFFFFFF
        elif size == 2:
            return struct.unpack('h', struct.pack('H', data & 0xFFFF))[0] & 0xFFFFFFFF
        return data & 0xFFFFFFFF

    def _write_mem(self, addr, data, size=4):
        # UART 特殊處理
        if addr == UART_BASE_ADDRESS or addr == UART_BASE_ADDRESS + 4:
            if addr == UART_BASE_ADDRESS:  # 數據寄存器
                char = chr(data & 0xFF)
                self.uart_output += char
                if self.debug:
                    print(f"UART TX: '{char}' (0x{data:02x})") 
            return
        
        # 🏆 定時器特殊處理
        elif addr == TIMER_MTIMECMP_ADDR:
            self.mtimecmp = data & 0xFFFFFFFF
            if self.debug:
                print(f"TIMER: Set mtimecmp = 0x{self.mtimecmp:08x}")
            return
            
        # 2. 寫入邏輯：直接寫入 RAM 字典
        # 這樣無論地址是 0x1000 (Global) 還是 0x10001000 (Stack)，都能寫入
        for i in range(size):
            self.ram[addr + i] = (data >> (i * 8)) & 0xFF
        
        if self.debug and addr >= 0x10000 and addr < 0x11000:
            print(f"[MEM_WRITE] Addr={addr:#x}, Data={data:#x}, Size={size}")
        
        # x0 永遠為 0
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
        if not self.interrupt_enabled:
            return False
        
        # 檢查定時器中斷
        if self.mtime >= self.mtimecmp:
            self.timer_int_pending = True
        
        # 如果有中斷待處理，處理最高優先級的中斷
        if self.timer_int_pending and (self.csr['mie'] & 0x80):
            return True
        elif self.software_int_pending and (self.csr['mie'] & 0x08):
            return True
        elif self.external_int_pending and (self.csr['mie'] & 0x800):
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
            elif funct3 == 3: self.registers[rd] = 1 if (val_rs1 & 0xFFFFFFFF) < (val_rs2 & 0xFFFFFFFF) else 0
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
    parser.add_argument('--max-cycles', type=int, default=150000, help='Maximum cycles to simulate')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    args = parser.parse_args()
    
    ROM_FILE = args.rom
    if os.path.exists(ROM_FILE):
        sim = RISCV_ILS(ROM_FILE)
        sim.debug = args.debug
        sim.run(args.max_cycles)
    else:
        print(f"Firmware not found: {ROM_FILE}")
        print("Run 'make' first to generate firmware.hex")
        sys.exit(1)