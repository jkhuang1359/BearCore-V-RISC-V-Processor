#ifndef _STDDEF_H
#define _STDDEF_H

#include <stdint.h>  // 添加這行，確保有 uint32_t 和 int32_t 的定義

#ifndef _SIZE_T
#define _SIZE_T
typedef unsigned int size_t;  // 或使用 uint32_t
#endif

#ifndef _PTRDIFF_T
#define _PTRDIFF_T
typedef int ptrdiff_t;  // 或使用 int32_t
#endif

#ifndef _WCHAR_T
#define _WCHAR_T
typedef unsigned int wchar_t;  // 或使用 uint32_t
#endif

// 添加 NULL 定義
#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void*)0)
#endif
#endif

// 如果沒有 stdint.h，則自定義基本類型
#ifndef __STDINT_H
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
#endif // __STDINT_H

#endif // _STDDEF_H