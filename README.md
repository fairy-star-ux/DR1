# DR1M90 Linux + FPGA 搜救小船

本作品面向水域应急救援中搜救效率低、人工风险大、复杂水域目标发现难等问题，设计了一套基于安路飞龙 DR1（MLK-F3P-DR1M90G）异构 SoC 的水上智能搜救系统。以下按实际实现记录功能与复现步骤。

基于米联客 MLK_F3P_CZ02_DR1 / 安路 DR1M90GEG400 的软硬件协同控制工程。
FPGA 输出三路舵机 PWM；Linux 提供 Web、电机串口、GPS、USB 摄像头实时预览、拍照和 WiFi。

## 当前实现

- 摄像头云台水平/俯仰角度设置；超声波舵机定角度、往返扫描和停止。
- 两个电机通过串口驱动板控制，使用协议通道 1 和 3；网页可调 PWM。
- GPS NMEA 接收和定位状态展示；摄像头实时预览和手动拍照，照片保存到 SD 根文件系统，可查看和清空。
- FPGA 通过 AXI GP0 寄存器接受 Linux 控制，基地址 `0x80010000`。
- FSBL 在 Linux 前加载 `BOOT.bin` 中的位流；重启后无需再次用 JTAG 下载。

4G/OneNET、YOLO/NPU、自主避障和超声波测距不在当前版本实现范围。

## 目录

```text
fpga/
  td/                    TD 主工程 fpga_prj.al、RTL、IP 和引脚约束
  fd/                    FD BSP/平台配置及 FSBL 源文件
linux/
  app/                   以实际部署版本为基线的 Web 与 V4L2 拍照源码
  tools/                 串口、电机、摄像头诊断程序（需手动运行）
  buildroot/             已脱敏的配置快照、rootfs overlay、服务启动脚本
  kernel/                内核配置和实际设备树快照
  drivers/aic8800/        用于已验证系统的第三方 WiFi 驱动源码
  boot/                  SD ext4 启动命令、U-Boot 配置和设备树
scripts/                 配置、编译、打包、SD 安装、检查和测试
docs/                    当前 DR1M90 平台说明、接线、复现和测试步骤
manifests/               源文件来源、已验证产物的 SHA-256 和验证报告
third_party/             第三方版权/许可证原文
artifacts/               本地已验证镜像、模块、固件；Git 忽略
```

## 阅读顺序

1. [软件平台说明](docs/软件平台说明.md)：软硬件分工、版本、串口、当前功能边界。
2. [硬件接线](docs/硬件接线.md)：FPGA 封装管脚与供电。
3. [复现与构建](docs/复现与构建.md)：官方 SDK、TD/FD、Linux、BOOT 和 SD 部署。
4. [执行测试步骤](docs/执行测试步骤.md)：逐项验证，含停止/回滚步骤。
5. [寄存器与 API](docs/寄存器与API.md)、[验证记录](docs/验证记录.md)。
6. [GitHub 发布说明](docs/GitHub发布说明.md)、[第三方说明](THIRD_PARTY_NOTICES.md)。

## 快速检查

```bash
python3 scripts/check_repo.py
python3 -m unittest discover -s tests -v
```

以上检查不访问设备、不驱动电机或舵机。部署后的只读检查：

```bash
python3 scripts/check_board.py http://BOARD_IP:8080
```

## 复现前提

仓库不是完整的安路 SDK，也不包含 TD/FD 安装程序、工具链和公开分发许可未明确的启动镜像。
需自行准备对应官方 `uisrc-lab-anlogic`、TD/FD 和 AIC8800D80 固件；必需输入和本地已验证文件的哈希见 `manifests/`。
重新生成镜像时必须将 FPGA bit、FSBL、内核、设备树、模块与 rootfs 作为一套匹配输入。

默认配置不启用 FPGA MMIO；确认 `BOOT.bin` 含本工程位流后，构建时显式加 `--enable-fpga-servos`。
不要用关闭网页报错的方式绕过位流验证：未实现的 AXI 地址曾触发系统 SError。

## 当前验证范围

截至 2026-11-01，板上完成两次 SSH 重启、Web 启动和舵机寄存器写入验证；WiFi 自动关联，GPS 串口有数据但未定位。
电机和摄像头此前经过上板测试；本次仓库整理不重复驱动硬件。
全新 SDK 从零构建、断电冷启动及机械动作验收仍按测试文档复测，不能把静态检查当作全部通过。
