/**
 * ============================================================================
 * 文件: main.c
 * 描述: 主程序——多线程整合+开关控制+状态机
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现多线程整合与开关控制状态机
 * ============================================================================
 */

/**
 * ============================================================================
 * 搜救小船主控程序 v3.0 —— 开关控制整合版
 * ============================================================================
 *
 * 开关控制架构:
 *   开关ON  → 初始化硬件 → 启动vision.py → 创建6线程 → 正常运行
 *   开关OFF → 设置退出标志 → 等待线程结束 → kill vision.py → 释放资源
 *
 * 支持循环启动: 关闭后可再次打开开关重新启动系统
 *
 * 模块:
 *   motor   : 电机控制  (/dev/ttyUSB0)
 *   servo   : 雷达舵机扫描 (GPIO510)
 *   visual  : 视觉舵机控制 (GPIO445)
 *   radar   : 超声波测距(GPIO)
 *   gps     : GPS定位   (/dev/ttyAMA2)
 *   ec20    : 4G上传    (/dev/ttyUSB2)
 *   vision  : YOLO识别  (独立python进程, 只做纯视觉计算)
 *   switch  : 电源开关  (GPIO输入)
 *
 * 线程优先级 (SCHED_FIFO):
 *   motor_control=90  radar=80  servo=75
 *   vision_coord=65   gps=50    ec20=40
 *
 * 串口分配 (独立无抢占):
 *   /dev/ttyUSB0 → motor  |  /dev/ttyAMA2 → gps  |  /dev/ttyUSB2 → ec20
 * ============================================================================
 */

#include "motor.h"
#include "radar.h"
#include "servo.h"
#include "visual_servo.h"
#include "gps.h"
#include "ec20.h"
#include "switch.h"
#include "boat_common.h"

/* ===================== 运行参数配置 ===================== */
#define NORMAL_SPEED         1500
#define TURN_SPEED           1800
#define CHECK_INTERVAL_MS    100

/* ===================== 系统状态定义 ===================== */
typedef enum {
    SYS_INIT = 0,
    SYS_FORWARD,
    SYS_AVOIDING,
    SYS_FOUND_TARGET,
    SYS_STOPPED
} SystemState;

typedef enum {
    VISION_IDLE = 0,
    VISION_TRIGGERED,
    VISION_HUMAN,
    VISION_NOT_HUMAN
} VisionState;

/* ===================== 全局共享状态 ===================== */
static volatile int       g_exit_flag = 0;        // 单次运行退出标志
static volatile int       g_shutdown_flag = 0;    // 全局关机标志(Ctrl+C)
static volatile int       g_system_running = 0;   // 系统是否运行中
static volatile SystemState g_system_state = SYS_INIT;
static volatile VisionState g_vision_state = VISION_IDLE;
static volatile int       g_obstacle_angle = 0;
static volatile int       g_found_target = 0;
static volatile int       g_visual_servo_ready = 0;  // 视觉舵机是否已就位（1=已转到位）

static pthread_mutex_t    g_state_mutex = PTHREAD_MUTEX_INITIALIZER;

/* ===================== 线程句柄 ===================== */
static pthread_t motor_tid, radar_tid, servo_tid, vision_tid, gps_tid, ec20_tid;

/* ===================== vision.py 子进程PID ===================== */
static pid_t g_vision_pid = -1;

/* ===================== 信号处理 ===================== */
static void sigint_handler(int signo)
{
    if (signo == SIGINT) {
        printf("\n[系统] 收到SIGINT，请求关机...\n");
        g_shutdown_flag = 1;
        g_exit_flag = 1;
    }
}

/* ===================== 实时线程创建工具 ===================== */
static int create_rt_thread(pthread_t *tid, void *(*func)(void*), void *arg,
                            int prio, const char *name)
{
    pthread_attr_t attr;
    struct sched_param param;

    pthread_attr_init(&attr);
    pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
    pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
    param.sched_priority = prio;
    pthread_attr_setschedparam(&attr, &param);

    int ret = pthread_create(tid, &attr, func, arg);
    pthread_attr_destroy(&attr);

    if (ret == 0) {
        printf("[线程] %-10s 已创建 | SCHED_FIFO | 优先级 %2d\n", name, prio);
    } else {
        fprintf(stderr, "[线程错误] %-10s 创建失败: %d\n", name, ret);
    }
    return ret;
}

