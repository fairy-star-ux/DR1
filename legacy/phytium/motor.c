/**
 * ============================================================================
 * 文件: motor.c
 * 描述: 电机控制模块——串口控制双路PWM电机驱动板
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现串口控制双路PWM电机驱动
 * ============================================================================
 */

#include"motor.h"
/************************* 配置项 *************************/
// 飞腾派USB转TTL对应的串口设备名
#define UART_DEV_DEFAULT "/dev/ttyUSB0"
// 驱动板固定波特率115200
#define UART_BAUDRATE   B115200
// 差速比例：0.0~1.0，值越小转弯越急，越大越平缓（推荐0.5~0.7）
#define DIFF_RATIO      0.6f
// 平滑过渡步长：每次PWM变化的幅度，越小越平滑但响应越慢（推荐50~200）
#define SMOOTH_STEP     100
// 平滑过渡延时：每次变化后的等待时间（微秒），越小过渡越快（推荐10000~30000）
#define SMOOTH_DELAY_US 20000
/**********************************************************/
// 全局串口文件描述符
 static int uart_fd = -1;
// 记录当前各电机的PWM值，用于平滑过渡
static int16_t g_current_m1 = 0, g_current_m2 = 0, g_current_m3 = 0, g_current_m4 = 0;
/**
 * @brief  串口初始化（115200 8N1 无流控）
 * @return 成功返回0，失败返回-1
 */
int uart_init(void)
{
    const char *uart_dev = getenv("MOTOR_SERIAL_PORT");
    if (!uart_dev || !*uart_dev) uart_dev = UART_DEV_DEFAULT;
    uart_fd = open(uart_dev, O_RDWR | O_NOCTTY | O_NDELAY);
    if (uart_fd < 0) {
        perror("❌ 打开串口失败，请检查设备名和权限");
        return -1;
    }
    struct termios options;
    if (tcgetattr(uart_fd, &options) != 0) {
        perror("❌ 获取串口配置失败");
        close(uart_fd);
        return -1;
    }
    cfsetispeed(&options, UART_BAUDRATE);
    cfsetospeed(&options, UART_BAUDRATE);
    options.c_cflag |= (CLOCAL | CREAD);
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~PARENB;
    options.c_iflag &= ~INPCK;
    options.c_cflag &= ~CRTSCTS;
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_oflag &= ~OPOST;
    options.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tcflush(uart_fd, TCIFLUSH);
    if (tcsetattr(uart_fd, TCSANOW, &options) != 0) {
        perror("❌ 设置串口配置失败");
        close(uart_fd);
        return -1;
    }
    printf("✅ 串口初始化成功，设备：%s，波特率：115200\n", uart_dev);
    return 0;
}
/**
 * @brief  发送串口指令给驱动板
 * @param  cmd 要发送的指令字符串
 * @return 成功返回0，失败返回-1
 */
int uart_send_cmd(const char *cmd)
{
    if (uart_fd < 0) {
        printf("❌ 串口未初始化\n");
        return -1;
    }
    int len = strlen(cmd);
    int ret = write(uart_fd, cmd, len);
    if (ret != len) {
        perror("❌ 指令发送失败");
        return -1;
    }
    usleep(10000);
    return 0;
}
/**
 * @brief  配置电机参数（初始化必须执行一次）
 * @return 成功返回0，失败返回-1
 */
int motor_init(void)
{
    printf("▶️  开始初始化电机参数\n");
    if (uart_send_cmd("$mtype:4#\r\n") != 0) return -1;
    sleep(1);
    if (uart_send_cmd("$deadzone:800#\r\n") != 0) return -1;
    sleep(1);
    printf("✅ 电机参数初始化完成\n");
    return 0;
}
/**
 * @brief  平滑设置4个电机的PWM值（核心平滑函数）
 * @param  target_m1 左电机目标PWM
 * @param  target_m2 右电机目标PWM
 * @param  target_m3 备用电机目标PWM
 * @param  target_m4 备用电机目标PWM
 */
void motor_smooth_set_pwm(int16_t target_m1, int16_t target_m2, int16_t target_m3, int16_t target_m4)
{
    // ✅ 直接发送目标PWM，跳过平滑过渡（多线程下usleep会被严重延迟，导致电机始终爬不上去）
    char cmd[64] = {0};
    sprintf(cmd, "$pwm:%d,%d,%d,%d#\r\n", target_m1, target_m2, target_m3, target_m4);
    uart_send_cmd(cmd);
    
    g_current_m1 = target_m1;
    g_current_m2 = target_m2;
    g_current_m3 = target_m3;
    g_current_m4 = target_m4;
}
/**
 * @brief  电机前进（带平滑加速）
 * @param  speed 速度，范围0~3600
 */
void motor_forward(uint16_t speed)
{
    motor_smooth_set_pwm(speed, speed, 0, 0);
}
/**
 * @brief  电机后退（带平滑减速）
 * @param  speed 速度，范围0~3600
 */
void motor_backward(uint16_t speed)
{
    motor_smooth_set_pwm(-speed, -speed, 0, 0);
}
/**
 * @brief  差速平滑左转（左电机慢，右电机快，保持前进趋势）
 * @param  speed 基准速度，范围0~3600
 */
void motor_left(uint16_t speed)
{
    int16_t left_speed = (int16_t)(speed * DIFF_RATIO);
    motor_smooth_set_pwm(left_speed, speed, 0, 0);
}
/**
 * @brief  差速平滑右转（右电机慢，左电机快，保持前进趋势）
 * @param  speed 基准速度，范围0~3600
 */
void motor_right(uint16_t speed)
{
    int16_t right_speed = (int16_t)(speed * DIFF_RATIO);
    motor_smooth_set_pwm(speed, right_speed, 0, 0);
}
/**
 * @brief  停止所有电机（带平滑减速）
 */
void motor_stop(void)
{
    motor_smooth_set_pwm(0, 0, 0, 0);
}
/**
 * @brief  关闭串口
 */
void uart_close(void)
{
    if (uart_fd >= 0) {
        close(uart_fd);
        uart_fd = -1;
        printf("✅ 串口已关闭\n");
    }
}
