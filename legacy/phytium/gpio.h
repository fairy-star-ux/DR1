/**
 * ============================================================================
 * 文件: gpio.h
 * 描述: GPIO底层操作头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明GPIO底层操作接口
 * ============================================================================
 */

#ifndef GPIO_H
#define GPIO_H
#include "boat_common.h"
#define GPIO_OUT    "out"
#define GPIO_IN     "in"
// GPIO导出
void gpio_export(int pin);
// GPIO取消导出
void gpio_unexport(int pin);
// 设置GPIO方向
void gpio_set_dir(int pin, const char *direction);
// 设置GPIO输出电平
void gpio_set_value(int pin, int value);
// 读取GPIO输入电平
int gpio_read_value(int pin);
void gpio_set_value_fast(int pin, int value);

#endif // GPIO_H