/* ===================== 视觉文件通信 ===================== */
static void write_angle_file(int angle)
{
    FILE *fp = fopen(ANGLE_FILE, "w");
    if (fp) {
        fprintf(fp, "%d\n", angle);
        fclose(fp);
        printf("[视觉通信] 已写入 %s: %d°\n", ANGLE_FILE, angle);
    } else {
        fprintf(stderr, "[视觉通信错误] 无法写入 %s\n", ANGLE_FILE);
    }
}

static int read_result_file(char *buf, size_t len)
{
    FILE *fp = fopen(RESULT_FILE, "r");
    if (!fp) return -1;
    if (fgets(buf, len, fp) == NULL) {
        fclose(fp);
        return -1;
    }
    buf[strcspn(buf, "\n")] = 0;
    fclose(fp);
    return 0;
}

static void reset_result_file(void)
{
    FILE *fp = fopen(RESULT_FILE, "w");
    if (fp) {
        fprintf(fp, "waiting\n");
        fclose(fp);
    }
}

static int read_capture_b64(char *buf, size_t len)
{
    FILE *fp = fopen(CAPTURE_B64_FILE, "r");
    if (!fp) return -1;
    size_t read_len = fread(buf, 1, len - 1, fp);
    fclose(fp);
    if (read_len == 0) return -1;
    buf[read_len] = '\0';
    size_t tail = strlen(buf);
    while (tail > 0 && (buf[tail - 1] == '\n' || buf[tail - 1] == '\r')) {
        buf[--tail] = '\0';
    }
    if (strlen(buf) < 100) return -1;
    printf("[视觉] 成功读取照片Base64，长度 %zu 字节\n", strlen(buf));
    return 0;
}


/* ===================== 线程1: 电机控制 (优先级90) ===================== */
void *motor_control_thread(void *arg)
{
    (void)arg;
    printf("[电机线程] 启动 | 优先级 %d | 状态机驱动\n", PRIO_MOTOR_CTRL);

    motor_forward(NORMAL_SPEED);

    while (!g_exit_flag) {
        int dist = ultrasonic_get_distance();
        int angle = ultrasonic_get_angle();

        pthread_mutex_lock(&g_state_mutex);
        SystemState state  = g_system_state;
        VisionState vision = g_vision_state;
        int obs_angle      = g_obstacle_angle;
        int found          = g_found_target;
        pthread_mutex_unlock(&g_state_mutex);

        if (found) {
            motor_stop();
            printf("[电机] 发现搜救目标，永久停止!\n");
            break;
        }

        switch (state) {
            case SYS_INIT:
            case SYS_FORWARD: {
                if (dist < OBSTACLE_THRESHOLD && dist != 999) {
                    motor_stop();
                    usleep(200000);

                    pthread_mutex_lock(&g_state_mutex);
                    g_system_state   = SYS_AVOIDING;
                    g_vision_state   = VISION_TRIGGERED;
                    g_obstacle_angle = angle;
                    g_visual_servo_ready = 0;  // 视觉舵机尚未就位
                    pthread_mutex_unlock(&g_state_mutex);

                    printf("[电机] ⚠️ 障碍物 dist=%dcm angle=%d° | 停止→进入避障\n",
                           dist, angle);
                } else {
                    motor_forward(NORMAL_SPEED);
                }
                break;
            }

            case SYS_AVOIDING: {
                motor_stop();

                /* ---- 首次进入避障：视觉舵机就位 ---- */
                if (!g_visual_servo_ready) {
                    printf("[电机] 视觉舵机就位中 (角度=%d°)...\n", obs_angle);

                    servo_stop_scan();                     // ① 停止雷达舵机扫描
                    visual_servo_set_angle(obs_angle);     // ② 转动视觉舵机到障碍物角度
                    write_angle_file(obs_angle);           // ③ 触发vision.py拍照
                    reset_result_file();

                    g_visual_servo_ready = 1;
                    printf("[电机] 视觉舵机已就位，等待YOLO识别...\n");
                }

                if (vision == VISION_HUMAN) {
                    printf("[电机] ✅ 视觉确认是人! 永久停止\n");
                    pthread_mutex_lock(&g_state_mutex);
                    g_found_target = 1;
                    g_system_state = SYS_FOUND_TARGET;
                    pthread_mutex_unlock(&g_state_mutex);

                } else if (vision == VISION_NOT_HUMAN) {
                    printf("[电机] ❌ 视觉确认非人，执行避障转向\n");

                    /* ---- 避障转向 ---- */
                    if (obs_angle > 0) {
                        printf("[避障] 右侧障碍 → 左转\n");
                        motor_left(TURN_SPEED);
                    } else if (obs_angle < 0) {
                        printf("[避障] 左侧障碍 → 右转\n");
                        motor_right(TURN_SPEED);
                    } else {
                        printf("[避障] 正前方障碍 → 默认左转\n");
                        motor_left(TURN_SPEED);
                    }
                    usleep(1000000);
                    motor_stop();
                    usleep(300000);

                    /* ---- 恢复双舵机 ---- */
                    printf("[电机] 回正视觉舵机 + 恢复雷达扫描\n");
                    visual_servo_reset();    // 回正视觉舵机到0°
                    servo_start_scan();       // 恢复雷达舵机扫描

                    pthread_mutex_lock(&g_state_mutex);
                    g_vision_state   = VISION_IDLE;
                    g_system_state   = SYS_FORWARD;
                    g_obstacle_angle = 0;
                    pthread_mutex_unlock(&g_state_mutex);

                    motor_forward(NORMAL_SPEED);
                }
                break;
            }

            case SYS_FOUND_TARGET:
            case SYS_STOPPED:
                motor_stop();
                break;
        }
        usleep(CHECK_INTERVAL_MS * 1000);
    }

    motor_stop();
    printf("[电机线程] 退出\n");
    return NULL;
}

