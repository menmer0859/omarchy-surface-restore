# Omarchy 上的 Surface 功能恢复

本项目整理并自动化 Microsoft Surface 在 Omarchy（Arch Linux）上的触摸屏与红外人脸解锁配置。流程来自 Surface Laptop 5 实机验证；安装器会现场列出摄像头路径并让用户选择，不会写入本机的人脸模型或设备专属路径。

> 运行前请先阅读脚本。安装器会安装系统软件并修改配置文件；密码解锁会保留，人脸识别只是额外入口。

实机验证基线：Surface Laptop 5、Omarchy 4.0.4、linux-surface 6.19.8、iptsd 3.1.0、Howdy `howdy-git` 2.6.1 开发版。项目负责人反馈：修正 Quickshell `Process` 退出信号后，一次用户意图触发的人脸锁屏已在本机运行，锁屏现可正常响应；完整相机时序、休眠和 Polkit 密码回退验收尚未记录。其他 Surface 型号和 Omarchy 版本不视为已支持。

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
./install.sh polkit-face # 可选：图形管理员提示中的人脸/密码选择
./install.sh all        # 顺序配置两项
```

触摸配置使用 linux-surface 上游 Arch 软件源，安装前会核对官方签名密钥指纹，然后安装 `linux-surface`、headers 和 `iptsd`。原有 Omarchy 内核会保留作备用。Arch 系统升级可能同步更新其他软件包，请接电源；安装器不会擅自改 Limine 或自动重启。

人脸配置需要 `yay` 或 `paru` 和 `v4l-utils`。请检查 AUR helper 展示的构建配方和软件变更。安装器会列出稳定摄像头路径，结合 `v4l2-ctl --list-devices` 或 Howdy 摄像头测试，选择红外摄像头。不要猜测 `/dev/video0`；摄像头编号可能改变。

Howdy 会在本机录入人脸，并把模型保存在 `/etc/howdy/models/`。模型文件不会上传或放进 Git。锁屏使用独立 PAM 服务，系统密码 PAM 不会被替换；进入 secure 后，新的按键、点击或触摸可启动一次识别，界面/PAM 请求在 12 秒后中止。鼠标移动只负责唤醒显示，不会启动相机；失败后必须显式重试。当前尚不能保证 PAM 中断时 Howdy 独立启动的识别进程立即退出，因此 12 秒计时器不代表摄像头最多只工作 12 秒。

终端 sudo 的人脸认证是单独的可选步骤：完成 `face` 安装和本机录入后，运行 `./install.sh sudo-face`。每当 sudo 需要重新认证时，控制终端会显示 `Use face authentication? [y/N]`；只有明确输入 `y` 或 `Y` 才启动 Howdy 摄像头。直接回车、其他输入、超时、没有控制终端或识别失败，都会继续现有密码认证。它只修改 `/etc/pam.d/sudo` 和 root 所有的 `/usr/local/libexec/omarchy-sudo-face-consent`；会沿用 `system-auth` 中现有的 faillock 预认证与成功记录选项，不修改 `system-auth`、`su`、桌面登录或锁屏行为。sudo PAM 文件和原有 helper 会备份。运行 `./scripts/restore.sh` 可恢复；若安装前 helper 不存在，恢复时会删除它。

### 终端 sudo 人脸验证步骤

1. 确认当前用户已录入 Howdy 模型：`test -s "/etc/howdy/models/$USER.dat"`。如果文件不存在，先运行 `./install.sh face` 并完成本机人脸录入。
2. 在项目目录运行 `./install.sh sudo-face`。安装器会先检查 Howdy 命令、模型、`pam_howdy.so`、`pam_exec.so`、`pam_faillock.so` 和 sudo 的 PAM 布局，再显示变更范围并要求确认。它会备份 `/etc/pam.d/sudo`，将 root 所有、权限为 `0755` 的 helper 安装到 `/usr/local/libexec/`，最后只更新 sudo 的认证规则。
3. 用 `sudo -k -v` 清除 sudo 的认证缓存并触发一次真实验证。输入 `N` 后应该出现普通 sudo 密码提示；输入密码成功，表示密码回退可用。
4. 再运行一次 `sudo -k -v`，这次输入 `y`。Howdy 应启动红外摄像头；识别成功则验证通过，识别失败则应继续到密码提示。

sudo 会缓存成功认证，所以平时不会每次运行命令都询问。`sudo -k` 只用于强制触发下一次认证。无控制终端时 helper 会拒绝启动摄像头，非交互式 sudo 仍受 sudo 自身的密码/TTY 策略约束。

PAM 中的 `pam_faillock preauth` 先检查账户锁定；`pam_exec.so quiet` 调用同意 helper，并抑制用户拒绝时 PAM 模块产生的“helper failed”提示；只有输入 `y/Y` 才到 `pam_howdy.so`。由于 `pam_exec` 会在一个没有控制终端 `/dev/tty` 的新会话中运行 helper，helper 会通过 PAM 提供的 `PAM_TTY` 只打开本地终端设备。人脸成功后写入 `pam_faillock authsucc`，失败或拒绝则进入原来的 `system-auth` 密码流程。该提示中的 `[y/N]` 表示默认拒绝，按回车不会启动摄像头。

如需完全回退，运行 `./scripts/restore.sh`，选择 sudo 人脸安装前生成的快照并确认。重复安装会创建新的快照；选择前先检查快照内的 `etc/pam.d/sudo` 是否已经含有 `omarchy-surface-restore sudo face authentication` 标记。要关闭该功能，应选一份**不含此标记**的安装前备份。

图形软件请求管理员权限时通常走 Polkit，而不是 `sudo`。可选运行 `./install.sh polkit-face`，为 Omarchy 全屏 Polkit 提示添加“Use face”和“Use password”两个按钮。只有点击“Use face”才会把同意交给 PAM 并启动 Howdy；拒绝、对话故障或识别失败会进入原密码认证。安装器会构建一个小型 PAM 同意模块、克隆 Omarchy 自带的 Polkit 插件，并创建 `/etc/pam.d/polkit-1` 覆盖；不会修改 `system-auth` 或 Polkit 授权策略。Howdy 通过 `pam_exec.so` 运行，避免其诊断输出污染 Polkit 对话协议；PAM 栈若在 `system-auth` 后还有额外认证规则，安装器会拒绝更改以免人脸成功跳过这些规则。安装器还会从 Howdy 配置解析当前红外摄像头，只给 Polkit helper 开放该 `/dev/videoN` 节点，同时保留 systemd 的严格设备策略。若已有其他 Polkit 插件克隆，安装器会停止并要求先处理冲突。全屏提示会显示当前认证身份；如管理员身份不止一个，可点击身份按钮切换。当前 QML 基于 Omarchy 4.0.4，其他版本需要先检查插件变化。

### 图形管理员提示验证

安装后，从图形桌面触发一个确实要求管理员认证的动作；也可在终端运行 `pkexec /usr/bin/id`，确认请求出现在 Omarchy 全屏授权界面。先点“Use password”并验证密码路径，再重新触发授权、点“Use face”验证 Howdy。识别失败应显示密码输入；取消授权应取消原动作。Polkit 会短暂缓存部分授权，如果动作没有再次弹框，可稍后重试或触发另一项受保护的动作。

回退时，在 `./scripts/restore.sh` 中选择安装前快照。快照会还原或移除 `/etc/pam.d/polkit-1`、`/usr/local/lib/security/pam_surface_face_consent.so`、systemd 摄像头规则及安装器创建的用户 Polkit 插件文件。

旧版流程曾在 Surface Laptop 5 上实测：重启 shell 后运行 `pkexec /usr/bin/id` 会打开 Omarchy 全屏授权界面；点击 **Use face** 后红外摄像头启动，命令以 root 身份成功执行。本次失败后密码回退提示尚待重新进行图形实机验证。

如果 `pkexec` 只在终端显示 `Use face authentication? [y/N]`，却没有出现 Omarchy 全屏按钮，通常是 Quickshell 作为 systemd 用户服务运行时，无法从进程所属 cgroup 推断登录会话。项目提供了基于官方 Arch Quickshell 0.3.1 配方、仅包含上游 [PR #875](https://github.com/quickshell-mirror/quickshell/pull/875) 会话注册修复的本地 Arch 包。先在项目目录执行：

```bash
cd packaging/quickshell-xdg-session
makepkg -si
```

`makepkg` 会显示需要的构建依赖并通过 sudo 请求安装；请审阅 PKGBUILD 和软件包变更。安装后返回项目根目录，再运行 `./install.sh polkit-face` 更新 Polkit 摄像头权限。随后运行 `omarchy restart shell` 或注销并重新登录，再测试 `pkexec /usr/bin/id`。成功时应该出现全屏界面；选择“Use password”测试密码回退，再重试并明确点击“Use face”。摄像头只有在选择人脸后才会启动。

如果需要撤销 Polkit/PAM 与 systemd 摄像头规则，运行 `./scripts/restore.sh` 并选择本次安装快照。该操作不会降级 Quickshell 软件包；如需退回发行版版本，可运行 `sudo pacman -S quickshell`。

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

锁屏进入安全状态时不会自动启动相机。屏幕先显示“已锁定。点击或按键使用人脸”；之后新的按键、点击或触摸才会启动一次识别，界面/PAM 请求在 12 秒后中止。鼠标移动只唤醒显示；锁屏快捷键释放、显示器变化和预览均不会启动相机。识别失败后不会自动重试；点“重试人脸”可再试，点“使用密码”进入原密码流程。当前尚不能保证 PAM 中断时 Howdy 识别进程立即退出，因此真实摄像头停止时间仍是待解决项。请在依赖人脸识别前确认密码仍可解锁。

更新已有锁屏插件时，在项目目录运行 `./scripts/install-lock-ui.sh`，然后运行 `omarchy restart shell`。安装器会先备份旧插件；`./scripts/restore.sh` 可恢复原目录，并在适用时移除新加的 `FaceAttemptPolicy.js`。这只更新用户级锁屏插件，不安装或更改系统 PAM。

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
- 图形 Polkit 人脸认证也默认关闭。启用后必须在全屏提示中明确点击“Use face”；人脸识别不是密码的安全替代品。
- 如果系统里已有另一个克隆 `omarchy.lock` 的用户插件，请先停用它，避免两个插件同时替换锁屏。

## 测试

```bash
bash tests/run.sh
```

自动化测试只使用临时文件，不安装软件或改动系统配置。锁屏基础运行已由项目负责人在 Surface Laptop 5 本机确认；完整硬件验收矩阵仍需逐项记录。

完整实机记录见 [docs/verified-surface-laptop-5.md](docs/verified-surface-laptop-5.md)。软件和硬件项目来源列在英文 [README](README.md#upstream-references) 中。
