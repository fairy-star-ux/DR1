/**
 * ============================================================================
 * 文件: ec20.c
 * 描述: 4G通信模块——AT指令序列 OneNET MQTT上传
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现AT指令序列 OneNET MQTT上传
 * ============================================================================
 */

/************************* 头文件引入（Linux系统自带，无需额外安装） *************************/
#include "ec20.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>

/************************* 【必须修改】配置参数区（替换为你的实际信息） *************************/
#define ONENET_PRODUCT_ID     ""    // OneNET平台产品ID
#define ONENET_DEVICE_NAME    ""         // OneNET平台设备名称
#define ONENET_DEVICE_KEY     ""         // OneNET平台设备秘钥
#define EC20_SERIAL_PORT      "/dev/ttyUSB2"         // EC20 mini PCIe映射的串口号（如ttyUSB0）
#define UPLOAD_CHECK_INTERVAL 2                       // 新数据检测间隔（单位：秒，不用改太大）
/************************* 固定配置参数（无需修改，适配EC20+OneNET） *************************/
#define EC20_BAUDRATE         B115200    // EC20模块默认波特率，固定115200
#define SERIAL_BUF_SIZE       1024        // 串口收发缓冲区大小
#define PHOTO_B64_MAX_LEN     1500        // 照片Base64最大长度（适配EC20单包限制）
#define MQTT_CLIENT_IDX       0           // MQTT客户端索引，单设备固定0
// 固定文件路径（内存目录/tmp，不磨损SD卡，与GPS/视觉模块路径完全对应）
#define GPS_FILE_PATH         "/tmp/gps_data.txt"
#define PHOTO_FILE_PATH       "/tmp/photo_b64.txt"

/************************* 全局变量（防重复上报用，无需修改） *************************/
static long last_gps_timestamp = 0;    // 上一次上报的GPS数据时间戳
static long last_photo_timestamp = 0;  // 上一次上报的照片数据时间戳
static int upload_fail_count = 0;       // 上报失败计数，用于异常重连

/************************* 模块线程控制与状态变量 *************************/
static volatile int ec20_exit_flag = 0;   // 线程退出标志，非0时线程安全退出
static int ec20_serial_fd = -1;          // EC20串口文件描述符，模块状态核心
static pthread_mutex_t ec20_mutex = PTHREAD_MUTEX_INITIALIZER; // 保护触发上报共享缓冲区

/************************* 强制触发上报共享缓冲区（线程安全） *************************/
static volatile int ec20_trigger_flag = 0;         // 触发标志，非0表示有待上报数据
static float trigger_lat = 0.0f;                   // 触发上报的纬度
static float trigger_lon = 0.0f;                   // 触发上报的经度
static char trigger_photo_b64[PHOTO_B64_MAX_LEN] = {0}; // 触发上报的照片Base64

/************************* 函数声明 *************************/
// 串口底层操作（传输核心基础）
int serial_open(const char *port, speed_t baud_rate);
int serial_send(int serial_fd, const char *at_cmd);
int serial_recv(int serial_fd, char *recv_buf, int max_len, int timeout_ms);
int serial_close(int serial_fd);
// EC20 4G+MQTT传输核心操作
int ec20_check_at(int serial_fd);
int ec20_get_csq(int serial_fd);
int ec20_init_4g_network(int serial_fd);
int ec20_deinit_4g_network(int serial_fd);  // 新增：4G网络反初始化
int ec20_mqtt_config(int serial_fd);
int ec20_mqtt_connect_onenet(int serial_fd);
int ec20_mqtt_disconnect(int serial_fd);    // 新增：MQTT断开连接
int onenet_upload_data(int serial_fd, float latitude, float longitude, const char *photo_b64);
// 【核心适配】从文件读取数据（对应你的方案）
int gps_read_from_file(float *out_latitude, float *out_longitude);
int photo_read_from_file(char *out_b64_buf, int max_buf_len);

/************************* 【重构】对外接口函数实现 *************************/

/**
 * @brief EC20模块初始化
 *
 * 执行完整的初始化序列：打开串口 -> AT检查 -> 信号检测 -> 4G网络激活 -> MQTT配置 -> OneNET连接
 *
 * @return 0 on success, -1 on failure
 */
