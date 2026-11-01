# 清单含义

- `local-source-provenance.json`：从原 Windows 工作区复制时的来源相对路径及原字节 SHA-256。
- `vm-export.json`：从实际 SDK/overlay 导出文件时的路径、原字节 SHA-256 和大小；它记录导出时状态，后续脱敏/修订后不要求仍等于源文件。
- `source-sha256.json`：整理完成源码的 SHA-256，CRLF 按 LF 归一化，不含本清单自身、产物清单及验证报告。
- `artifact-sha256.json`：本地忽略目录 `artifacts/` 中对应已验证 bit/BOOT、SDK 输出、运行依赖的原字节 SHA-256 与大小。Git 中只有哈希，不附二进制。
- `validation-report.json`：本次验证范围与结果，不能代替冷启动/机械验收。
- `sdk-reference/`：所用官方 SDK 版本 Makefile 与流程脚本快照，只作来源和流程比对；不直接替代本仓库的构建入口。

`artifacts/known-good` 为此前上板确认的 BOOT/位流等输入；`artifacts/sdk-output` 是导出时 SDK 输出快照，两者不能只按文件名判定相同。核对清单和实际 SHA-256 后再选用，不把未验证输入混成同一套镜像。

外部必需：官方 DR1M SDK、TD/FD/IP、Linaro AArch64 GCC 7.5.0、AIC8800D80 完整固件。源码不是完整 SDK 镜像，官方固件许可未确认，需使用者另行从板卡资料取得。

已导出 WiFi 源码包（原包名以官方资料为准）的 SHA-256：`5b8397a62b866c82378db74ad98d0d68a9ef263c3cba214d20576876e40ffba3`。此哈希表示本地所用资料版本，不是公开下载地址或分发授权。
