/**
 * ============================================================================
 * 文件: visual_servo.c
 * 描述: 视觉舵机模块——GPIO445定点转动（C程序独占）
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现GPIO445定点转动
 * ============================================================================
 */

#include "visual_servo.h"
#include "gpio.h"

/**
 * ============================================================================
 * 视觉舵机控制模块 —— 由C程序独占，vision.py不再越权操作
 * ============================================================================
 *
 * 设计原则:
 *   1. C程序统一控制所有硬件，vision.py只做纯视觉计算
 *   2. 视觉舵机 GPIO 445 完全由本模块控制，不与雷达舵机510冲突
 *   3. 定点转动模式（非扫描），到位后停止PWM输出防止抖动
 *   4. 不使用独立线程，由电机线程在需要时直接调用
 *
 * 角度映射:
 *   逻辑角度(-90~+90) → 物理角度(0~180)
 *   物理角度 = 90 + 逻辑角度
 *   0°(逻辑) = 90°(物理) = 正前方
 * ============================================================================
 */

#define VISUAL_SERVO_GPIO       445     // 视觉舵机GPIO（物理引脚37）
#define SERVO_WAIT_TIME_MS      1200    // 舵机到位等待时间(ms)
#define PWM_PULSE_COUNT         30      // PWM脉冲数，确保极限位置有动力

/* 当前逻辑角度 */
static int current_angle = 0;

/* ===================== 内部PWM输出 ===================== */

static void visual_servo_pwm_output(int physical_angle)
{
    // 物理角度限位 0~180
    int safe_angle = physical_angle;
    if (safe_angle < 0)   safe_angle = 0;
    if (safe_angle > 180) safe_angle = 180;

    // 占空比计算: 0.5ms=0°  2.5ms=180°
    double high_ms = 0.5 + (safe_angle / 180.0) * 2.0;
    double low_ms  = 20.0 - high_ms;

    int high_us = (int)(high_ms * 1000.0);
    int low_us  = (int)(low_ms  * 1000.0);

    printf("[视觉舵机] PWM输出: 物理角度=%d° 高电平=%dus\n", safe_angle, high_us);

    // 输出PWM脉冲（使用fast版本，无防抖延迟）
    for (int i = 0; i < PWM_PULSE_COUNT; i++) {
        gpio_set_value_fast(VISUAL_SERVO_GPIO, 1);
        usleep(high_us);
        gpio_set_value_fast(VISUAL_SERVO_GPIO, 0);
        usleep(low_us);
    }

    // 停止PWM输出，防止静止时抖动
    gpio_set_value_fast(VISUAL_SERVO_GPIO, 0);

    // 额外等待舵机机械到位
    usleep(SERVO_WAIT_TIME_MS * 1000);
}

/* ===================== 对外接口 ===================== */

int visual_servo_init(void)
{
    gpio_export(VISUAL_SERVO_GPIO);
    gpio_set_dir(VISUAL_SERVO_GPIO, GPIO_OUT);
    gpio_set_value(VISUAL_SERVO_GPIO, 0);  // 初始低电平
    usleep(100000);  // 等待GPIO导出完成

    current_angle = 0;
    printf("[视觉舵机] 初始化完成 GPIO=%d，当前角度=0°(正前方)\n", VISUAL_SERVO_GPIO);
    return 0;
}

void visual_servo_set_angle(int angle)
{
    // 逻辑角度限位 -90~+90
    if (angle < -90) angle = -90;
    if (angle > 90)  angle = 90;

    // 映射到物理角度 0~180
    int physical_angle = 90 + angle;

    printf("[视觉舵机] 转动: 逻辑角度 %d° → 物理角度 %d°\n", angle, physical_angle);

    visual_servo_pwm_output(physical_angle);
    current_angle = angle;

    printf("[视觉舵机] 已到位，当前逻辑角度=%d°\n", current_angle);
}

void visual_servo_reset(void)
{
    printf("[视觉舵机] 回正到0°(正前方)\n");
    visual_servo_set_angle(0);
}

void visual_servo_deinit(void)
{
    // 先停止输出，再取消导出
    gpio_set_value_fast(VISUAL_SERVO_GPIO, 0);
    usleep(50000);
    gpio_unexport(VISUAL_SERVO_GPIO);
    current_angle = 0;
    printf("[视觉舵机] 资源已释放\n");
}

int visual_servo_get_angle(void)
{
    return current_angle;
}
