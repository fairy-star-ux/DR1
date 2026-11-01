/**
 * ============================================================================
 * 文件: visual_servo.h
 * 描述: 视觉舵机模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明视觉舵机接口
 * ============================================================================
 */

#ifndef VISUAL_SERVO_H
#define VISUAL_SERVO_H

#include "boat_common.h"

/**
 * @brief 视觉舵机初始化
 *        导出GPIO，设为输出方向，初始化为低电平
 * @return 0成功，-1失败
 */
int visual_servo_init(void);

/**
 * @brief 设置视觉舵机角度（定点转动）
 *        输出30个PWM脉冲确保到位，然后停止PWM防止抖动
 * @param angle 目标角度（相对正前方，范围-90~+90）
 *                0=正前方，-90=最左，+90=最右
 *                内部映射到物理角度：物理角度 = 90 + angle
 */
void visual_servo_set_angle(int angle);

/**
 * @brief 视觉舵机回正（转到正前方0度）
 */
void visual_servo_reset(void);

/**
 * @brief 视觉舵机资源释放
 *        取消GPIO导出
 */
void visual_servo_deinit(void);

/**
 * @brief 获取视觉舵机当前逻辑角度
 * @return 当前相对角度（-90~+90）
 */
int visual_servo_get_angle(void);

#endif // VISUAL_SERVO_H