int ec20_init(void)
{
    if (ec20_serial_fd >= 0)
    {
        printf("【警告】EC20模块已初始化，请勿重复调用 ec20_init()\n");
        return 0;
    }

    printf("==================== EC20 模块初始化开始 ====================\n");

    // 1. 打开EC20模块串口（传输通道初始化）
    ec20_serial_fd = serial_open(EC20_SERIAL_PORT, EC20_BAUDRATE);
    if (ec20_serial_fd < 0)
    {
        printf("【致命错误】EC20串口打开失败！请检查串口号、权限、模块接线\n");
        return -1;
    }
    printf("【成功】EC20串口打开成功：%s\n", EC20_SERIAL_PORT);

    // 2. 检查EC20模块AT通信是否正常
    if (ec20_check_at(ec20_serial_fd) != 0)
    {
        printf("【致命错误】EC20模块AT通信失败！请检查模块供电、接线、波特率\n");
        serial_close(ec20_serial_fd);
        ec20_serial_fd = -1;
        return -1;
    }
    printf("【成功】EC20模块AT通信正常\n");

    // 3. 检查4G信号强度
    int csq = ec20_get_csq(ec20_serial_fd);
    if (csq < 10)
    {
        printf("【警告】4G信号偏弱（CSQ=%d），建议检查天线、SIM卡\n", csq);
    }
    else
    {
        printf("【成功】4G信号正常，CSQ=%d\n", csq);
    }

    // 4. 初始化4G网络（激活PDP上下文，传输底层通道）
    if (ec20_init_4g_network(ec20_serial_fd) != 0)
    {
        printf("【致命错误】4G网络初始化失败！请检查SIM卡、流量、APN配置\n");
        serial_close(ec20_serial_fd);
        ec20_serial_fd = -1;
        return -1;
    }
    printf("【成功】4G网络激活成功，PDP上下文已生效\n");

    // 5. 配置MQTT参数
    if (ec20_mqtt_config(ec20_serial_fd) != 0)
    {
        printf("【致命错误】MQTT参数配置失败！\n");
        serial_close(ec20_serial_fd);
        ec20_serial_fd = -1;
        return -1;
    }
    printf("【成功】MQTT参数配置完成\n");

    // 6. 连接OneNET MQTT服务器（核心传输通道建立）
    if (ec20_mqtt_connect_onenet(ec20_serial_fd) != 0)
    {
        printf("【致命错误】OneNET MQTT连接失败！请检查产品ID、设备名、秘钥\n");
        serial_close(ec20_serial_fd);
        ec20_serial_fd = -1;
        return -1;
    }
    printf("【成功】OneNET MQTT服务器连接成功！\n");

    // 重置模块状态计数器
    upload_fail_count = 0;
    ec20_exit_flag = 0;
    ec20_trigger_flag = 0;

    printf("==================== EC20 模块初始化完成 ====================\n");
    return 0;
}

/**
 * @brief EC20主循环线程函数
 *
 * 供pthread_create调用。循环检测新数据并上报：
 *  - 优先检查 ec20_trigger_flag（强制触发，外部调用 ec20_trigger_upload() 设置）
 *  - 其次检查文件 photo_b64.txt / gps_data.txt（原始检测方式）
 *  - 上报失败3次自动执行重连（断开MQTT -> 去激活PDP -> 重新初始化4G -> 重连MQTT）
 *  - 检查 ec20_exit_flag 后安全退出循环
 *
 * @param arg 线程参数，可传入NULL
 * @return NULL
 */
