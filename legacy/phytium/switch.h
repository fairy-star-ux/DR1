/**
 * ============================================================================
 * 文件: switch.h
 * 描述: 开关检测模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明开关检测接口
 * ============================================================================
 */

#ifndef SWITCH_H
#define SWITCH_H

#include "boat_common.h"

/**
 * @brief 开关GPIO初始化
 *        导出GPIO，设置为输入方向
 * @return 0成功，-1失败
 */
int switch_init(void);

/**
 * @brief 读取当前开关原始电平（无消抖）
 * @return 1=高电平，0=低电平，-1=错误
 */
int switch_read_raw(void);

/**
 * @brief 读取开关状态（带消抖确认）
 *        连续3次读取间隔10ms一致才返回确认状态
 * @return 1=开关ON（根据SWITCH_ACTIVE_LOW解析后的逻辑状态）
 *         0=开关OFF
 *        -1=读取错误
 */
int switch_read_stable(void);

/**
 * @brief 等待开关变为ON状态（带消抖，阻塞）
 *        内部200ms轮询，消抖确认后返回
 * @param exit_flag 外部退出标志指针，非0时立即返回-1
 * @return 1=确认ON，-1=被exit_flag中断
 */
int switch_wait_on(volatile int *exit_flag);

/**
 * @brief 等待开关变为OFF状态（带消抖，阻塞）
 *        内部200ms轮询，消抖确认后返回
 * @param exit_flag 外部退出标志指针，非0时立即返回-1
 * @return 0=确认OFF，-1=被exit_flag中断
 */
int switch_wait_off(volatile int *exit_flag);

/**
 * @brief 开关资源释放
 *        取消GPIO导出
 */
void switch_deinit(void);

#endif // SWITCH_H
