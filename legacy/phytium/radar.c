/**
 * ============================================================================
 * 文件: radar.c
 * 描述: 超声波雷达模块——GPIO超声波测距与舵机角度同步
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现GPIO超声波测距与舵机角度同步
 * ============================================================================
 */

#include "radar.h"
#include "gpio.h"
#include "servo.h"
static pthread_t measure_thread;
static volatile int measure_running = 0;
static volatile int current_distance = 999;
static volatile int current_angle = 0;    // ✅ 记录测距时的舵机角度
static pthread_mutex_t data_mutex = PTHREAD_MUTEX_INITIALIZER;
/************************* 单次测距（严格遵循超声波手册时序） *************************/
/************************* 单次测距（修复版） *************************/
static int single_measure(void) {
    struct timeval start, end;
    long time_us;
    int distance_cm;
    char path[64];
    char val_str[2];
    int fd;
    struct timeval timeout_start;

    // 构建 ECHO 引脚的读取路径
    sprintf(path, "/sys/class/gpio/gpio%d/value", ECHO_GPIO);

    // ✅ 提前打开 ECHO，避免循环内反复 open/close
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("【超声波错误】打开 ECHO 失败");
        return 999;
    }

    // 1. 发送触发脉冲 (使用快速函数!)
    gpio_set_value_fast(TRIG_GPIO, 0);
    usleep(20);
    gpio_set_value_fast(TRIG_GPIO, 1);
    usleep(20);  // 严格 20us 脉冲
    gpio_set_value_fast(TRIG_GPIO, 0);

    // 2. 等待回响信号开始 (上升沿)
    gettimeofday(&timeout_start, NULL);
    while (1) {
        // 检查超时 (200ms)
        struct timeval now;
        gettimeofday(&now, NULL);
        long elapsed_ms = (now.tv_sec - timeout_start.tv_sec)*1000 + (now.tv_usec - timeout_start.tv_usec)/1000;
        if (elapsed_ms > 200) {
            close(fd);
            fprintf(stderr, "【超声波错误】触发超时\n");
            return 999;
        }

        // ✅ 用 lseek 替代 open/close
        lseek(fd, 0, SEEK_SET);
        read(fd, val_str, 1);
        
        if (val_str[0] == '1') break; // 等到高电平
        usleep(500);
    }
    
    gettimeofday(&start, NULL);

    // 3. 等待回响信号结束 (下降沿)
    while (1) {
        // 检查超时 (500ms)
        struct timeval now;
        gettimeofday(&now, NULL);
        long elapsed_ms = (now.tv_sec - start.tv_sec)*1000 + (now.tv_usec - start.tv_usec)/1000;
        if (elapsed_ms > 500) {
            close(fd);
            fprintf(stderr, "【超声波错误】回响超时\n");
            return 999;
        }

        // ✅ 用 lseek 替代 open/close
        lseek(fd, 0, SEEK_SET);
        read(fd, val_str, 1);
        
        if (val_str[0] == '0') break; // 等到低电平
        usleep(500);
    }

    gettimeofday(&end, NULL);
    close(fd);  // ✅ 只在最后关闭

    // 4. 计算距离
    time_us = (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_usec - start.tv_usec);
    distance_cm = (int)(time_us * 0.034 / 2);
    
    if (distance_cm < 0 || distance_cm > 500) return 999;
    return distance_cm;
}
/************************* 实时测距线程 *************************/
static void *measure_thread_func(void *arg)
{
    while (measure_running) {
        int angle = servo_get_angle();   // ✅ 获取当前舵机角度
        int dist = single_measure();
        pthread_mutex_lock(&data_mutex);
        current_distance = dist;
        current_angle = angle;           // ✅ 同步记录角度
        pthread_mutex_unlock(&data_mutex);
        usleep(ULTRASONIC_INTERVAL);
    }
    pthread_exit(NULL);
}
/************************* 超声波初始化 *************************/
int ultrasonic_init(void)
{
    gpio_export(TRIG_GPIO);
    gpio_export(ECHO_GPIO);
    gpio_set_dir(TRIG_GPIO, GPIO_OUT);
    gpio_set_dir(ECHO_GPIO, GPIO_IN);
    gpio_set_value(TRIG_GPIO, 0);
    usleep(100000);
    printf("【超声波】初始化完成\n");
    return 0;
}
/************************* 获取当前距离 *************************/
int ultrasonic_get_distance(void)
{
    int dist;
    pthread_mutex_lock(&data_mutex);
    dist = current_distance;
    pthread_mutex_unlock(&data_mutex);
    return dist;
}
/************************* 获取测距时的舵机角度 *************************/
int ultrasonic_get_angle(void)
{
    int angle;
    pthread_mutex_lock(&data_mutex);
    angle = current_angle;
    pthread_mutex_unlock(&data_mutex);
    return angle;
}
/************************* 启动实时测距 *************************/
void ultrasonic_start(void)
{
    if (measure_running) return;
    measure_running = 1;
    pthread_create(&measure_thread, NULL, measure_thread_func, NULL);
    printf("【超声波】实时测距已启动\n");
}
/************************* 停止实时测距 *************************/
void ultrasonic_stop(void)
{
    if (!measure_running) return;
    measure_running = 0;
    pthread_join(measure_thread, NULL);
    printf("【超声波】实时测距已停止\n");
}
/************************* 超声波资源释放 *************************/
void ultrasonic_deinit(void)
{
    ultrasonic_stop();
    gpio_unexport(TRIG_GPIO);
    gpio_unexport(ECHO_GPIO);
    pthread_mutex_destroy(&data_mutex);
    printf("【超声波】资源释放完成\n");
}