void *ec20_thread_func(void *arg)
{
    float gps_lat = 0.0f, gps_lon = 0.0f;
    char photo_b64_buf[PHOTO_B64_MAX_LEN] = {0};
    time_t current_time;
    struct tm *local_time;
    int have_data = 0;

    (void)arg; // 抑制未使用参数警告

    printf("==================== EC20 上报线程启动 ====================\n");
    printf("检测间隔：%d秒，支持文件检测和强制触发上报\n", UPLOAD_CHECK_INTERVAL);
    printf("===========================================================\n");

    while (!ec20_exit_flag)
    {
        // 清空缓冲区，避免数据残留
        memset(photo_b64_buf, 0, PHOTO_B64_MAX_LEN);
        gps_lat = 0.0f;
        gps_lon = 0.0f;
        have_data = 0;

        // 获取当前时间，打印日志
        time(&current_time);
        local_time = localtime(&current_time);
        printf("\n【%04d-%02d-%02d %02d:%02d:%02d】开始检测新数据\n",
               local_time->tm_year + 1900, local_time->tm_mon + 1, local_time->tm_mday,
               local_time->tm_hour, local_time->tm_min, local_time->tm_sec);

        // 【方式1】优先检查是否有强制触发上报请求（外部调用 ec20_trigger_upload() 设置）
        pthread_mutex_lock(&ec20_mutex);
        if (ec20_trigger_flag)
        {
            gps_lat = trigger_lat;
            gps_lon = trigger_lon;
            strncpy(photo_b64_buf, trigger_photo_b64, PHOTO_B64_MAX_LEN - 1);
            photo_b64_buf[PHOTO_B64_MAX_LEN - 1] = '\0';
            ec20_trigger_flag = 0; // 清除触发标志，数据已拷贝到本地缓冲区
            have_data = 1;
            printf("【触发】检测到强制上报请求，使用外部传入数据（lat=%.6f, lon=%.6f, photo_len=%zu）\n",
                   gps_lat, gps_lon, strlen(photo_b64_buf));
        }
        pthread_mutex_unlock(&ec20_mutex);

        // 【方式2】无触发请求时，执行原有文件检测逻辑
        if (!have_data)
        {
            // 优先读取新照片数据（只有视觉识别到目标才会生成新文件，触发上报）
            if (photo_read_from_file(photo_b64_buf, PHOTO_B64_MAX_LEN) == 0)
            {
                printf("【成功】读取到新照片数据，Base64长度：%zu字节\n", strlen(photo_b64_buf));

                // 有新照片，读取最新的GPS位置数据
                if (gps_read_from_file(&gps_lat, &gps_lon) == 0)
                {
                    printf("【成功】读取到最新GPS数据：纬度=%.6f，经度=%.6f\n", gps_lat, gps_lon);
                    have_data = 1;
                }
                else
                {
                    printf("【失败】未读取到有效GPS数据，跳过本次上报\n");
                }
            }
            else
            {
                printf("【无更新】未检测到新的照片数据，跳过本次上报\n");
            }
        }

        // 【核心传输】有数据则上报到OneNET平台
        if (have_data)
        {
            if (onenet_upload_data(ec20_serial_fd, gps_lat, gps_lon, photo_b64_buf) == 0)
            {
                printf("【成功】数据上报OneNET平台完成\n");
                upload_fail_count = 0; // 上报成功，清空失败计数
            }
            else
            {
                printf("【失败】数据上报OneNET平台失败\n");
                upload_fail_count++;
                // 异常重连：连续3次上报失败，先清理旧连接再重新初始化（修复核心）
                if (upload_fail_count >= 3)
                {
                    printf("【警告】连续3次上报失败，开始执行重连流程\n");
                    // 步骤1：断开旧的MQTT连接（关键！先清理再重建）
                    ec20_mqtt_disconnect(ec20_serial_fd);
                    // 步骤2：去激活旧的PDP上下文（关键！避免重复激活冲突）
                    ec20_deinit_4g_network(ec20_serial_fd);
                    // 步骤3：重新初始化4G网络
                    if (ec20_init_4g_network(ec20_serial_fd) != 0) {
                        printf("【重连失败】4G网络重新初始化失败\n");
                    } else {
                        printf("【重连成功】4G网络重新初始化完成\n");
                        // 步骤4：重新连接OneNET MQTT
                        if (ec20_mqtt_connect_onenet(ec20_serial_fd) != 0) {
                            printf("【重连失败】OneNET MQTT重新连接失败\n");
                        } else {
                            printf("【重连成功】OneNET MQTT重新连接完成\n");
                        }
                    }
                    upload_fail_count = 0;
                }
            }
        }

        // 检测间隔等待
        sleep(UPLOAD_CHECK_INTERVAL);
    }

    printf("==================== EC20 上报线程安全退出 ====================\n");
    return NULL;
}

/**
 * @brief EC20资源释放
 *
 * 设置退出标志通知线程退出，断开MQTT连接，去激活4G网络，关闭串口。
 * 可安全重复调用（第二次调用将检测到未初始化状态并直接返回）。
 */