/* ===================== 线程2: 超声波测距 (优先级80) ===================== */
void *radar_thread(void *arg)
{
    (void)arg;
    printf("[雷达线程] 启动 | 优先级 %d\n", PRIO_RADAR);
    ultrasonic_start();
    while (!g_exit_flag) usleep(500000);
    ultrasonic_stop();
    printf("[雷达线程] 退出\n");
    return NULL;
}

/* ===================== 线程3: 舵机扫描 (优先级75) ===================== */
void *servo_thread(void *arg)
{
    (void)arg;
    printf("[舵机线程] 启动 | 优先级 %d\n", PRIO_SERVO);
    servo_start_scan();
    while (!g_exit_flag) usleep(500000);
    servo_stop_scan();
    printf("[舵机线程] 退出\n");
    return NULL;
}

/* ===================== 线程4: 视觉协调 (优先级65) ===================== */
void *vision_coord_thread(void *arg)
{
    (void)arg;
    printf("[视觉线程] 启动 | 优先级 %d\n", PRIO_VISION_COORD);

    while (!g_exit_flag) {
        pthread_mutex_lock(&g_state_mutex);
        VisionState vision = g_vision_state;
        pthread_mutex_unlock(&g_state_mutex);

        if (vision != VISION_TRIGGERED) {
            usleep(50000);
            continue;
        }

        printf("[视觉] 等待识别结果 (超时 %d ms)...\n", VISION_TIMEOUT_MS);
        char result_buf[16] = {0};
        int got_result = 0;
        int wait_count = 0;
        int max_wait = VISION_TIMEOUT_MS / 100;  // 100ms × 300 = 30秒
        int processing_seen = 0;                 // 是否已收到processing信号

        while (wait_count < max_wait && !g_exit_flag) {
            usleep(100000);  // 100ms轮询

            if (read_result_file(result_buf, sizeof(result_buf)) == 0) {
                if (strcmp(result_buf, "processing") == 0) {
                    /* ---- vision.py已开始工作，重置超时计数 ---- */
                    if (!processing_seen) {
                        printf("[视觉] 📷 视觉模块已开始工作 (processing)...\n");
                        processing_seen = 1;
                    }
                    wait_count = 0;  // 重置超时：只要视觉在工作就不超时
                    continue;
                } else if (strcmp(result_buf, "yes") == 0) {
                    got_result = 1;
                    printf("[视觉] ✅ 识别结果: 是人!\n");

                    char b64_buf[2048] = {0};
                    int have_photo = (read_capture_b64(b64_buf, sizeof(b64_buf)) == 0);
                    float lat = 0.0f, lon = 0.0f;
                    long ts = 0;
                    int have_gps = (gps_get_position(&lat, &lon, &ts) == 0);

                    if (have_photo && have_gps) {
                        printf("[视觉] 触发EC20上报 | 坐标: %.6f, %.6f\n", lat, lon);
                        ec20_trigger_upload(lat, lon, b64_buf);
                    } else {
                        printf("[视觉] 数据缺失 photo=%s gps=%s | 不上报\n",
                               have_photo ? "OK" : "FAIL",
                               have_gps ? "OK" : "FAIL");
                    }

                    pthread_mutex_lock(&g_state_mutex);
                    g_vision_state = VISION_HUMAN;
                    pthread_mutex_unlock(&g_state_mutex);
                    break;
                } else if (strcmp(result_buf, "no") == 0) {
                    got_result = 1;
                    printf("[视觉] ❌ 识别结果: 非人，执行避障\n");
                    pthread_mutex_lock(&g_state_mutex);
                    g_vision_state = VISION_NOT_HUMAN;
                    pthread_mutex_unlock(&g_state_mutex);
                    break;
                }
                /* result == "waiting": vision.py还没开始，继续轮询 */
            }
            wait_count++;
        }

        if (!got_result && !g_exit_flag) {
            printf("[视觉] ⏱️ 等待超时 (%.1f秒)，按非人处理\n",
                   VISION_TIMEOUT_MS / 1000.0f);
            pthread_mutex_lock(&g_state_mutex);
            g_vision_state = VISION_NOT_HUMAN;
            pthread_mutex_unlock(&g_state_mutex);
        }
    }
    printf("[视觉线程] 退出\n");
    return NULL;
}

