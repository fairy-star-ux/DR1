/**
 * ============================================================================
 * 文件: boat_common.h
 * 描述: 公共头文件——全局配置宏、标准头文件包含
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，定义全局配置宏与标准头文件包含
 * ============================================================================
 */

#ifndef COMMON_H
#define COMMON_H

// 全局标准头文件
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <pthread.h>
#include <termios.h>
#include <sys/time.h>
#include <signal.h>
#include <errno.h>
#include <sys/stat.h>
#include <math.h>
#include <stdbool.h>
#include <sys/wait.h>       // waitpid()
#include <sys/types.h>      // pid_t

/************************* 电机配置 *************************/
#define UART_DEV                "/dev/ttyUSB0"
#define UART_BAUDRATE           B115200
#define DIFF_RATIO              0.6f
#define SMOOTH_STEP             100
#define SMOOTH_DELAY_US         20000

/************************* 超声波雷达配置 *************************/
#define TRIG_GPIO               450
#define ECHO_GPIO               485
#define OBSTACLE_THRESHOLD      50
#define ULTRASONIC_INTERVAL     60000

/************************* 雷达舵机配置 *************************/
#define SERVO_GPIO              510
#define SERVO_MIN_ANGLE         -90
#define SERVO_MAX_ANGLE         90
#define SERVO_INIT_ANGLE        0
#define SERVO_STEP              2
#define SERVO_DELAY_MS          10

/************************* 电源/运行开关配置 *************************/
#define SWITCH_GPIO             446     // 开关GPIO引脚（根据实际接线修改）
#define SWITCH_ACTIVE_LOW       1       // 1=低电平有效(拨下接地导通), 0=高电平有效
#define SWITCH_DEBOUNCE_MS      300     // 开关消抖时间(ms)
#define SWITCH_POLL_MS          200     // 开关状态轮询周期(ms)

/************************* 视觉模块配置 *************************/
#define ANGLE_FILE              "angle.txt"
#define RESULT_FILE             "result.txt"
#define CAPTURE_B64_FILE        "capture_base64.txt"
#define VISION_TIMEOUT_MS       30000   // 30秒：ARM上YOLO推理可能较慢
#define VISION_PYTHON_CMD       "python3"
#define VISION_SCRIPT_NAME      "vision.py"

/************************* 线程优先级配置 (SCHED_FIFO, 1-99) *************************/
// 数值越大优先级越高 —— 安全关键模块优先，确保时序不被抢占
#define PRIO_MOTOR_CTRL         90   // 电机控制: 安全关键, 必须实时响应避障
#define PRIO_RADAR              80   // 超声波测距: 高频, 为电机提供障碍物数据
#define PRIO_SERVO              75   // 舵机扫描: 中频PWM输出
#define PRIO_VISION_COORD       65   // 视觉协调: 处理识别结果, 协调上报
#define PRIO_GPS                50   // GPS定位: 低频位置更新
#define PRIO_EC20               40   // 4G上传: 网络传输, 可容忍延迟

/************************* GPIO方向宏定义 *************************/
#define GPIO_OUT    "out"
#define GPIO_IN     "in"

#endif // COMMON_H
