/**
 * ============================================================================
 * 文件: ec20.h
 * 描述: 4G通信模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明4G通信接口
 * ============================================================================
 */

#ifndef __EC20_H__
#define __EC20_H__

#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief EC20模块初始化
 *
 * 执行完整的初始化序列：打开串口 -> AT检查 -> 信号检测 -> 4G网络激活 -> MQTT配置 -> OneNET连接
 *
 * @return 0 on success, -1 on failure
 */
int ec20_init(void);

/**
 * @brief EC20主循环线程函数
 *
 * 供pthread_create调用。循环检测新数据并上报，支持文件检测和强制触发两种方式。
 * 检查ec20_exit_flag后安全退出。
 *
 * @param arg 线程参数，可传入NULL
 * @return NULL
 */
void *ec20_thread_func(void *arg);

/**
 * @brief EC20资源释放
 *
 * 设置退出标志，断开MQTT连接，去激活4G网络，关闭串口。
 * 可安全重复调用。
 */
void ec20_deinit(void);

/**
 * @brief 强制触发一次数据上报
 *
 * 当外部程序发现目标时调用，数据将写入共享缓冲区，由主循环线程执行实际上报。
 * 不依赖文件检测机制，可立即触发上报（受限于线程检测间隔）。
 * 线程安全，使用内部互斥锁保护共享缓冲区。
 *
 * @param lat 纬度
 * @param lon 经度
 * @param photo_b64 照片Base64编码字符串（以'\0'结尾）
 * @return 0 on success, -1 on failure（模块未初始化或参数非法）
 */
int ec20_trigger_upload(float lat, float lon, const char *photo_b64);

#ifdef __cplusplus
}
#endif

#endif /* __EC20_H__ */