/* ===================== 线程5: GPS定位 (优先级50) ===================== */
void *gps_thread(void *arg)
{
    (void)arg;
    printf("[GPS线程]  启动 | 优先级 %d\n", PRIO_GPS);
    if (gps_init() != 0) {
        fprintf(stderr, "[GPS] 初始化失败，线程退出\n");
        return NULL;
    }
    gps_thread_func(NULL);
    printf("[GPS线程]  退出\n");
    return NULL;
}

/* ===================== 线程6: EC20 4G上传 (优先级40) ===================== */
void *ec20_thread(void *arg)
{
    (void)arg;
    printf("[EC20线程] 启动 | 优先级 %d\n", PRIO_EC20);
    if (ec20_init() != 0) {
        fprintf(stderr, "[EC20] 初始化失败，线程退出\n");
        return NULL;
    }
    ec20_thread_func(NULL);
    printf("[EC20线程] 退出\n");
    return NULL;
}


/* ============================================================================
 *                        vision.py 子进程管理
 * ============================================================================ */

/**
 * @brief 启动 vision.py 子进程
 *        使用 fork() + execlp() 启动独立的 Python 进程
 * @return 0成功，-1失败
 */
static int vision_start(void)
{
    if (g_vision_pid > 0) {
        printf("[vision] 进程已运行 PID=%d，无需重复启动\n", g_vision_pid);
        return 0;
    }

    printf("[vision] 正在启动 %s %s ...\n", VISION_PYTHON_CMD, VISION_SCRIPT_NAME);

    pid_t pid = fork();
    if (pid < 0) {
        perror("[vision] fork() 失败");
        return -1;
    }

    if (pid == 0) {
        /* ====== 子进程 ====== */
        /* 降低CPU优先级至最低，避免抢占C程序的实时线程 */
        nice(19);

        /* 重定向标准输出/错误到日志文件，避免干扰终端 */
        int log_fd = open("vision.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (log_fd >= 0) {
            dup2(log_fd, STDOUT_FILENO);
            dup2(log_fd, STDERR_FILENO);
            close(log_fd);
        }
        /* 执行 Python 脚本 */
        execlp(VISION_PYTHON_CMD, VISION_PYTHON_CMD, VISION_SCRIPT_NAME, NULL);
        /* 如果 execlp 返回，说明执行失败 */
        perror("[vision] execlp() 失败");
        _exit(1);
    }

    /* ====== 父进程 ====== */
    g_vision_pid = pid;
    printf("[vision] 子进程已启动 PID=%d\n", pid);

    /* 等待 2 秒让 vision.py 完成初始化 (舵机复位、摄像头打开、模型加载) */
    printf("[vision] 等待 vision.py 初始化 (2秒)...\n");
    usleep(2000000);

    return 0;
}

/**
 * @brief 停止 vision.py 子进程
 *        先发送 SIGTERM 优雅退出，超时后用 SIGKILL 强制终止
 */
