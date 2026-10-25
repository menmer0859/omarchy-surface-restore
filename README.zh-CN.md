# Omarchy Surface 功能恢复

按需选择 Surface 功能。本仓库包含两个可以分别安装、也可共存的模块：

| 模块 | 恢复内容 | 入口 |
| --- | --- | --- |
| 红外人脸识别 | Omarchy 锁屏人脸解锁；终端 sudo 和图形 Polkit 是独立可选项 | `./install.sh face` |
| 触摸屏 | linux-surface 内核、headers 和 `iptsd` | `./install.sh touch` |

安装人脸模块不会安装 Surface 内核；安装触摸模块不会修改 PAM、Howdy 或人脸插件。旧命令 `./install.sh all` 仍表示先配置触摸，再进行首次人脸配置，不会自动启用 sudo 或图形授权的人脸识别。

## 快速开始

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git
cd omarchy-surface-restore
./install.sh check
./install.sh
```

交互菜单会让你选择模块，也可以直接运行：

```bash
./install.sh face
./install.sh touch
```

### 引导式人脸配置插件

本仓库也可以构建一个独立的 Omarchy 状态栏插件，提供中英双语配置面板和只读就绪检查。生成并验证自包含插件目录：

```bash
python3 modules/face-auth/scripts/export-setup-plugin.py --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

此 GitHub 项目是源码仓库，本身还不是可直接传给插件安装命令的插件仓库。`omarchy plugin add` 要求 Git 仓库根目录包含插件 manifest。独立插件仓库及 Omarchy 插件目录上架尚未发布。发布流程和当前状态见[插件分发说明](docs/face-setup-plugin-distribution.md)。

安装前请阅读各模块说明：[红外人脸识别](modules/face-auth/README.zh-CN.md) · [触摸屏](modules/touch/README.zh-CN.md)。English: [face authentication](modules/face-auth/README.md) · [touchscreen](modules/touch/README.md)。

## 已验证的设备

真实设备基线为 Microsoft Surface Laptop 5，运行基于 Arch Linux 的 Omarchy。人脸插件和模块目录调整已在这台设备安装并进行多轮试用；其他 Surface 型号、相机栈和 Omarchy 版本仍需各自验证。触摸恢复使用上游 linux-surface Arch 软件源和 `iptsd`。

详见 [Surface Laptop 5 配置记录](docs/verified-surface-laptop-5.md) 和 [人脸插件行为说明](docs/plugin-development.md)。本项目把 Howdy、PAM 与 Omarchy 界面组合起来，不宣称具备 Windows Hello 同级的防伪能力或相机停止时限保证。

## 命令

```bash
./install.sh face        # 首次配置 Howdy、人脸录入与锁屏插件
./install.sh sudo-face   # 可选：终端 sudo 每次先明确选择是否使用人脸
./install.sh polkit-face # 可选：图形管理员授权中明确选择人脸
./install.sh plugin-ui   # 只升级已有的人脸插件界面
./install.sh touch       # Surface 触摸屏内核和 iptsd
./install.sh check       # 只读检查设备与运行环境
./install.sh all         # 旧行为：触摸支持，然后首次配置人脸
```

安装器会说明变更、在应用前征求确认并保存恢复快照。人脸模型只保存在本机，严禁提交到 GitHub。依赖、验证与回退方式见模块说明。

## 开发检查

在仓库根目录运行：

```bash
bash tests/run.sh
bash modules/face-auth/tests/compile-services.sh
```

Polkit 原生会话重开测试还需要按人脸模块打包说明准备指定版本的 Quickshell 源码：[Quickshell 构建说明](modules/face-auth/packaging/quickshell-polkit-restart/README.md)。

## 许可证

见 [LICENSE](LICENSE)。
