/**
 * ============================================================================
 * 文件: radar.h
 * 描述: 超声波雷达模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明超声波雷达接口
 * ============================================================================
 */

#ifndef ULTRASONIC_H
#define ULTRASONIC_H
#include "boat_common.h"
// 超声波初始化
int ultrasonic_init(void);
// 获取当前测距值（单位：cm）
int ultrasonic_get_distance(void);
// 获取测距时的舵机角度
int ultrasonic_get_angle(void);
// 启动实时测距线程
void ultrasonic_start(void);
// 停止实时测距线程
void ultrasonic_stop(void);
// 超声波资源释放
void ultrasonic_deinit(void);
#endif // ULTRASONIC_H