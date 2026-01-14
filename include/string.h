#ifndef _STRING_H
#define _STRING_H

#include <stddef.h>  // 這會包含我們修改過的 stddef.h

// 如果已經有內建函數定義，則跳過自定義聲明
#ifndef __HAVE_BUILTIN_MEMSET
void* memset(void* s, int c, size_t n);
#define __HAVE_BUILTIN_MEMSET 1
#endif

#ifndef __HAVE_BUILTIN_MEMCPY
void* memcpy(void* dest, const void* src, size_t n);
#define __HAVE_BUILTIN_MEMCPY 1
#endif

#ifndef __HAVE_BUILTIN_MEMCMP
int memcmp(const void* s1, const void* s2, size_t n);
#define __HAVE_BUILTIN_MEMCMP 1
#endif

#ifndef __HAVE_BUILTIN_STRLEN
size_t strlen(const char* s);
#define __HAVE_BUILTIN_STRLEN 1
#endif

#ifndef __HAVE_BUILTIN_STRCPY
char* strcpy(char* dest, const char* src);
#define __HAVE_BUILTIN_STRCPY 1
#endif

#ifndef __HAVE_BUILTIN_STRCAT
char* strcat(char* dest, const char* src);
#define __HAVE_BUILTIN_STRCAT 1
#endif

#ifndef __HAVE_BUILTIN_STRCMP
int strcmp(const char* s1, const char* s2);
#define __HAVE_BUILTIN_STRCMP 1
#endif

#ifndef __HAVE_BUILTIN_STRCHR
char* strchr(const char* s, int c);
#define __HAVE_BUILTIN_STRCHR 1
#endif

#endif // _STRING_H