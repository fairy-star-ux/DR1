/**
 * ============================================================================
 * 文件: motor.h
 * 描述: 电机控制模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明电机控制接口
 * ============================================================================
 */

#ifndef MOTOR_H
#define MOTOR_H
#include "boat_common.h"
//串口初始化
int uart_init(void);
//发送串口指令
int uart_send_cmd(const char *cmd);
// 电机初始化
int motor_init(void);
//设置4个pwm值
void motor_smooth_set_pwm(int16_t target_m1, int16_t target_m2, int16_t target_m3, int16_t target_m4);
// 小船前进
void motor_forward(uint16_t speed);
// 小船停止
void motor_stop(void);
//小船后退
void motor_backward(uint16_t speed);
// 小船左转（左慢右快）
void motor_left(uint16_t speed);
// 小船右转（左快右慢）
void motor_right(uint16_t speed);
// 电机资源释放
void uart_close(void);
#endif // MOTOR_H