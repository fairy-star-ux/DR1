/**
 * ============================================================================
 * 文件: gps.h
 * 描述: GPS定位模块头文件
 * 作者: 集创赛参赛队
 * 版本: v1.0
 * 日期: 2025-05
 * 平台: 飞腾派 D2000/8 (ARM64 Linux)
 * ============================================================================
 * 修改履历:
 *   v1.0 (2025-05) - 初始版本，声明GPS定位接口
 * ============================================================================
 */

#ifndef __GPS_H__
#define __GPS_H__

#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief GPS模块初始化（打开串口）
 * @return 0成功，-1失败
 */
int gps_init(void);

/**
 * @brief GPS主循环线程函数（供pthread_create调用）
 * @param arg 线程参数（可传NULL）
 * @return 线程返回值（NULL）
 */
void *gps_thread_func(void *arg);

/**
 * @brief GPS资源释放（关闭串口，设置退出标志）
 */
void gps_deinit(void);

/**
 * @brief 获取当前最新GPS坐标（线程安全，供其他线程读取）
 * @param lat      输出纬度（浮点数）
 * @param lon      输出经度（浮点数）
 * @param timestamp 输出时间戳（秒级Unix时间）
 * @return 0成功且数据有效，-1失败或无有效数据
 */
int gps_get_position(float *lat, float *lon, long *timestamp);

#ifdef __cplusplus
}
#endif

#endif /* __GPS_H__ */
