# Omarchy 上的 Surface 功能恢复

本项目整理并自动化 Microsoft Surface 在 Omarchy（Arch Linux）上的触摸屏与红外人脸解锁配置。流程来自 Surface Laptop 5 实机验证；安装器会现场列出摄像头路径并让用户选择，不会写入本机的人脸模型或设备专属路径。

> 运行前请先阅读脚本。安装器会安装系统软件并修改配置文件；密码解锁会保留，人脸识别只是额外入口。

实机验证基线：Surface Laptop 5、Omarchy 4.0.4、linux-surface 6.19.8、iptsd 3.1.0、Howdy `howdy-git` 2.6.1 开发版。其他 Surface 型号和 Omarchy 版本可能有差异；锁屏插件只在 Omarchy 4.0.4 上完整验证过。

## 快速开始

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git
cd omarchy-surface-restore
./install.sh check       # 只读检查
./install.sh             # 交互式菜单
```

也可以直接选择功能：

```bash
./install.sh touch      # Surface 内核与触摸支持
./install.sh face       # Howdy、人脸录入和锁屏切换
./install.sh sudo-face  # 可选：终端 sudo 人脸确认
./install.sh all        # 顺序配置两项
```

触摸配置使用 linux-surface 上游 Arch 软件源，安装前会核对官方签名密钥指纹，然后安装 `linux-surface`、headers 和 `iptsd`。原有 Omarchy 内核会保留作备用。Arch 系统升级可能同步更新其他软件包，请接电源；安装器不会擅自改 Limine 或自动重启。

人脸配置需要 `yay` 或 `paru` 和 `v4l-utils`。请检查 AUR helper 展示的构建配方和软件变更。安装器会列出稳定摄像头路径，结合 `v4l2-ctl --list-devices` 或 Howdy 摄像头测试，选择红外摄像头。不要猜测 `/dev/video0`；摄像头编号可能改变。

Howdy 会在本机录入人脸，并把模型保存在 `/etc/howdy/models/`。模型文件不会上传或放进 Git。锁屏默认尝试人脸识别，并提供密码/人脸切换按钮。Howdy 使用独立 PAM 服务，系统密码 PAM 不会被替换。

终端 sudo 的人脸认证是单独的可选步骤：完成 `face` 安装和本机录入后，运行 `./install.sh sudo-face`。每当 sudo 需要重新认证时，控制终端会显示 `Use face authentication? [y/N]`；只有明确输入 `y` 或 `Y` 才启动 Howdy 摄像头。直接回车、其他输入、超时、没有控制终端或识别失败，都会继续现有密码认证。它只修改 `/etc/pam.d/sudo` 和 root 所有的 `/usr/local/libexec/omarchy-sudo-face-consent`；会沿用 `system-auth` 中现有的 faillock 预认证与成功记录选项，不修改 `system-auth`、`su`、桌面登录或锁屏行为。sudo PAM 文件和原有 helper 会备份。运行 `./scripts/restore.sh` 可恢复；若安装前 helper 不存在，恢复时会删除它。

## 安装后验证

触摸屏配置完成后重启，在 Limine 选择名称含 `linux-surface` 的内核（如果它没有自动启动），再检查：

```bash
uname -r
systemctl status iptsd.service
```

内核版本应包含 `surface`。测试触摸输入；如有问题，可从 Limine 启动原 Omarchy 内核，并检查 `journalctl -b -u iptsd.service`。

人脸配置后重启 Omarchy shell 并锁屏：

```bash
omarchy restart shell
```

锁屏会先进入人脸识别；点“使用密码解锁”输入账户密码，点“使用人脸解锁”可切回。请在依赖人脸识别前确认密码仍可解锁。

## 备份与恢复

被替换的文件和 Howdy 模型目录权限会备份到 `/var/backups/omarchy-surface-restore/<时间戳>/`，原绝对路径会保留。运行下方脚本，选择一个快照后确认恢复：

```bash
./scripts/restore.sh
```

组合运行 `all` 时两项配置共用同一快照；分别运行 touch 和 face 会生成不同快照。恢复会还原已有配置，并删除快照标记为安装器新建的单个文件（包括新录入的人脸模型）。它不会卸载软件包、内核或移除签名密钥。

## 安全和隐私

- 切勿提交 `*.dat`、相机抓拍、模型文件、软件包归档、私钥或备份目录。
- AUR 软件包使用第三方构建脚本；安装前请检查 PKGBUILD 及其依赖。
- 人脸模型属于敏感生物识别数据。保护系统备份，删除人脸解锁时也删除本机模型。
- 锁屏 Howdy 使用专用 PAM 服务。除非明确运行 `./install.sh sudo-face`，终端 sudo 不会启用人脸认证；启用后，每次需要 sudo 认证时都必须先在终端明确输入 `y`/`Y` 才会访问摄像头。
- 如果系统里已有另一个克隆 `omarchy.lock` 的用户插件，请先停用它，避免两个插件同时替换锁屏。

## 测试

```bash
bash tests/run.sh
```

测试只使用临时文件，不安装软件或改动系统配置。真实触摸和人脸识别仍需在目标 Surface 上人工确认。

完整实机记录见 [docs/verified-surface-laptop-5.md](docs/verified-surface-laptop-5.md)。软件和硬件项目来源列在英文 [README](README.md#upstream-references) 中。
