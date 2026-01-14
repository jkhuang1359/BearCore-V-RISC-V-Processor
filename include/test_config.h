// test_config.h
#ifndef TEST_CONFIG_H
#define TEST_CONFIG_H

// ============================================================================
// 測試配置總控
// ============================================================================

// 測試級別（根據需要選擇一個）
//#define TEST_LEVEL_MINIMAL      // 最小測試集（僅核心功能）
//#define TEST_LEVEL_STANDARD     // 標準測試集（推薦）
//#define TEST_LEVEL_COMPREHENSIVE  // 全面測試集（所有測試）

// ============================================================================
// 各個測試類別的獨立開關（會覆蓋測試級別的設置）
// ============================================================================

// 基本指令測試
#ifndef ENABLE_BASIC_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_BASIC_TESTS         1
#else
#define ENABLE_BASIC_TESTS         1  // 預設啟用
#endif
#endif

// 控制流測試
#ifndef ENABLE_CONTROL_FLOW_TESTS
#define ENABLE_CONTROL_FLOW_TESTS  1
#endif

// 演算法測試
#ifndef ENABLE_ALGORITHM_TESTS
#define ENABLE_ALGORITHM_TESTS     1
#endif

// 數據結構測試
#ifndef ENABLE_DATASTRUCTURE_TESTS
#define ENABLE_DATASTRUCTURE_TESTS 1
#endif

// 系統功能測試
#ifndef ENABLE_SYSTEM_TESTS
#define ENABLE_SYSTEM_TESTS        1
#endif

// 進階功能測試
#ifndef ENABLE_ADVANCED_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_ADVANCED_TESTS      0
#else
#define ENABLE_ADVANCED_TESTS      1
#endif
#endif

// 性能與壓力測試
#ifndef ENABLE_PERFORMANCE_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_PERFORMANCE_TESTS   0
#else
#define ENABLE_PERFORMANCE_TESTS   1
#endif
#endif

// 隨機數與統計測試
#ifndef ENABLE_STATISTICS_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_STATISTICS_TESTS    0
#else
#define ENABLE_STATISTICS_TESTS    1
#endif
#endif

// 系統特性測試
#ifndef ENABLE_SYSTEM_FEATURE_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_SYSTEM_FEATURE_TESTS 0
#else
#define ENABLE_SYSTEM_FEATURE_TESTS 1
#endif
#endif

// 應用層測試
#ifndef ENABLE_APPLICATION_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_APPLICATION_TESTS   0
#else
#define ENABLE_APPLICATION_TESTS   1
#endif
#endif

// 安全相關測試
#ifndef ENABLE_SECURITY_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_SECURITY_TESTS      0
#else
#define ENABLE_SECURITY_TESTS      1
#endif
#endif

// 文件系統概念測試
#ifndef ENABLE_FILESYSTEM_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_FILESYSTEM_TESTS    0
#elif defined(TEST_LEVEL_STANDARD)
#define ENABLE_FILESYSTEM_TESTS    1
#else
#define ENABLE_FILESYSTEM_TESTS    1
#endif
#endif

// 網絡協議測試
#ifndef ENABLE_NETWORK_TESTS
#ifdef TEST_LEVEL_MINIMAL
#define ENABLE_NETWORK_TESTS       0
#elif defined(TEST_LEVEL_STANDARD)
#define ENABLE_NETWORK_TESTS       0  // 標準版可選
#else
#define ENABLE_NETWORK_TESTS       1
#endif
#endif

// UART功能測試
#ifndef ENABLE_UART_TESTS
#define ENABLE_UART_TESTS          1
#endif

// ============================================================================
// 特定測試的細粒度控制（可覆蓋類別設置）
// ============================================================================

// 文件系統測試中的有問題測試
#ifndef ENABLE_FILEPATH_PARSING_TEST
#define ENABLE_FILEPATH_PARSING_TEST   0  // 已知問題
#endif

#ifndef ENABLE_FILE_OPERATIONS_TEST
#define ENABLE_FILE_OPERATIONS_TEST    0  // 已知問題
#endif

// 是否運行有問題的測試（用於調試）
#ifndef RUN_KNOWN_ISSUE_TESTS
#define RUN_KNOWN_ISSUE_TESTS          0
#endif

// ============================================================================
// 測試詳細程度控制
// ============================================================================

// 測試輸出詳細程度
#ifndef TEST_VERBOSITY
#define TEST_VERBOSITY 2  // 0=無輸出, 1=簡要, 2=詳細, 3=非常詳細
#endif

// 是否顯示測試統計
#ifndef SHOW_TEST_STATS
#define SHOW_TEST_STATS 1
#endif

// 是否在測試開始時顯示配置信息
#ifndef SHOW_CONFIG_INFO
#define SHOW_CONFIG_INFO 1
#endif

#endif // TEST_CONFIG_H