void ec20_deinit(void)
{
    if (ec20_serial_fd < 0)
    {
        printf("【警告】EC20模块未初始化，无需释放资源\n");
        return;
    }

    printf("==================== EC20 模块开始释放资源 ====================\n");

    // 设置退出标志，通知线程安全退出
    ec20_exit_flag = 1;

    // 步骤1：断开MQTT连接
    printf("【释放】断开OneNET MQTT连接...\n");
    ec20_mqtt_disconnect(ec20_serial_fd);

    // 步骤2：去激活4G网络
    printf("【释放】去激活4G网络（PDP上下文）...\n");
    ec20_deinit_4g_network(ec20_serial_fd);

    // 步骤3：关闭串口
    printf("【释放】关闭EC20串口...\n");
    serial_close(ec20_serial_fd);
    ec20_serial_fd = -1;

    // 重置标志
    ec20_exit_flag = 0;
    ec20_trigger_flag = 0;
    upload_fail_count = 0;

    printf("==================== EC20 模块资源释放完成 ====================\n");
}

/**
 * @brief 强制触发一次数据上报
 *
 * 当外部程序发现目标时调用，将数据写入共享缓冲区并设置触发标志。
 * 主循环线程在下次循环检测到标志后，执行实际上报（串口AT指令发送）。
 * 线程安全，使用互斥锁保护共享缓冲区。
 *
 * @param lat 纬度
 * @param lon 经度
 * @param photo_b64 照片Base64编码字符串
 * @return 0 on success, -1 on failure
 */
int ec20_trigger_upload(float lat, float lon, const char *photo_b64)
{
    if (ec20_serial_fd < 0)
    {
        printf("【错误】EC20模块未初始化，无法触发上报\n");
        return -1;
    }
    if (photo_b64 == NULL)
    {
        printf("【错误】照片数据为空，无法触发上报\n");
        return -1;
    }

    pthread_mutex_lock(&ec20_mutex);
    trigger_lat = lat;
    trigger_lon = lon;
    strncpy(trigger_photo_b64, photo_b64, PHOTO_B64_MAX_LEN - 1);
    trigger_photo_b64[PHOTO_B64_MAX_LEN - 1] = '\0';
    ec20_trigger_flag = 1;
    pthread_mutex_unlock(&ec20_mutex);

    printf("【触发】强制上报请求已提交，等待线程执行（lat=%.6f, lon=%.6f, photo_len=%zu）\n",
           lat, lon, strlen(photo_b64));
    return 0;
}

/************************* 【核心适配】文件读取函数（完全匹配你的方案，无需修改） *************************/
int gps_read_from_file(float *out_latitude, float *out_longitude)
{
    // 校验文件是否存在
    struct stat file_stat;
    if (stat(GPS_FILE_PATH, &file_stat) != 0)
    {
        return -1;
    }

    // 打开文件读取
    FILE *fp = fopen(GPS_FILE_PATH, "r");
    if (fp == NULL)
    {
        return -1;
    }

    // 读取数据：纬度,经度,时间戳
    float lat, lon;
    long timestamp;
    int read_ret = fscanf(fp, "%f,%f,%ld", &lat, &lon, &timestamp);
    fclose(fp);

    // 校验：读取成功 && 是新数据 && 数据合法
    if (read_ret != 3 || timestamp <= last_gps_timestamp || lat == 0 || lon == 0)
    {
        return -1;
    }

    // 输出有效数据，更新时间戳
    *out_latitude = lat;
    *out_longitude = lon;
    last_gps_timestamp = timestamp;

    return 0;
}

int photo_read_from_file(char *out_b64_buf, int max_buf_len)
{
    // 校验文件是否存在
    struct stat file_stat;
    if (stat(PHOTO_FILE_PATH, &file_stat) != 0)
    {
        return -1;
    }

    // 打开文件读取
    FILE *fp = fopen(PHOTO_FILE_PATH, "r");
    if (fp == NULL)
    {
        return -1;
    }

    // 读取数据：Base64字符串,时间戳（限制长度，防止缓冲区溢出）
    long timestamp;
    char format_str[32] = {0};
    snprintf(format_str, sizeof(format_str), "%%%d[^,],%%ld", max_buf_len - 1);
    int read_ret = fscanf(fp, format_str, out_b64_buf, &timestamp);
    fclose(fp);

    // 校验：读取成功 && 是新数据 && 数据合法
    if (read_ret != 2 || timestamp <= last_photo_timestamp || strlen(out_b64_buf) < 10)
    {
        return -1;
    }

    // 更新时间戳
    last_photo_timestamp = timestamp;

    return 0;
}

