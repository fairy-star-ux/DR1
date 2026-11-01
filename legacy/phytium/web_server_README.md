> 历史飞腾派平台资料；不代表 DR1M90 当前部署。当前说明见 ../../docs/。

# Linux Web 控制服务

服务监听 `0.0.0.0:8080`，网页地址为 `http://板卡IP:8080/`。

当前可用功能：

- 通过 `/dev/ttyUSB0` 发送电机驱动板 `$pwm:a,b,c,d#`；
- 读取 GPS NMEA（默认 `/dev/ttyUSB1`，可用 `GPS_SERIAL_PORT` 覆盖）；
- 调用 V4L2 拍照程序保存到 `/var/lib/boat-web/photos`，并在网页展示；
- 查询 FPGA 能力状态。

当前 FPGA 位流只把舵机 PWM 接到了顶层引脚，没有 Linux 可写的 AXI/UART 寄存器，因此网页暂时不能改变云台角度或启停超声波扫描。网页会明确返回 409，而不会伪造成功。要实现这两项，需要下一版 FPGA/SoC 增加 Linux 可访问寄存器或控制 UART，再接入 `/api/ptz` 和 `/api/ultrasonic`。
