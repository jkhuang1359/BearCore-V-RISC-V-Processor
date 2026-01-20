#ifndef _SYSTEM_H
#define _SYSTEM_H

#include <stdint.h>

// UART 寄存器定義
#define UART_BASE 0x10000000
#define UART_DATA   (*((volatile uint32_t*)(UART_BASE + 0x00)))
#define UART_STATUS (*((volatile uint32_t*)(UART_BASE + 0x04)))
#define UART_IE     (*((volatile uint32_t*)(UART_BASE + 0x18)))

// 狀態寄存器位定義
#define UART_TX_BUSY   (1 << 0)
#define UART_RX_READY  (1 << 1)

#define UART_TX_IE  (1 << 0)
#define UART_RX_IE  (1 << 1)

// Timer 寄存器定義
#define TIMER_BASE 0x10000008
#define MTIME_L    (*((volatile uint32_t*)(TIMER_BASE + 0x00)))
#define MTIME_H    (*((volatile uint32_t*)(TIMER_BASE + 0x04)))
#define MTIMECMP_L (*((volatile uint32_t*)(TIMER_BASE + 0x08)))
#define MTIMECMP_H (*((volatile uint32_t*)(TIMER_BASE + 0x0C)))

// 類型定義（如果其他頭文件沒有定義）
#ifndef _UINT32_T
#define _UINT32_T
typedef unsigned int uint32_t;
#endif

#ifndef _INT32_T
#define _INT32_T
typedef int int32_t;
#endif

#ifndef _UINT8_T
#define _UINT8_T
typedef unsigned char uint8_t;
#endif

#ifndef _INT8_T
#define _INT8_T
typedef signed char int8_t;
#endif

#ifndef _UINT16_T
#define _UINT16_T
typedef unsigned short uint16_t;
#endif

#ifndef _INT16_T
#define _INT16_T
typedef short int16_t;
#endif

#endif /* _SYSTEM_H */