# Omarchy 红外人脸识别模块

本模块为受支持的 Surface + Omarchy 恢复本地 Howdy 人脸识别，并分别接入锁屏、可选的终端 sudo 和可选的图形 Polkit 授权。密码仍然可用。

实机验证基线是运行 Omarchy/Arch 的 Surface Laptop 5。这不代表其他 Surface 相机系统或 Omarchy 版本已验证。本项目是 Howdy/PAM 集成，不具备 Windows Hello 同级的防伪能力，也不保证相机停止时限。

## 安装

在仓库根目录执行：

```bash
./install.sh check
./install.sh face
```

### 引导式配置面板

`surface.face-setup` 状态栏插件提供只读兼容性检查，并允许分别选择锁屏、终端 sudo 和图形 Polkit。请在源码仓库根目录生成并验证独立插件目录：

```bash
python3 modules/face-auth/scripts/export-setup-plugin.py --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

导出的目录可作为单独 Git 仓库的根目录发布。该仓库发布后，用户可运行 `omarchy plugin add <插件 Git 地址> --enable` 安装。目前已完成本地导出与验证，配套仓库及插件目录上架尚未发布。详见[插件分发说明](../../docs/face-setup-plugin-distribution.md)。

安装器会检查 Omarchy、插件翻译 API、稳定的 V4L2 路径及红外相机访问权限，并请你辨认相机，不会猜测 `/dev/video0`。请审核 AUR 的 `howdy-git` 软件包变更。Howdy 会在本机 `/etc/howdy/models/` 保存录入的人脸模型；模型不会复制进仓库。

录入完成后会安装锁屏的人脸/密码路径。手动锁屏本身不启动相机；屏幕亮着时，新的明确操作可以请求一次识别。系统确认屏幕由熄灭变亮或从休眠恢复后，等待约 1.5 秒并尝试一次。识别失败后不会在后台周期扫描。密码始终可用。

### 可选：终端 sudo

```bash
./install.sh sudo-face
```

只有在 `Use face authentication? [y/N]` 后输入 `y` 或 `Y` 才会启动 Howdy。回车、拒绝、超时、终端不可用或识别失败都会回到原密码路径。可用 `sudo -k -v` 清理 sudo 缓存并触发新一轮验证。

### 可选：图形管理员授权

```bash
./install.sh polkit-face
```

此项会在 Omarchy 全屏 Polkit 提示中加入“使用人脸”和“使用密码”。必须点击“使用人脸”才访问相机。取消会结束本次授权。它会修改 Polkit PAM 服务、用户插件、仅针对所选摄像头的设备规则及辅助模块；安装前会显示目标并备份。

从密码页返回人脸需要本模块打包的 Quickshell API。返回后先打开安静的方式选择页；用户还要再次明确选择“使用人脸”才同意扫描。如果 Polkit 识别已经进行中，当前后端只能取消整个请求或等待识别失败，不能在同一个忙碌会话中直接切换密码。

## 只升级界面

已配置好人脸的设备只更新现有插件界面：

```bash
./install.sh plugin-ui
omarchy restart shell
```

此操作只更新受管的锁屏/Polkit 界面资源，不改 PAM/Howdy，也不会重新录入模型。插件安装后不依赖仓库目录继续存在。

界面支持英语和简体中文，跟随 **Omarchy 菜单 → Setup → Language**。终端辅助程序读取标准路径 `~/.config/omarchy/language`；出于特权辅助程序安全考虑，不采用自定义 XDG 配置目录。

## Quickshell 依赖

图形界面“返回人脸”依赖 `AuthFlow.restartAuthentication()`。指定版本配方和补丁在 [`packaging/quickshell-polkit-restart`](packaging/quickshell-polkit-restart/README.md)。它针对已验证的 Quickshell 源码版本，不能盲目降级较新的系统包。旧运行时仍保留密码验证，并隐藏当前不支持的返回操作。

Qt 6.12 下重新打包还必须保留 Omarchy 的主题加载兼容补丁。修正后的本地包为 `0.3.2.r7.g2b4501a-3.1`；此前的 `-2` 漏带该补丁，会导致其他插件的主题颜色异常。

## 验收与恢复

建议顺序：先验证锁屏密码兜底；锁屏后测试“密码 → 返回人脸选择 → 明确选择人脸”；再用 `sudo -k -v` 分别测试 n 和 y；用 `pkexec /usr/bin/id` 测试密码、人脸返回和取消；最后选一个真实图形管理员操作。Polkit 可能缓存授权，因此命令不一定每次都弹出提示。

安装器把时间戳备份存放在 `/var/backups/omarchy-surface-restore`。只恢复人脸模块时：

```bash
./scripts/restore.sh --module face-auth
```

添加模块标签之前创建的旧快照只会出现在不筛选模块的恢复列表中，请仔细检查文件清单。恢复不会卸载软件包/内核，也不会降级 Quickshell。恢复认证文件时请保留一个可用终端。

## 限制与隐私

- Howdy PAM matcher 是独立进程；结束界面或 PAM 会话不代表 matcher 已立即退出或释放相机。界面超时不是物理相机断电时限。
- Surface Laptop 5 是实机基线。其他机型需分别检查相机栈、权限和红外设备节点。
- 不要提交 `*.dat`、`*.model`、人脸照片、相机帧、备份、本地软件包、凭据或设备专属配置。

实现与测试细节见[插件行为说明](../../docs/plugin-development.md)、[本机验收记录](../../docs/local-acceptance-fixes.md)和[总测试入口](../../tests/run.sh)。