/************************* 串口底层操作函数（传输基础，无需修改） *************************/
int serial_open(const char *port, speed_t baud_rate)
{
    int fd = open(port, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd < 0) return -1;

    // 配置串口参数：8N1，无硬件流控
    struct termios options;
    tcgetattr(fd, &options);
    options.c_cflag |= (CLOCAL | CREAD);
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;         // 8位数据位
    options.c_cflag &= ~PARENB;     // 无校验位
    options.c_cflag &= ~CSTOPB;     // 1位停止位
    options.c_cflag &= ~CRTSCTS;    // 关闭硬件流控
    options.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    options.c_oflag &= ~OPOST;
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);

    // 设置波特率
    cfsetispeed(&options, baud_rate);
    cfsetospeed(&options, baud_rate);
    tcflush(fd, TCIOFLUSH);
    tcsetattr(fd, TCSANOW, &options);

    return fd;
}

int serial_send(int serial_fd, const char *at_cmd)
{
    if (serial_fd < 0 || at_cmd == NULL) return -1;
    int len = strlen(at_cmd);
    int ret = write(serial_fd, at_cmd, len);
    return ret == len ? 0 : -1;
}

int serial_recv(int serial_fd, char *recv_buf, int max_len, int timeout_ms)
{
    if (serial_fd < 0 || recv_buf == NULL || max_len <= 0) return -1;
    memset(recv_buf, 0, max_len);
    int total_len = 0;
    char buf[1] = {0};

    // 循环读取，直到超时或缓冲区满
    while (timeout_ms > 0 && total_len < max_len - 1)
    {
        int ret = read(serial_fd, buf, 1);
        if (ret > 0)
        {
            recv_buf[total_len++] = buf[0];
        }
        else
        {
            usleep(1000); // 1ms等待
            timeout_ms--;
        }
    }
    recv_buf[total_len] = '\0';
    return total_len;
}

int serial_close(int serial_fd)
{
    if (serial_fd < 0) return -1;
    tcflush(serial_fd, TCIOFLUSH);
    close(serial_fd);
    return 0;
}