static void vision_stop(void)
{
    if (g_vision_pid <= 0) return;

    printf("[vision] 正在停止子进程 PID=%d...\n", g_vision_pid);

    /* Step 1: 优雅退出信号 */
    if (kill(g_vision_pid, SIGTERM) == 0) {
        /* 等待最多 1 秒 */
        int status;
        pid_t ret;
        int wait_count = 0;
        while (wait_count < 10) {
            ret = waitpid(g_vision_pid, &status, WNOHANG);
            if (ret == g_vision_pid) {
                printf("[vision] 子进程已优雅退出\n");
                g_vision_pid = -1;
                return;
            }
            usleep(100000);  /* 100ms */
            wait_count++;
        }
    }

    /* Step 2: 强制终止 */
    printf("[vision] SIGTERM 超时，发送 SIGKILL...\n");
    kill(g_vision_pid, SIGKILL);
    waitpid(g_vision_pid, NULL, 0);
    printf("[vision] 子进程已强制终止\n");
    g_vision_pid = -1;
}

/* ============================================================================
 *                        系统启动 / 停止 控制
 * ============================================================================ */

/**
 * @brief 系统完整启动时序
 *        按严格顺序初始化硬件、启动视觉、创建线程
 * @return 0成功，-1失败
 */
static int system_start(void)
{
    int ret;

    printf("\n[启动] ═══════════════════════════════════════════\n");
    printf("[启动] 系统启动序列开始...\n");

    /* ---- Step 1: 重置全局状态 ---- */
    g_exit_flag = 0;
    g_system_running = 1;
    g_system_state = SYS_INIT;
    g_vision_state = VISION_IDLE;
    g_obstacle_angle = 0;
    g_found_target = 0;
    g_visual_servo_ready = 0;
    g_vision_pid = -1;

    /* ---- Step 2: 硬件模块串行初始化 ----
     * 原则: 串口和GPIO逐个初始化，避免资源冲突
     */
    printf("[启动] Step 1/7: 初始化电机串口...\n");
    if (uart_init() != 0) {
        fprintf(stderr, "[致命错误] 电机串口失败\n");
        goto fail_uart;
    }
    if (motor_init() != 0) {
        fprintf(stderr, "[致命错误] 电机参数失败\n");
        goto fail_motor;
    }

    printf("[启动] Step 2/7: 初始化超声波...\n");
    if (ultrasonic_init() != 0) {
        fprintf(stderr, "[致命错误] 超声波失败\n");
        goto fail_ultrasonic;
    }

    printf("[启动] Step 3/7: 初始化雷达舵机...\n");
    if (servo_init() != 0) {
        fprintf(stderr, "[致命错误] 雷达舵机失败\n");
        goto fail_servo;
    }

    printf("[启动] Step 4/7: 初始化视觉舵机...\n");
    if (visual_servo_init() != 0) {
        fprintf(stderr, "[致命错误] 视觉舵机失败\n");
        goto fail_visual_servo;
    }

    /* ---- Step 3: 启动 vision.py 子进程 ----
     * 注意: vision.py 需要2-3秒初始化(YOLO模型加载)
     *       因此在线程创建之前启动，保证系统运行时视觉已就绪
     *       vision.py 以 nice=19 最低CPU优先级运行，避免抢占
     */
    printf("[启动] Step 5/7: 启动视觉模块 (nice=19)...\n");
    if (vision_start() != 0) {
        fprintf(stderr, "[警告] vision.py 启动失败，继续运行但视觉功能不可用\n");
        /* 视觉失败不是致命错误，系统仍可以运行（纯避障模式） */
    }

    /* ---- Step 4: 初始化视觉通信文件 ---- */
    reset_result_file();
    FILE *af = fopen(ANGLE_FILE, "w");
    if (af) {
        fprintf(af, "0\n");
        fclose(af);
    }

    /* ---- Step 5: 创建实时线程 ----
     * 时序: 先创建高优先级线程，确保它们先就绪
     */
    printf("[启动] Step 6/7: 创建工作线程...\n");

    ret = create_rt_thread(&motor_tid, motor_control_thread, NULL,
                           PRIO_MOTOR_CTRL, "电机控制");
    if (ret != 0) goto fail_threads;

    ret = create_rt_thread(&radar_tid, radar_thread, NULL,
                           PRIO_RADAR, "超声波");
    if (ret != 0) goto fail_threads;

    ret = create_rt_thread(&servo_tid, servo_thread, NULL,
                           PRIO_SERVO, "舵机");
    if (ret != 0) goto fail_threads;

    ret = create_rt_thread(&vision_tid, vision_coord_thread, NULL,
                           PRIO_VISION_COORD, "视觉协调");
    if (ret != 0) goto fail_threads;

    ret = create_rt_thread(&gps_tid, gps_thread, NULL,
                           PRIO_GPS, "GPS");
    if (ret != 0) goto fail_threads;

    ret = create_rt_thread(&ec20_tid, ec20_thread, NULL,
                           PRIO_EC20, "EC20");
    if (ret != 0) goto fail_threads;

    printf("[启动] Step 7/7: ✅ 全部线程创建成功\n");
    printf("[启动] 系统进入运行状态\n");
    printf("[启动] ═══════════════════════════════════════════\n\n");
    return 0;

/* ---- 启动失败清理 ---- */
fail_threads:
    g_exit_flag = 1;
    gps_deinit();
    ec20_deinit();
    pthread_join(radar_tid, NULL);
    pthread_join(servo_tid, NULL);
    pthread_join(vision_tid, NULL);
    pthread_join(gps_tid, NULL);
    pthread_join(ec20_tid, NULL);
    vision_stop();
    servo_deinit();
fail_visual_servo:
    visual_servo_deinit();
fail_servo:
    ultrasonic_deinit();
fail_ultrasonic:
    /* motor_deinit 不需要，uart_close 即可 */
fail_motor:
    uart_close();
fail_uart:
    g_system_running = 0;
    printf("[启动] ❌ 系统启动失败\n");
    return -1;
}


