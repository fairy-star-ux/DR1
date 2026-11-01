# ============================================================================
# 搜救小船项目 Makefile —— 一键编译
# ============================================================================
# 使用说明:
#   make        — 编译整个项目，生成可执行文件
#   make clean  — 清理编译产物
#   make run    — 编译并运行（需要root权限用于实时线程）
#   make help   — 显示帮助信息
# ============================================================================

# 项目名
TARGET    := boat_main

# 编译器
CC        := gcc

# 编译选项
CFLAGS    := -Wall -Wextra -pthread -I.
CFLAGS    += -O2 -std=c99 -D_GNU_SOURCE
# 启用优化级别O2，线程安全; 使用C99标准
# -D_GNU_SOURCE 启用 usleep()、CRTSCTS 等 POSIX/GNU 扩展

# 调试模式: make DEBUG=1 启用 -g 调试符号
ifeq ($(DEBUG),1)
    CFLAGS  += -g -O0
    LDFLAGS += -g
else
    CFLAGS  += -DNDEBUG
endif

# 链接选项
LDFLAGS   := -pthread

# 源文件
SRCS      := main.c motor.c radar.c servo.c visual_servo.c gps.c ec20.c gpio.c switch.c

# 头文件 (用于依赖检测)
HEADERS   := boat_common.h motor.h radar.h servo.h visual_servo.h gps.h ec20.h gpio.h switch.h

# 目标文件
OBJS      := $(SRCS:.c=.o)

# ============================================================================
# 默认目标
# ============================================================================
.PHONY: all clean run motor_test help

all: $(TARGET)

motor_test: motor_test.c boat_common.h
	@$(CC) $(CFLAGS) motor_test.c -o $@
	@echo "编译成功: ./motor_test"

# ============================================================================
# 链接目标
# ============================================================================
$(TARGET): $(OBJS)
	@echo "  LD    $@"
	@$(CC) $(OBJS) $(LDFLAGS) -o $@
	@echo "============================================"
	@echo "  编译成功: ./$@"
	@echo "============================================"

# ============================================================================
# 编译规则
# ============================================================================
# main.c 依赖所有头文件
main.o: main.c $(HEADERS)
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# motor.c
motor.o: motor.c motor.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# radar.c
radar.o: radar.c radar.h servo.h gpio.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# servo.c
servo.o: servo.c servo.h gpio.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# gps.c (新增: GPS定位模块)
gps.o: gps.c gps.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# ec20.c (新增: 4G通信模块)
ec20.o: ec20.c ec20.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# visual_servo.c (新增: 视觉舵机控制模块，由C程序独占)
visual_servo.o: visual_servo.c visual_servo.h gpio.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# switch.c (开关检测模块)
switch.o: switch.c switch.h gpio.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# gpio.c
gpio.o: gpio.c gpio.h boat_common.h
	@echo "  CC    $@"
	@$(CC) $(CFLAGS) -c $< -o $@

# ============================================================================
# 清理
# ============================================================================
clean:
	@echo "  CLEAN"
	@rm -f $(OBJS) $(TARGET)

# ============================================================================
# 编译并运行
# ============================================================================
run: $(TARGET)
	@echo "============================================"
	@echo "  启动 $(TARGET)..."
	@echo "  (使用 sudo 获取实时线程调度权限)"
	@echo "============================================"
	sudo ./$(TARGET)

# ============================================================================
# 帮助信息
# ============================================================================
help:
	@echo "============================================"
	@echo "  搜救小船项目 —— 编译脚本"
	@echo "============================================"
	@echo ""
	@echo "  编译目标:"
	@echo "    make          编译项目，生成 ./$(TARGET)"
	@echo "    make DEBUG=1  编译调试版本（带调试符号）"
	@echo "    make clean    清理编译产物"
	@echo "    make run      编译并运行（需要root权限）"
	@echo "    make help     显示本帮助"
	@echo ""
	@echo "  编译选项:"
	@echo "    CC       = $(CC)"
	@echo "    CFLAGS   = $(CFLAGS)"
	@echo "    LDFLAGS  = $(LDFLAGS)"
	@echo ""
	@echo "  源文件:"
	@echo "    $(SRCS)"
	@echo ""
	@echo "  串口分配:"
	@echo "    /dev/ttyUSB0  -> 电机驱动板"
	@echo "    /dev/ttyAMA2  -> GPS模块"
	@echo "    /dev/ttyUSB2  -> EC20 4G模块"
	@echo ""
	@echo "  GPIO分配:"
	@echo "    GPIO 510  -> 雷达舵机 (扫描用，C程序控制)"
	@echo "    GPIO 445  -> 视觉舵机 (定点用，C程序控制)"
	@echo "    GPIO 450  -> 超声波TRIG"
	@echo "    GPIO 485  -> 超声波ECHO"
	@echo "    GPIO 446  -> 电源开关"
	@echo ""
	@echo "  线程优先级 (SCHED_FIFO):"
	@echo "    motor_control=90  radar=80  servo=75"
	@echo "    vision_coord=65   gps=50   ec20=40"
	@echo ""
	@echo "  vision.py: 以 nice=19 最低CPU优先级运行，只做纯视觉计算"
	@echo "             不再控制舵机，避免GPIO抢占和CPU抢占"
	@echo ""