/************************* EC20 4G+MQTT传输核心函数（新增/修改标注） *************************/
int ec20_check_at(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);
    if (serial_send(serial_fd, "AT\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    return strstr(recv_buf, "OK") != NULL ? 0 : -1;
}

int ec20_get_csq(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);
    if (serial_send(serial_fd, "AT+CSQ\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    
    char *csq_ptr = strstr(recv_buf, "+CSQ: ");
    if (csq_ptr == NULL) return -1;
    int csq = atoi(csq_ptr + 6);
    return csq;
}

int ec20_init_4g_network(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);

    // 1. 配置PDP上下文（移动CMNET，联通改3GNET，电信改CTNET）
    if (serial_send(serial_fd, "AT+CGDCONT=1,\"IP\",\"CTNET\"\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 1000);
    if (strstr(recv_buf, "OK") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 2. 激活PDP上下文
    if (serial_send(serial_fd, "AT+CGACT=1,1\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 3000);
    if (strstr(recv_buf, "OK") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 3. 验证PDP激活状态
    if (serial_send(serial_fd, "AT+CGACT?\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 1000);
    return strstr(recv_buf, "+CGACT: 1,1") != NULL ? 0 : -1;
}

// 新增：4G网络反初始化（去激活PDP上下文）
int ec20_deinit_4g_network(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);

    // 去激活PDP上下文（1是上下文ID，与初始化对应）
    serial_send(serial_fd, "AT+CGACT=0,1\r\n");
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 3000);
    if (strstr(recv_buf, "OK") == NULL) {
        printf("【警告】PDP上下文去激活失败，强制继续\n");
    }
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 验证去激活结果
    serial_send(serial_fd, "AT+CGACT?\r\n");
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 1000);
    return strstr(recv_buf, "+CGACT: 1,0") != NULL ? 0 : -1;
}

int ec20_mqtt_config(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);

    // 1. 配置MQTT协议版本：3.1.1
    if (serial_send(serial_fd, "AT+QMTCFG=\"version\",0,4\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    if (strstr(recv_buf, "OK") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 2. 配置清除会话
    if (serial_send(serial_fd, "AT+QMTCFG=\"session\",0,1\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    if (strstr(recv_buf, "OK") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 3. 配置保活时间60秒
    if (serial_send(serial_fd, "AT+QMTCFG=\"keepalive\",0,60\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    if (strstr(recv_buf, "OK") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 4. 绑定PDP上下文（保险配置，与4G激活的上下文对应）
    if (serial_send(serial_fd, "AT+QMTCFG=\"pdpcid\",0,1\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 500);
    if (strstr(recv_buf, "OK") == NULL) return -1;

    return 0;
}

int ec20_mqtt_connect_onenet(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);
    char at_cmd[512] = {0};

    // 1. 打开MQTT客户端网络连接（OneNET服务器地址+端口）
    if (serial_send(serial_fd, "AT+QMTOPEN=0,\"mqtts.heclouds.com\",1883\r\n") != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 5000);
    if (strstr(recv_buf, "+QMTOPEN: 0,0") == NULL) return -1;
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 2. MQTT认证连接OneNET（核心：ClientID=设备名，用户名=产品ID，密码=设备秘钥）
    snprintf(at_cmd, sizeof(at_cmd), "AT+QMTCONN=0,\"%s\",\"%s\",\"%s\"\r\n",
             ONENET_DEVICE_NAME, ONENET_PRODUCT_ID, ONENET_DEVICE_KEY);
    if (serial_send(serial_fd, at_cmd) != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 5000);
    
    // 验证连接结果：+QMTCONN: 0,0,0 表示连接成功
    return strstr(recv_buf, "+QMTCONN: 0,0,0") != NULL ? 0 : -1;
}

// 新增：MQTT断开连接（先断开MQTT会话，再关闭网络通道）
int ec20_mqtt_disconnect(int serial_fd)
{
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    tcflush(serial_fd, TCIOFLUSH);

    // 步骤1：断开MQTT客户端连接
    serial_send(serial_fd, "AT+QMTDISC=0\r\n");
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 3000);
    if (strstr(recv_buf, "+QMTDISC: 0,0") == NULL) {
        printf("【警告】MQTT断开会话失败，强制继续\n");
    }
    memset(recv_buf, 0, SERIAL_BUF_SIZE);

    // 步骤2：关闭MQTT网络通道
    serial_send(serial_fd, "AT+QMTCLOSE=0\r\n");
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 2000);
    if (strstr(recv_buf, "+QMTCLOSE: 0,0") == NULL) {
        printf("【警告】MQTT关闭网络通道失败，强制继续\n");
    }

    return 0;
}

int onenet_upload_data(int serial_fd, float latitude, float longitude, const char *photo_b64)
{
    if (serial_fd < 0 || photo_b64 == NULL) return -1;
    char recv_buf[SERIAL_BUF_SIZE] = {0};
    char payload_buf[PHOTO_B64_MAX_LEN + 512] = {0};
    char at_cmd[512] = {0};
    char topic_buf[256] = {0};

    // 1. 组装OneNET标准上报主题
    snprintf(topic_buf, sizeof(topic_buf), "$sys/%s/%s/thing/property/post",
             ONENET_PRODUCT_ID, ONENET_DEVICE_NAME);

    // 2. 组装OneNET要求的OneJson格式数据
    snprintf(payload_buf, sizeof(payload_buf),
             "{\"id\":%ld,\"params\":{\"latitude\":{\"value\":%.6f},\"longitude\":{\"value\":%.6f},\"photo\":{\"value\":\"%s\"}}}",
             (long)time(NULL), latitude, longitude, photo_b64);
    int payload_len = strlen(payload_buf);

    // 3. 清空串口缓冲区，发送MQTT发布命令（数据模式，QoS=1，确保送达）
    tcflush(serial_fd, TCIOFLUSH);
    snprintf(at_cmd, sizeof(at_cmd), "AT+QMTPUBEX=0,1,1,0,\"%s\",%d\r\n", topic_buf, payload_len);
    if (serial_send(serial_fd, at_cmd) != 0) return -1;
    usleep(200000); // 200ms等待模块响应

    // 4. 发送实际上报数据
    if (serial_send(serial_fd, payload_buf) != 0) return -1;
    serial_recv(serial_fd, recv_buf, SERIAL_BUF_SIZE, 3000);

    // 验证上报结果：+QMTPUBEX: 0,1,0 表示上报成功
    return strstr(recv_buf, "+QMTPUBEX: 0,1,0") != NULL ? 0 : -1;
}