/**
 * @brief 系统完整关闭时序
 *        严格按顺序通知退出 → 等待线程 → 停止视觉 → 释放硬件 → 重置状态
 *        保证不发生资源访问冲突（如串口在线程使用中关闭）
 */
static void system_stop(void)
{
    printf("\n[关闭] ═══════════════════════════════════════════\n");
    printf("[关闭] 系统关闭序列开始...\n");

    /* ---- Step 1: 通知所有线程退出 ---- */
    printf("[关闭] Step 1/6: 设置退出标志...\n");
    g_exit_flag = 1;

    /* 通知GPS和EC20模块（它们的内部循环检查模块级退出标志） */
    gps_deinit();
    ec20_deinit();

    /* ---- Step 2: 等待电机线程结束 ----
     * 电机线程是"领导者"，它结束后其他线程可以安全清理
     */
    printf("[关闭] Step 2/6: 等待电机线程...\n");
    pthread_join(motor_tid, NULL);
    printf("[关闭] ✅ 电机线程已结束\n");

    /* ---- Step 3: 等待传感器线程结束 ---- */
    printf("[关闭] Step 3/6: 等待传感器线程...\n");
    pthread_join(radar_tid, NULL);
    pthread_join(servo_tid, NULL);
    pthread_join(vision_tid, NULL);
    printf("[关闭] ✅ 雷达/舵机/视觉线程已结束\n");

    /* ---- Step 4: 等待网络线程结束 ---- */
    printf("[关闭] Step 4/6: 等待网络线程...\n");
    pthread_join(gps_tid, NULL);
    pthread_join(ec20_tid, NULL);
    printf("[关闭] ✅ GPS/EC20线程已结束\n");

    /* ---- Step 5: 停止 vision.py 子进程 ---- */
    printf("[关闭] Step 5/6: 停止视觉子进程...\n");
    vision_stop();
    printf("[关闭] ✅ vision.py 已停止\n");

    /* ---- Step 6: 释放硬件资源 ----
     * 原则: 线程已全部结束，此时释放硬件是安全的
     */
    printf("[关闭] Step 6/7: 释放硬件资源...\n");
    servo_deinit();          /* 雷达舵机归位 + 取消GPIO510导出 */
    visual_servo_deinit();   /* 视觉舵机取消GPIO445导出 */
    ultrasonic_deinit();       /* 取消GPIO导出 */
    uart_close();              /* 关闭电机串口 */

    /* ---- Step 7: 重置全局状态（为下次启动做准备） ---- */
    g_system_running = 0;
    g_system_state = SYS_INIT;
    g_vision_state = VISION_IDLE;
    g_obstacle_angle = 0;
    g_found_target = 0;
    g_visual_servo_ready = 0;
    g_vision_pid = -1;

    /* 清理视觉通信残留文件 */
    remove(ANGLE_FILE);
    remove(RESULT_FILE);

    printf("[关闭] ✅ 所有资源已释放\n");
    printf("[关闭] ═══════════════════════════════════════════\n\n");
}

