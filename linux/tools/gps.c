/**
 * ============================================================================
 * 文件: gps.c
 * 描述: GPS定位模块——串口ttyAMA2 NMEA RMC解析
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现串口ttyAMA2 NMEA RMC解析
 * ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <math.h>
#include <pthread.h>

#include "gps.h"

/* ==================== 配置宏 ==================== */
/* DR1M90 USB GPS default; override using GPS_SERIAL_PORT after enumeration. */
#define GPS_SERIAL_PORT_DEFAULT "/dev/ttyUSB1"
#define GPS_BAUDRATE         B9600
#define GPS_FILE_PATH        "/tmp/gps_data.txt"

/* ==================== 内部静态变量 ==================== */
static int gps_fd = -1;
static long last_ts = 0;
static volatile int gps_exit_flag = 0;

/* 线程间共享的最新GPS坐标，受 gps_data_mutex 保护 */
static double current_lat = 0.0;
static double current_lon = 0.0;
static long current_ts = 0;
static int gps_data_valid = 0;   /* 0 = 无有效数据, 1 = 有有效数据 */
static pthread_mutex_t gps_data_mutex = PTHREAD_MUTEX_INITIALIZER;

/* ==================== 内部静态函数 ==================== */

/**
 * @brief GPS串口初始化（8N1，标准GPS配置）
 * @param dev   串口设备路径
 * @param baud  波特率
 * @return 文件描述符，<0表示失败
 */
static int gps_uart_init(const char *dev, speed_t baud)
{
    int fd = open(dev, O_RDWR | O_NOCTTY);
    if (fd < 0) return -1;

    struct termios opt;
    tcgetattr(fd, &opt);

    cfsetispeed(&opt, baud);
    cfsetospeed(&opt, baud);

    opt.c_cflag |= CLOCAL | CREAD;
    opt.c_cflag &= ~CSIZE;
    opt.c_cflag |= CS8;
    opt.c_cflag &= ~PARENB;
    opt.c_cflag &= ~CSTOPB;

    opt.c_iflag = 0;
    opt.c_oflag = 0;
    opt.c_lflag = 0;

    tcflush(fd, TCIFLUSH);
    tcsetattr(fd, TCSANOW, &opt);
    return fd;
}

/* ==================== 核心公式：度分 → 十进制度 ==================== */
double Convert_to_degrees(char *data)
{
    double temp = atof(data);
    int degree = (int)(temp / 100);
    double min = temp - degree * 100.0;
    return degree + min / 60.0;
}

/* ==================== 写入GPS数据 ==================== */
static void write_gps(double lat, double lon)
{
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return;
    if (fabs(lat) < 0.0001 && fabs(lon) < 0.0001) return;

    long now = time(NULL);
    if (now - last_ts < 1) return;
    last_ts = now;

    /* (a) 写入文件供EC20模块读取，格式: 纬度,经度,时间戳 */
    FILE *f = fopen(GPS_FILE_PATH, "w");
    if (f) {
        fprintf(f, "%.6f,%.6f,%ld\n", lat, lon, now);
        fclose(f);
    }

    /* (b) 更新内存中的最新坐标（供其他线程快速查询） */
    pthread_mutex_lock(&gps_data_mutex);
    current_lat = lat;
    current_lon = lon;
    current_ts = now;
    gps_data_valid = 1;
    pthread_mutex_unlock(&gps_data_mutex);

    printf("[GPS有效] %.6f, %.6f\n", lat, lon);
}

/* ==================== 解析 RMC（逗号分段提取） ==================== */
void parse_rmc(char *line)
{
    char buf[512];
    strncpy(buf, line, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    char *p = buf;
    char *field[20] = {0};
    int cnt = 0;

    /* 按逗号分割 */
    while (p && cnt < 20) {
        field[cnt++] = p;
        p = strchr(p, ',');
        if (p) *p++ = 0;
    }

    if (cnt < 7) return;

    /* 定位状态 A=有效 */
    if (!field[2] || field[2][0] != 'A') return;

    /* 提取经纬度 */
    char *lat_str = field[3];
    char *ns = field[4];
    char *lon_str = field[5];
    char *ew = field[6];

    if (!lat_str || !ns || !lon_str || !ew) return;

    double lat = Convert_to_degrees(lat_str);
    double lon = Convert_to_degrees(lon_str);

    if (ns[0] == 'S') lat = -lat;
    if (ew[0] == 'W') lon = -lon;

    write_gps(lat, lon);
}

/* ==================== 对外接口 ==================== */

/**
 * @brief GPS模块初始化（打开串口）
 * @return 0成功，-1失败
 */
int gps_init(void)
{
    const char *gps_port = getenv("GPS_SERIAL_PORT");
    if (!gps_port || !*gps_port) gps_port = GPS_SERIAL_PORT_DEFAULT;
    gps_fd = gps_uart_init(gps_port, GPS_BAUDRATE);
    if (gps_fd < 0) {
        fprintf(stderr, "[GPS] 串口打开失败: %s\n", gps_port);
        return -1;
    }

    /* 重置退出标志和数据状态 */
    gps_exit_flag = 0;
    gps_data_valid = 0;
    last_ts = 0;

    printf("[GPS] 模块初始化完成，串口已打开: %s\n", gps_port);
    return 0;
}

/**
 * @brief GPS主循环线程函数（供pthread_create调用）
 * @param arg 线程参数（可传NULL）
 * @return 线程返回值（NULL）
 */
void *gps_thread_func(void *arg)
{
    (void)arg;  /* 未使用参数，消除警告 */

    if (gps_fd < 0) {
        fprintf(stderr, "[GPS] 串口未打开，线程退出\n");
        return NULL;
    }

    printf("[GPS] 线程启动，等待定位...\n");

    char line[512] = {0};
    int idx = 0;

    while (!gps_exit_flag) {
        char c;
        int n = read(gps_fd, &c, 1);
        if (n <= 0) {
            if (errno == EINTR) continue;   /* 被信号打断，继续 */
            usleep(1000);                   /* 短暂休眠避免CPU空转 */
            continue;
        }

        if (c == '\n') {
            line[idx] = 0;
            idx = 0;

            /* 只处理 RMC */
            if (strstr(line, "$GPRMC") || strstr(line, "$GNRMC")) {
                parse_rmc(line);
            }
        }
        else if (c != '\r') {
            if (idx < 511) line[idx++] = c;
        }
    }

    printf("[GPS] 线程退出\n");
    return NULL;
}

/**
 * @brief GPS资源释放（关闭串口，设置退出标志）
 */
void gps_deinit(void)
{
    /* 设置退出标志，通知线程退出 */
    gps_exit_flag = 1;

    /* 关闭串口 */
    if (gps_fd >= 0) {
        close(gps_fd);
        gps_fd = -1;
    }

    printf("[GPS] 模块已释放\n");
}

/**
 * @brief 获取当前最新GPS坐标（线程安全）
 * @param lat       输出纬度（浮点数）
 * @param lon       输出经度（浮点数）
 * @param timestamp 输出时间戳（秒级Unix时间）
 * @return 0成功且数据有效，-1失败或无有效数据
 */
int gps_get_position(float *lat, float *lon, long *timestamp)
{
    if (!lat || !lon || !timestamp) return -1;

    pthread_mutex_lock(&gps_data_mutex);
    if (!gps_data_valid) {
        pthread_mutex_unlock(&gps_data_mutex);
        return -1;
    }
    *lat = (float)current_lat;
    *lon = (float)current_lon;
    *timestamp = current_ts;
    pthread_mutex_unlock(&gps_data_mutex);

    return 0;
}
