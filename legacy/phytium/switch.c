/**
 * ============================================================================
 * 文件: switch.c
 * 描述: 开关检测模块——GPIO446输入+软件消抖
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现GPIO446输入与软件消抖
 * ============================================================================
 */

#include "switch.h"
#include "gpio.h"

/**
 * ============================================================================
 * 开关检测模块 —— 带硬件消抖 + 软件消抖双重保护
 * ============================================================================
 *
 * 消抖策略:
 *   1. 硬件层面: 建议在开关引脚并联 0.1uF 电容到地
 *   2. 软件层面: 连续3次读取，间隔10ms，全部一致才确认状态
 *   3. 状态切换: 等待开关状态变化后，额外等待 SWITCH_DEBOUNCE_MS 确认稳定
 *
 * 逻辑电平解析 (根据 SWITCH_ACTIVE_LOW):
 *   若 SWITCH_ACTIVE_LOW=1: 物理低电平 → 逻辑ON，物理高电平 → 逻辑OFF
 *   若 SWITCH_ACTIVE_LOW=0: 物理高电平 → 逻辑ON，物理低电平 → 逻辑OFF
 * ============================================================================
 */

/* ===================== 内部静态函数 ===================== */

/**
 * @brief 将物理电平转换为逻辑开关状态
 */
static inline int physical_to_logic(int physical_level)
{
    if (physical_level < 0) return -1;
#if SWITCH_ACTIVE_LOW
    return physical_level == 0 ? 1 : 0;  // 低电平有效: 低=ON, 高=OFF
#else
    return physical_level == 1 ? 1 : 0;  // 高电平有效: 高=ON, 低=OFF
#endif
}

/* ===================== 对外接口 ===================== */

int switch_init(void)
{
    gpio_export(SWITCH_GPIO);
    gpio_set_dir(SWITCH_GPIO, GPIO_IN);
    usleep(100000);  // 100ms 等待GPIO导出完成

    int state = switch_read_stable();
    printf("[开关] 初始化完成，GPIO=%d，当前状态=%s\n",
           SWITCH_GPIO, state == 1 ? "ON" : (state == 0 ? "OFF" : "未知"));
    return 0;
}

int switch_read_raw(void)
{
    return gpio_read_value(SWITCH_GPIO);
}

int switch_read_stable(void)
{
    int val[3];
    int i;

    // 连续读取3次，间隔10ms
    for (i = 0; i < 3; i++) {
        val[i] = gpio_read_value(SWITCH_GPIO);
        if (val[i] < 0) return -1;
        usleep(10000);  // 10ms
    }

    // 3次必须全部一致
    if (val[0] == val[1] && val[1] == val[2]) {
        return physical_to_logic(val[0]);
    }

    // 不一致，说明正在抖动，返回当前物理值对应的逻辑值（取最后一次）
    return physical_to_logic(val[2]);
}

int switch_wait_on(volatile int *exit_flag)
{
    printf("[开关] 等待ON...\n");

    while (1) {
        if (exit_flag && *exit_flag) return -1;

        int state = switch_read_stable();
        if (state == 1) {
            // 消抖确认：额外等待 SWITCH_DEBOUNCE_MS
            usleep(SWITCH_DEBOUNCE_MS * 1000);
            if (switch_read_stable() == 1) {
                printf("[开关] ✅ 确认ON\n");
                return 1;
            }
        }
        usleep(SWITCH_POLL_MS * 1000);
    }
}

int switch_wait_off(volatile int *exit_flag)
{
    printf("[开关] 等待OFF...\n");

    while (1) {
        if (exit_flag && *exit_flag) return -1;

        int state = switch_read_stable();
        if (state == 0) {
            // 消抖确认
            usleep(SWITCH_DEBOUNCE_MS * 1000);
            if (switch_read_stable() == 0) {
                printf("[开关] ✅ 确认OFF\n");
                return 0;
            }
        }
        usleep(SWITCH_POLL_MS * 1000);
    }
}

void switch_deinit(void)
{
    gpio_unexport(SWITCH_GPIO);
    printf("[开关] GPIO已释放\n");
}
