/* 🏆 必須先宣告記憶體區域 */
MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    /* 🏆 強制程式進入點為 _start */
    ENTRY(_start)

    . = 0x00000000;  /* 🏆 明確指定起始位址 */
    .text : {
        KEEP(*(.text.init)) /* 🏆 確保 _start 放在最前面  */
        *(.text .text.*)
    } > RAM

    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > RAM

    .bss : {
        . = ALIGN(4);
        *(.bss .bss.*)
        *(COMMON)
    } > RAM

    /* 🏆 設定堆疊頂端 */
    _stack_top = 0x00008000;
}