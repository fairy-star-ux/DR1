# GitHub 发布说明

整理目录就是 Git 仓库根目录；不要在上一级 `D:/fpga_prj` 执行 `git add .`。
原工作工程未搬移，新目录中的旧平台密钥和构建账号配置已经脱敏。配置自己的凭据时只使用被忽略的 `secrets/`。

## 发布前检查

```bash
python3 scripts/check_repo.py
python3 -m unittest discover -s tests -v
git status --short
git diff --cached --stat
git ls-files artifacts secrets
```

最后一条应没有输出。还要人工检查拟发布差异，确认没有照片、SSH 密钥、云平台密钥、WiFi PSK 和含密码的 rootfs。
原厂源码/IP 授权范围见 `THIRD_PARTY_NOTICES.md`；无法确定公开许可时先用私有仓库。

## 提交与关联远端

本项目远端为 `https://github.com/fairy-star-ux/DR1.git`。首次上传保留仓库已有初始提交和项目介绍，不强制覆盖远端历史。
下面命令用于首次配置其他副本或派生仓库；如果已有 `origin`，先用 `git remote -v` 核对，不重复添加。提交身份替换成自己的：

```bash
git config user.name "YOUR_NAME"
git config user.email "YOUR_EMAIL"
git add .
git diff --cached --stat
git commit -m "Organize DR1M90 FPGA and Linux reproducible sources"
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPO.git
git push -u origin main
```

密码/Token 不写入远端 URL。使用 Git 凭据管理器或 SSH Key。
官方 SDK 等大文件不使用 Git LFS 绕过权限检查；需分发产物时，先确认分发许可、去除凭据，再单独制作带 SHA-256 的 Release。

## 后续维护

- 修改 RTL/地址后，同步更新寄存器文档、BOOT 输入哈希与 Linux 配置；原 bit 哈希不代表新 bit。
- 应用修改后运行离线测试和摄像头/电机/舵机逐项验收；保存测试日期、commit 与镜像哈希。
- `manifests/source-sha256.json` 记录首次整理版本，改动受记录文件后应重新生成或更新该清单。
- 新镜像/私有配置留在被忽略目录。运行 `python3 scripts/update_manifests.py` 刷新清单，再运行检查。源码哈希将 CRLF 统一为 LF，兼容 Git 换行转换；产物哈希按二进制原始字节计算。清单本身、验证报告、`.git` 和构建产物不进入源码递归哈希。
