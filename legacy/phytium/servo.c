/**
 * ============================================================================
 * 文件: servo.c
 * 描述: 雷达舵机模块——GPIO510循环扫描
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现GPIO510循环扫描
 * ============================================================================
 */

#include "servo.h"
#include "gpio.h"
static pthread_t scan_thread;
static volatile int scan_running = 0;
static volatile int scan_stop_flag = 0;
static volatile int current_angle = SERVO_INIT_ANGLE;
static pthread_mutex_t angle_mutex = PTHREAD_MUTEX_INITIALIZER;
/************************* 角度转脉宽，软件PWM驱动舵机 *************************/
static void servo_pwm_output(int angle) {
    // 双重角度限位（硬件级保护）
    int safe_angle = angle;
    if (safe_angle < SERVO_MIN_ANGLE) safe_angle = SERVO_MIN_ANGLE;
    if (safe_angle > SERVO_MAX_ANGLE) safe_angle = SERVO_MAX_ANGLE;
    // 脉宽硬限位（避免超出舵机承受范围）
    int high_time_us = 1500 + (safe_angle * 1000 / 90);
    if (high_time_us < 500) high_time_us = 500;   // 最小0.5ms
    if (high_time_us > 2500) high_time_us = 2500; // 最大2.5ms
    int low_time_us = 20000 - high_time_us;
    // ✅ 用 gpio_set_value_fast 替代 gpio_set_value，去掉 3ms 防抖
    for (int i = 0; i < 3; i++) {
        gpio_set_value_fast(SERVO_GPIO, 1);
        usleep(high_time_us);
        gpio_set_value_fast(SERVO_GPIO, 0);
        usleep(low_time_us);
    }
}
/************************* 循环扫描线程 *************************/
static void *scan_thread_func(void *arg)
{
    int angle = SERVO_INIT_ANGLE;
    int direction = 1; // 1=右转，-1=左转
    while (scan_running) {
        if (scan_stop_flag) {
            usleep(10000);
            continue;
        }
        // 角度步进
        angle += direction * SERVO_STEP;
        // 到达边界反转方向
        if (angle >= SERVO_MAX_ANGLE) {
            angle = SERVO_MAX_ANGLE;
            direction = -1;
        } else if (angle <= SERVO_MIN_ANGLE) {
            angle = SERVO_MIN_ANGLE;
            direction = 1;
        }
        // 输出PWM
        servo_set_angle(angle);
        usleep(SERVO_DELAY_MS * 1000);
    }
    // 扫描停止后归位到初始角度
    servo_set_angle(SERVO_INIT_ANGLE);
    pthread_exit(NULL);
}
/************************* 舵机初始化 *************************/
int servo_init(void)
{
    gpio_export(SERVO_GPIO);
    gpio_set_dir(SERVO_GPIO, GPIO_OUT);
    gpio_set_value(SERVO_GPIO, 0);
    servo_set_angle(SERVO_INIT_ANGLE);
    printf("【舵机】初始化完成，归位到%d度\n", SERVO_INIT_ANGLE);
    return 0;
}
/************************* 设置舵机角度 *************************/
void servo_set_angle(int angle)
{
    if (angle < SERVO_MIN_ANGLE) angle = SERVO_MIN_ANGLE;
    if (angle > SERVO_MAX_ANGLE) angle = SERVO_MAX_ANGLE;
    servo_pwm_output(angle);
    pthread_mutex_lock(&angle_mutex);
    current_angle = angle;
    pthread_mutex_unlock(&angle_mutex);
}
/************************* 获取当前舵机角度 *************************/
int servo_get_angle(void)
{
    int angle;
    pthread_mutex_lock(&angle_mutex);
    angle = current_angle;
    pthread_mutex_unlock(&angle_mutex);
    return angle;
}
/************************* 启动循环扫描 *************************/
void servo_start_scan(void)
{
    if (scan_running) return;
    scan_stop_flag = 0;
    scan_running = 1;
    pthread_create(&scan_thread, NULL, scan_thread_func, NULL);
    printf("【舵机】循环扫描已启动\n");
}
/************************* 停止循环扫描 *************************/
/**
 * @brief 完全停止扫描线程
 *        设置停止标志 + 标记scan_running=0 + 等待线程结束
 *        与 servo_start_scan() 配对使用，确保可以重新创建扫描线程
 */
void servo_stop_scan(void)
{
    scan_stop_flag = 1;
    scan_running = 0;                    // 标记为停止，允许重新创建
    if (scan_thread) {
        pthread_join(scan_thread, NULL); // 等待线程真正退出
        scan_thread = 0;
    }
    printf("【舵机】扫描已停止\n");
}
/************************* 舵机资源释放 *************************/
void servo_deinit(void)
{
    scan_running = 0;
    scan_stop_flag = 1;
    if (scan_thread) {
        pthread_join(scan_thread, NULL);
    }
    servo_set_angle(SERVO_INIT_ANGLE);
    gpio_unexport(SERVO_GPIO);
    pthread_mutex_destroy(&angle_mutex);
    printf("【舵机】资源释放完成\n");
}