# 第三方来源与发布边界

本项目包含自己的集成源码，也保留官方板级配置、生成的 FPGA IP 包装、FSBL/BSP 和第三方 WiFi 驱动。各文件原版权/许可头保持原样；本仓库没有把这些内容重新许可为 MIT，也没有为所有代码声明统一的新许可证。

| 路径 | 来源 / 注意事项 |
|---|---|
| `fpga/td/uisrc/01_rtl/system`、`fpga/td/al_ip` | 安路工具生成的 Processor System / PLL 配置与 RTL；构建需要合法安装 TD/FD 与对应 IP |
| `fpga/fd` | 官方 SDK/FD 平台、FSBL、BSP 及第三方代码；以各文件许可为准 |
| `linux/drivers/aic8800` | 官方资料所附 AIC8800 USB 驱动，包含 AIC/RivieraWaves 等原版权头；未发现覆盖整份目录的独立统一 LICENSE，公开分发前需确认供应方授权 |
| `linux/kernel`、`linux/boot` | 官方 Linux/U-Boot 的配置和板级设备树快照；相应文件许可和官方项目许可适用 |
| `third_party/sources/linux` | 从所用 Linux 源码保留的 COPYING、LICENSES 原文 |
| `third_party/sources/u-boot` | 从所用 U-Boot 源码保留的 Licenses 原文 |

安路 SDK、工具链、TD/FD 安装程序、厂商 PDF、模型权重、固件二进制和完整系统镜像均不作为 Git 源码上传。`artifacts/` 的本地产物用于核对来源，默认被忽略；镜像还可能包含本地 root/WiFi 配置。

这份说明是来源记录，不代替第三方分发授权。要开源发布，先明确自有代码的许可证，并确认供应方对上述原厂源码/生成 IP 的公开托管条款；若授权范围不包含公开源码，改用私有仓库保存，或从发布清单移除该部分并要求用户从官方资料自行提供。
