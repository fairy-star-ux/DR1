> 历史飞腾派平台资料；不代表 DR1M90 当前部署。当前说明见 ../../docs/。

# 基于飞腾派的智能搜救小船系统

## 项目概述

本项目基于**飞腾派（Phytium Pi）D2000/8** ARM64开发板，设计并实现了一套智能搜救小船控制系统。系统通过超声波雷达+YOLOv8视觉识别实现自主避障与人像检测，通过GPS+4G模块实现位置实时上报，适用于水域搜救等应急场景。

## 核心特性

- **多线程实时调度**：6线程SCHED_FIFO调度，优先级分层设计
- **统一硬件控制**：C程序独占所有硬件，vision.py只做纯视觉计算
- **状态机避障决策**：FORWARD→AVOIDING→FOUND_TARGET三状态机
- **processing超时保护**：视觉工作中重置超时计数，避免误判
- **开关启停控制**：拨动开关控制整个系统的启停，支持循环启动

## 系统架构

```
+-----------------------------------------------------+
|                    主控程序 (main.c)                 |
|  6线程并行: motor(90) > radar(80) > servo(75)       |
|            > vision_coord(65) > gps(50) > ec20(40)  |
+-----------------------------------------------------+
|  motor  |  radar  |  servo  | visual_servo | switch |
| ttyUSB0 | GPIO    | GPIO510 | GPIO445      | GPIO446|
+-----------------------------------------------------+
|  gps    |  ec20   |  vision.py (YOLOv8)               |
| ttyAMA2 | ttyUSB2 |  nice=19 纯视觉服务              |
+-----------------------------------------------------+
```

## 硬件平台

| 组件 | 型号/规格 | 接口 |
|------|-----------|------|
| 主控板 | 飞腾派 D2000/8 | ARM64 8核2.3GHz |
| 电机驱动 | 双路PWM驱动板 | /dev/ttyUSB0 115200 |
| GPS模块 | NMEA协议GPS | /dev/ttyAMA2 9600 |
| 4G模块 | Quectel EC20-CNV | /dev/ttyUSB2 115200 |
| 超声波 | HC-SR04 | GPIO450/485 |
| 雷达舵机 | SG90 | GPIO510 |
| 视觉舵机 | SG90 | GPIO445 |
| 摄像头 | USB摄像头 | /dev/video0 |
| 开关 | 拨动开关 | GPIO446 |

## 软件平台

| 项目 | 版本 |
|------|------|
| 操作系统 | 飞腾Linux (ARM64) |
| 编译器 | GCC (aarch64-linux-gnu) |
| C标准 | C99 |
| 线程库 | POSIX Threads |
| Python | 3.8+ |
| OpenCV | 4.x |
| YOLO | ultralytics 8.x |

## 快速开始

在新板上指定 USB 串口时，可使用环境变量覆盖默认设备名：

```bash
export GPS_SERIAL_PORT=/dev/ttyUSB1
export MOTOR_SERIAL_PORT=/dev/ttyUSB0
```

### 1. 编译

```bash
make
```

### 2. 运行

```bash
sudo ./boat_main
```

### 3. 操作

- 拨开关到 **ON** → 系统启动运行
- 拨开关到 **OFF** → 系统关闭
- **Ctrl+C** → 程序完全退出

## 工程文件说明

| 文件 | 说明 |
|------|------|
| `main.c` | 主程序（开关控制版） |
| `boat_common.h` | 公共头文件（配置宏、标准头文件） |
| `motor.h/c` | 电机控制模块 |
| `radar.h/c` | 超声波雷达模块 |
| `servo.h/c` | 雷达舵机扫描模块 |
| `visual_servo.h/c` | 视觉舵机定点模块 |
| `gps.h/c` | GPS定位模块 |
| `ec20.h/c` | 4G通信OneNET上报模块 |
| `switch.h/c` | 电源开关控制模块 |
| `gpio.h/c` | GPIO底层操作模块 |
| `vision.py` | YOLOv8视觉识别模块 |
| `Makefile` | 一键编译脚本 |

## 文档索引

| 文档 | 说明 |
|------|------|
| `软件平台说明.md` | 软硬件工作平台详细说明 |
| `执行测试步骤.md` | 可执行文件运行与测试步骤 |
| `搜救小船技术文档.docx` | 完整技术报告（Word） |
| `功能需求列表.xlsx` | 功能需求表格 |
| `功能测试表.xlsx` | 功能测试表格 |

## 依赖安装

```bash
# Python依赖
pip3 install opencv-python ultralytics psutil numpy

# YOLO模型（自动下载或手动放置）
wget https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt
```

## 许可证

本项目为第十届全国大学生集成电路创新创业大赛参赛作品。

## 联系方式

- 大赛官网: https://www.univ.ciciec.com/
- 飞腾派社区: https://www.phytium.com.cn/
