# Surface Laptop 5 + Omarchy 实机记录

这份记录保存本项目的实测路径和遇到的问题。安装器已把个人用户名、特定摄像头完整路径和人脸模型排除在仓库之外。

## 环境

- 设备：Microsoft Surface Laptop 5
- 发行版：Omarchy 4.0.4（Arch Linux）
- 启动管理器：Limine
- 触摸：linux-surface 6.19.8、`iptsd` 3.1.0
- 红外人脸识别：AUR 的 `howdy-git` 2.6.1 开发包与 `python-dlib-git`
- 图形锁屏：Omarchy Quickshell 锁屏的用户插件克隆

## 触摸屏恢复

1. 保留 Omarchy 自带内核，不先卸载或覆盖它。
2. 按 linux-surface Arch 指南导入并核对签名密钥，加入上游软件源。
3. 安装 `linux-surface`、`linux-surface-headers` 和 `iptsd`。
4. 检查 Limine 可用的启动项；重启并进入 Surface 内核。
5. 确认 `uname -r` 含 `surface`，`iptsd.service` 正常，然后在桌面实际点按屏幕。

实机在 Surface 内核启动后恢复了触摸输入。启动项没有自动重写，原 Omarchy 内核仍可从 Limine 启动。

## 红外人脸解锁

1. 安装 Howdy 和 dlib/OpenCV 依赖。实机使用 `howdy-git` 开发版；项目安装器要求 AUR helper 展示并确认软件包事务。
2. 用 `v4l2-ctl --list-devices` 和 `/dev/v4l/by-path/` 找到 IR 摄像头稳定节点。设备有多个相似节点，不能只凭 `video0` 编号推断。
3. 在 Howdy 配置中设置 IR 摄像头、480×480 分辨率。这个摄像头实测使用 10 秒超时和 `dark_threshold = 90`；其他摄像头要按测试结果调整。
4. 在本机为桌面账户运行 Howdy 人脸录入。模型留在 `/etc/howdy/models/`，不进入代码仓库。
5. 单独创建 `/etc/pam.d/omarchy-lock-face`，锁屏通过该 PAM 名称调用 Howdy。保留 Omarchy 的密码 PAM。
6. 为 Omarchy 锁屏加入 `faceConfigured`、`faceAuthenticating` 和 `unlockMode` 状态：锁屏开始时优先人脸；失败时继续识别；选择密码时停止人脸 PAM；密码和人脸按钮可以双向切换。
7. 重载 Omarchy shell，锁屏并对准摄像头，确认能自动认证；再确认密码切换入口。

实机成功后，锁屏状态显示 `unlockMode: face`、`faceConfigured: true`；Howdy 日志返回 `Login approved`，会话约两秒内解锁。密码 PAM 始终存在。

## 处理过的权限故障

第一次真实锁屏时，UI 已进入人脸模式，但 Howdy 报 `PermissionError`，无法读取人脸模型。原因是模型目录不可由桌面用户遍历，模型文件也没有授予该用户读取权限。

实机权限修正为：模型目录 `root:root`、模式 `0711`；当前用户模型为 `root:<用户主组>`、模式 `0640`。这样目录不能被普通用户列出，但运行锁屏的账户可以读取自己的模型。修复后再次锁屏，Howdy 认证成功并自动解锁。

公用安装器会设置该读取权限并记录模型文件的备份/恢复状态。多用户设备应为每个账户分别处理模型读取权限；此参考流程面向单用户 Omarchy 笔记本。

### 终端 sudo 的显式人脸确认（可选）

sudo 人脸支持独立于锁屏配置，默认不启用。安装器先确认 Howdy 模型、PAM 模块和 `system-auth` 中的 faillock 规则，再备份 sudo PAM 文件并安装 root 所有的同意 helper。sudo 需要认证时，用户必须在控制终端明确输入 `y` 或 `Y` 后才会启动 IR 摄像头；回车、拒绝、超时、没有控制终端或识别失败都会继续密码认证。它仅修改 `/etc/pam.d/sudo`，不会改变 `system-auth`、`su`、桌面登录或锁屏 PAM。恢复快照会还原 sudo PAM，并在适用时删除新安装的 helper。

该流程要求明确同意并保留密码回退；不宣称后台自动识别或替代密码。实际 sudo 成功、失败和锁定状态仍需在目标设备交互验证。

## 可复用时需要现场确认的内容

- Surface 型号和 linux-surface 支持情况；不是每个 Surface 的触摸屏/IR 摄像头实现都相同。
- Limine 当前启动项与磁盘加密设置；首次重启前确认原内核可用。
- IR 摄像头节点、访问权限、画面亮度和 Howdy 阈值。
- 当前 Omarchy 锁屏插件接口。此仓库的 Quickshell 锁屏克隆只在 Omarchy 4.0.4 实测，升级后先检查上游锁屏变化。
- Howdy AUR 包和 Python 依赖随 Arch 滚动更新；请先审阅 PKGBUILD 和软件包事务。
