/* link.ld - 還原版 */
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K  /* RAM */
}

SECTIONS
{
    ENTRY(_start)

    /* 🏆 1. 重置向量：放在 ROM 的最開頭 (0x0) */
    .text.init 0x00000000 : {
        KEEP(*(.text.init))
    } > ROM

    /* 🏆 2. 例外向量：放在 ROM 的 0x100 */
    .text.vec 0x00000100 : {
        . = ALIGN(4);
        KEEP(*(.text.vec))
    } > ROM
    
    /* 🏆 3. 主程式與字串：放在 ROM 區塊 */
    /* 我們不再手動強制定址 0x200，讓它自動排在例外向量後面 */
    .text : {
        . = ALIGN(4);
        *(.text .text.*)  
    } > ROM

    .rodata : {
        . = ALIGN(256); 
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > ROM    

    /* 🏆 4. 資料段：搬家到 RAM 區塊 (0x10000 開始) */
    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > RAM AT > ROM  /* 加載位址(LMA)在 ROM，運行位址(VMA)在 RAM */

    .bss : {
        . = ALIGN(4);
        *(.bss .bss.*)
        *(COMMON)
    } > RAM

    /* 🏆 堆疊頂端：指向妳那顆 64KB RAM 的最高處 */
    /* 0x4000 + 64K = 0x14000，我們留一點安全邊界設在 0xF000 */
    _stack_top = 0x0001F000;
}