/* ============================================================================
 *                              main() 入口函数
 * ============================================================================ */

int main(void)
{
    /* ---- 1. 信号注册 ---- */
    signal(SIGINT, sigint_handler);

    printf("\n");
    printf("╔══════════════════════════════════════════════════════════════════╗\n");
    printf("║      搜救小船主控程序 v3.0 —— 开关控制整合版                     ║\n");
    printf("╠══════════════════════════════════════════════════════════════════╣\n");
    printf("║  开关GPIO=%d | 低电平有效=%s                                      ║\n",
           SWITCH_GPIO, SWITCH_ACTIVE_LOW ? "是" : "否");
    printf("║  开关控制: 拨到ON启动系统，拨到OFF关闭系统，支持循环启动          ║\n");
    printf("╠══════════════════════════════════════════════════════════════════╣\n");
    printf("║  模块: 电机 | 舵机 | 雷达 | GPS | EC20(4G) | YOLO视觉 | 开关      ║\n");
    printf("║  串口: ttyUSB0=电机 | ttyAMA2=GPS | ttyUSB2=EC20                 ║\n");
    printf("╠══════════════════════════════════════════════════════════════════╣\n");
    printf("║  线程优先级 (SCHED_FIFO):                                        ║\n");
    printf("║    电机=%2d | 雷达=%2d | 舵机=%2d | 视觉=%2d | GPS=%2d | EC20=%2d       ║\n",
           PRIO_MOTOR_CTRL, PRIO_RADAR, PRIO_SERVO,
           PRIO_VISION_COORD, PRIO_GPS, PRIO_EC20);
    printf("╚══════════════════════════════════════════════════════════════════╝\n");
    printf("\n");

    /* ---- 2. 初始化开关GPIO ---- */
    printf("[初始化] 开关GPIO...\n");
    if (switch_init() != 0) {
        fprintf(stderr, "[致命错误] 开关GPIO初始化失败\n");
        return -1;
    }

    /* ---- 3. 开关控制主循环 ----
     * 循环: 等待ON → 启动系统 → 运行中检测OFF → 关闭系统 → 回到等待ON
     */
    printf("[主控] 进入开关控制主循环\n\n");

    while (!g_shutdown_flag) {
        /* ========== 阶段1: 等待开关ON ========== */
        printf("┌────────────────────────────────────────┐\n");
        printf("│  系统待机中，请将开关拨到 ON 启动       │\n");
        printf("└────────────────────────────────────────┘\n");

        if (switch_wait_on(&g_shutdown_flag) < 0) {
            break;  /* 被SIGINT中断 */
        }

        /* ========== 阶段2: 启动系统 ========== */
        if (system_start() != 0) {
            printf("[主控] 启动失败，回到待机状态\n");
            usleep(1000000);  /* 等待1秒后重试 */
            continue;
        }

        /* ========== 阶段3: 运行中检测开关OFF ========== */
        printf("[主控] 系统运行中，监控开关状态...\n");
        while (!g_exit_flag && !g_shutdown_flag) {
            int sw = switch_read_stable();
            if (sw == 0) {
                /* OFF 消抖确认 */
                usleep(SWITCH_DEBOUNCE_MS * 1000);
                if (switch_read_stable() == 0) {
                    printf("[主控] 开关确认OFF，请求关闭系统\n");
                    g_exit_flag = 1;
                    break;
                }
            }
            usleep(SWITCH_POLL_MS * 1000);  /* 200ms轮询 */
        }

        /* ========== 阶段4: 关闭系统 ========== */
        system_stop();
        printf("[主控] 系统已关闭，回到待机状态\n\n");
        usleep(500000);  /* 500ms 冷却 */
    }

    /* ---- 4. 全局关机清理 ---- */
    printf("\n[主控] 全局关机，释放开关GPIO...\n");
    switch_deinit();

    printf("[主控] ====== 程序已完全退出 ======\n");
    return 0;
}
