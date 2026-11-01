/**
 * ============================================================================
 * 文件: servo.h
 * 描述: 雷达舵机模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明雷达舵机接口
 * ============================================================================
 */

#ifndef SERVO_H
#define SERVO_H
#include "boat_common.h"
// 舵机初始化
int servo_init(void);
// 设置舵机角度（范围：-90 ~ +90度）
void servo_set_angle(int angle);
// 获取当前舵机角度
int servo_get_angle(void);
// 启动循环扫描线程
void servo_start_scan(void);
// 停止循环扫描
void servo_stop_scan(void);
// 舵机资源释放
void servo_deinit(void);
#endif // SERVO_H