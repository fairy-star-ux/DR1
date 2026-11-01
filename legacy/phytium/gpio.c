/**
 * ============================================================================
 * 文件: gpio.c
 * 描述: GPIO底层操作——sysfs导出/方向/读写
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，实现sysfs导出、方向设置与读写操作
 * ============================================================================
 */

#include "gpio.h"
// 新增：GPIO合法性检查
static int gpio_is_valid(int pin) {
    // 限制GPIO引脚范围（根据飞腾派实际引脚定义调整）
    if (pin < 0 || pin > 1000) {
        fprintf(stderr, "【GPIO错误】引脚号非法：%d\n", pin);
        return 0;
    }
    return 1;
}
void gpio_export(int pin) {
    if (!gpio_is_valid(pin)) return; // 非法引脚直接返回
    
    char pin_str[6];
    int fd = open("/sys/class/gpio/export", O_WRONLY);
    if (fd < 0) {
        perror("gpio export failed");
        return; // 替换exit，避免程序直接退出导致资源泄漏
    }
    sprintf(pin_str, "%d", pin);
    write(fd, pin_str, strlen(pin_str));
    close(fd);
    usleep(100000); // 等待GPIO导出完成
}
void gpio_unexport(int pin) {
    if (!gpio_is_valid(pin)) return;
    
    char pin_str[6];
    int fd = open("/sys/class/gpio/unexport", O_WRONLY);
    if (fd < 0) {
        perror("gpio unexport failed");
        return;
    }
    sprintf(pin_str, "%d", pin);
    write(fd, pin_str, strlen(pin_str));
    close(fd);
}
void gpio_set_dir(int pin, const char *direction) {
    if (!gpio_is_valid(pin)) return;
    
    char path[64];
    sprintf(path, "/sys/class/gpio/gpio%d/direction", pin);
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("gpio set direction failed");
        return;
    }
    write(fd, direction, strlen(direction));
    close(fd);
}
// 新增：带防抖的GPIO电平设置
void gpio_set_value_safe(int pin, int value) {
    if (!gpio_is_valid(pin)) return;
    
    // 连续3次设置相同电平，避免瞬时干扰导致的电路误动作
    for (int i=0; i<3; i++) {
        char path[64];
        char val_str[2];
        sprintf(path, "/sys/class/gpio/gpio%d/value", pin);
        int fd = open(path, O_WRONLY);
        if (fd < 0) {
            perror("gpio set value failed");
            return;
        }
        sprintf(val_str, "%d", value);
        write(fd, val_str, strlen(val_str));
        close(fd);
        usleep(1000); // 间隔1ms防抖
    }
}
// 兼容原有接口，默认调用安全版本
void gpio_set_value(int pin, int value) {
    gpio_set_value_safe(pin, value);
}
// 新增：带超时的GPIO读取（避免死循环）
int gpio_read_value_timeout(int pin, int timeout_ms) {
    if (!gpio_is_valid(pin)) return -1;
    
    struct timeval start, now;
    gettimeofday(&start, NULL);
    
    char path[64];
    char val_str[2];
    sprintf(path, "/sys/class/gpio/gpio%d/value", pin);
    
    while (1) {
        int fd = open(path, O_RDONLY);
        if (fd < 0) {
            perror("gpio read value failed");
            return -1;
        }
        read(fd, val_str, sizeof(val_str));
        close(fd);
        
        // 检查超时
        gettimeofday(&now, NULL);
        long elapsed_ms = (now.tv_sec - start.tv_sec)*1000 + (now.tv_usec - start.tv_usec)/1000;
        if (elapsed_ms > timeout_ms) {
            fprintf(stderr, "【GPIO错误】读取引脚%d超时\n", pin);
            return -1;
        }
        
        // 连续2次读取值一致，返回结果
        int val1 = atoi(val_str);
        usleep(1000);
        fd = open(path, O_RDONLY);
        read(fd, val_str, sizeof(val_str));
        close(fd);
        int val2 = atoi(val_str);
        
        if (val1 == val2) {
            return val1;
        }
    }
}
// 兼容原有接口，默认超时100ms
int gpio_read_value(int pin) {
    return gpio_read_value_timeout(pin, 100);
}
// ... (原有内容保持不变) ...

// 新增：快速设置GPIO电平（跳过防抖循环）
void gpio_set_value_fast(int pin, int value) {
    if (!gpio_is_valid(pin)) return;
    
    char path[64];
    char val_str[2];
    sprintf(path, "/sys/class/gpio/gpio%d/value", pin);
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("gpio set value fast failed");
        return;
    }
    sprintf(val_str, "%d", value);
    write(fd, val_str, strlen(val_str));
    close(fd);
}