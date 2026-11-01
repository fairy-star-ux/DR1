# 寄存器与 API

## FPGA

实现：`fpga/td/uisrc/01_rtl/boat/servo_control_gp0_axi.v`。
这是连接 PS Master GP0 的 AXI 从设备，不要把历史 `servo_control_axil.v` 的接口当作当前实现。

| 偏移 | 物理地址 | 含义 |
|---|---|---|
| 0x00 | 0x80010000 | 云台水平，0–180° |
| 0x04 | 0x80010004 | 云台俯仰，0–180° |
| 0x08 | 0x80010008 | 超声波舵机指定角度，0–180° |
| 0x0C | 0x8001000C | bit0=PWM 使能，bit1=往返扫描 |

角度通过 32 位小端 MMIO 写入；Web 用 `/dev/mem` 映射 4 KiB。
GP0 的 `master_gp0_axi_aclk` 已接 `p2f_clk0`；PWM 参数 `CLK_HZ=49_995_000`；外部 LED/PLL 时钟为 100 MHz。
舵机 PWM 为 50 Hz，当前 0–180°对应约 0.5–2.5 ms，机构实际行程应现场标定。
`SELF_TEST=0` 为 Linux 控制；改为 1 仅作三舵机扫描接线测试，必须重新编译位流。
上电云台目标为 90°；超声波舵机禁用扫描。寄存器不提供机械位置反馈。

## HTTP

服务默认 `http://BOARD_IP:8080`，请求/响应 JSON。

| 路径 | 方法 | 请求 |
|---|---|---|
| `/` | GET | 控制页面 |
| `/api/status` | GET | 电机、GPS、FPGA 能力、最后照片 |
| `/api/photos` | GET | 已保存照片列表 |
| `/photos/文件名.jpg` | GET | 照片 |
| `/api/motor` | POST | `{"pwm":[左,0,右,0]}` |
| `/api/ptz` | POST | `{"pan":90,"tilt":90}` |
| `/api/ultrasonic` | POST | `{"angle":90,"enable":true,"sweep":false}` |
| `/api/capture` | POST | 无需请求正文 |

电机采用 `$pwm:a,b,c,d#`，两轮接通道 1 和 3；停止值全 0。
程序限制 PWM 在 -10000～10000，网页速度滑块是 0～3600；范围不是电机额定转速或闭环速度。
超声波 `enable=false` 停止 PWM，可能失去保持力；“停止扫描但保持角度”用 `enable=true,sweep=false`。
云台两个角度都需为整数且在 0～180°。

状态里的 `servo_control=true` 来自配置存在，不能作为位流识别探针。
在确认匹配的 `BOOT.bin` 已启动前，不要直接读写 GP0 地址试探设备是否存在。
