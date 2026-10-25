---
title: "Omarchy Surface Restore — 简体中文"
type: project-readme
date: 2026-10-25
status: reviewed
canonical_path: "https://github.com/menmer0859/omarchy-surface-restore/blob/main/README.zh-CN.md"
---

<div align="center">

<img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/mark.svg" width="88" alt="Omarchy Surface Restore 标志：扫描框中的笑脸">

# Omarchy Surface Restore

### 让 Surface 在 Omarchy 上，重新用上人脸与触摸。

**两个独立模块，为 Omarchy 恢复红外人脸认证与触摸。**<br>
锁屏、可选的 sudo 与 Polkit。已验证硬件基线：Surface Laptop 5。

<img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/platforms.svg" width="292" alt="适用于 Arch Linux 上的 Omarchy。MIT 许可证。">

**[交给 Agent](#交给-agent-安装)** · **[手动安装](#快速开始)** · **[功能](#你会获得什么)** · **[兼容性](#兼容性与证据)** · **[文档](#文档与路径索引)** · **[反馈](https://github.com/menmer0859/omarchy-surface-restore/issues)** · [English](https://github.com/menmer0859/omarchy-surface-restore/blob/main/README.md) · **简体中文**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/overview-zh-dark.svg">
  <img src="https://raw.githubusercontent.com/menmer0859/omarchy-surface-restore/2b3ba16494986dcf157dc5e980751fee9353a241/docs/images/readme/overview-zh-light.svg" width="900" alt="认证流程示意：唤醒锁屏后尝试一次人脸识别，终端输入 y 同意扫脸，或在图形管理员请求中选择人脸；各场景保留密码入口。">
</picture>

<sub>以上为交互流程示意，非实机截图。已验证硬件基线：Surface Laptop 5。</sub>

</div>

## TL;DR

在运行 Omarchy 的 Surface 上，可以独立安装人脸认证、触摸屏支持，也可以安装两者。人脸认证覆盖锁屏及可选的 sudo/Polkit 请求，并保留密码兜底。已证实的参考设备是 Surface Laptop 5；其他机型安装前需先核对兼容性。

- **人脸认证：** 一个模块接入锁屏，并可选启用终端 sudo 和图形 Polkit 授权。
- **触摸屏支持：** 独立模块，使用 linux-surface 与 iptsd。
- **熟悉的选择：** 需要时使用人脸，并保留密码作为兜底。
- **中英双语：** 图形界面跟随 Omarchy 的语言设置；sudo 辅助程序读取同一语言偏好。

按需安装即可。如果触摸已经正常，只安装人脸模块就可以。其他 Surface 型号安装前，请先阅读[兼容性](#兼容性与证据)。

## 兼容性与证据

实机基线是 **Surface Laptop 5，运行基于 Arch Linux 的 Omarchy 4.5.0rc1**。锁屏、终端 sudo 和图形授权已经过多轮本机试用。这份记录对应特定设备与运行环境，其他 Surface 仍需各自验证。

| 项目 | 当前范围 |
| :-- | :-- |
| Surface Laptop 5 | **已证实：** 人脸与触摸功能的参考设备 |
| 其他 Surface 型号 | **待验证：** 需分别检查相机驱动、可用红外视频流、权限及上游触摸支持 |
| Omarchy 版本 | **超出基线版本时待验证：** 需要兼容的插件与翻译 API；升级版本后仍需验证 |
| 图形管理员授权 | **已证实的范围：** 由 Omarchy 认证代理处理的 Polkit 请求 |
| 其他认证 | **不在接入范围：** 磁盘加密、应用保险库、SSH 及其他登录路径不在默认接入范围内 |

设备与运行时细节见[已验证配置记录（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/verified-surface-laptop-5.md)。

证据来源：[已验证设备记录（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/verified-surface-laptop-5.md)、[行为约定（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md)及[当前主分支快照 a0a55d1](https://github.com/menmer0859/omarchy-surface-restore/commit/a0a55d12ae91e6131a4a91020e023cea784f89a4)。[PR #5](https://github.com/menmer0859/omarchy-surface-restore/pull/5)记录了合入修复分支的配置组件；实现位于[快照 0dd507e](https://github.com/menmer0859/omarchy-surface-restore/commit/0dd507e772b3c0752fa5d56e93fa40ca928980a8)，仍待进入 `main`。

## 交给 Agent 安装

在**这台运行 Omarchy 的 Surface 上**打开 Codex、Claude Code，或其他可以操作本机终端的 Agent，复制下面整段提示词即可。不需要先了解安装命令；Agent 会询问你需要的功能并引导配置，管理员认证和人脸录入由你在本机完成。

```text
请帮我在运行 Omarchy 的 Surface 上，安装这个项目提供的功能：
https://github.com/menmer0859/omarchy-surface-restore

先问我需要红外人脸认证、触摸屏支持，还是两者都要。
如果选择人脸认证，请分别询问是否用于锁屏、终端 sudo 和图形管理员授权，
只安装我选择的选项。

请自行检测实际 Surface 型号、处理器架构、Omarchy 版本、相机支持和现有配置。
先阅读仓库当前的 README、所选模块说明和安装脚本，使用干净的源码副本和
项目提供的安装入口。Surface Laptop 5 是已验证基线，其他硬件请先核对支持情况。

应用前说明系统变更，保留密码兜底，并使用项目的备份与恢复机制。
终端 sudo 和图形授权仍须先由用户明确同意才启动扫脸。
需要时引导我选择红外摄像头、审核软件包，并在本机录入人脸。

系统密码由我在本机终端输入，不要让我发到聊天里。如果你的执行环境无法进行
特权安装，请给我在普通系统终端运行的准确命令，不要降低系统保护。

安装后带我逐项实测所选功能，包括密码兜底，以及需要时的重启验证。
请区分自动检查与我已经确认的实机结果，最后说明哪些功能正常、哪些尚未验证，
以及如何恢复之前的配置。
```

<sub>无法访问本机的云端 Agent 可以解释步骤，但硬件检查、安装和录入仍需要在这台 Surface 上完成。</sub>

## 快速开始

**1 · 获取源码，检查设备。**

```bash
sudo pacman -S --needed git v4l-utils
git clone https://github.com/menmer0859/omarchy-surface-restore.git "$HOME/.local/share/omarchy-surface-restore"
"$HOME/.local/share/omarchy-surface-restore/install.sh" check
```

**2 · 选择模块。** 运行安装器，选择人脸认证或触摸屏支持。应用系统变更前，请阅读安装提示。

```bash
"$HOME/.local/share/omarchy-surface-restore/install.sh"
```

人脸安装需要 AUR 助手（`yay` 或 `paru`），随后会请你选择红外摄像头、审核 Howdy 软件包并在本机录入人脸。触摸安装会配置 linux-surface 内核、headers 和 iptsd；完成后需要重启并进入该内核。

**3 · 先验证密码兜底，再测试人脸。** 安装人脸模块后先测试锁屏；需要时再分别启用终端和应用授权：

```bash
"$HOME/.local/share/omarchy-surface-restore/install.sh" sudo-face    # 可选：终端 sudo 人脸认证
"$HOME/.local/share/omarchy-surface-restore/install.sh" polkit-face  # 可选：图形管理员授权
sudo -k -v               # 测试终端认证：先选 n，再选 y
pkexec /usr/bin/id       # 测试图形 Polkit 请求
```

<sub>也可直接运行 <code>"$HOME/.local/share/omarchy-surface-restore/install.sh" face</code> 或 <code>"$HOME/.local/share/omarchy-surface-restore/install.sh" touch</code>。完整安装与恢复说明：<a href="https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.zh-CN.md">人脸认证</a> · <a href="https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/touch/README.zh-CN.md">触摸屏</a>。</sub>

## 你会获得什么

### 唤醒，看向相机，解锁

手动锁屏后，电脑立即保持锁定，不会因为你还坐在相机前就马上扫脸解锁。系统确认熄屏唤醒或休眠恢复后，锁屏等待约 1.5 秒，再尝试一次识别。识别失败后，由你选择重试或输入密码。

锁屏不会在后台周期性扫描。屏幕亮着时，新的明确操作可请求一次识别；选用密码后，当前亮屏期间暂停人脸识别。

### 在终端明确同意 sudo 扫脸

每次需要重新认证的 sudo 请求，都会先询问是否使用人脸。输入 `y` 后启动识别，并引导你看向笔记本摄像头；拒绝、超时或识别失败则继续使用密码。

| 你的操作 | 接下来会发生什么 |
| :-- | :-- |
| 输入 `y` 或 `Y` | 尝试人脸识别 |
| 输入 `n`、直接回车或不回应 | 继续使用密码 |
| 人脸识别失败 | 继续使用密码 |

### 为应用选择授权方式

Omarchy 的图形 Polkit 界面展示请求的操作、管理员账户，以及**使用人脸 / 使用密码**两种选择。选择人脸后才启动摄像头；取消会终止本次授权。

从密码页返回人脸选择页需要兼容的 Quickshell 构建。[人脸模块说明](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.zh-CN.md#quickshell-依赖)介绍了这项依赖，以及正在扫描时切换方式的限制。拥有独立保险库或主密码的应用，需要各自的集成支持。

### 单独恢复触摸屏

触摸模块安装上游 linux-surface 内核、匹配的 headers 和 iptsd。系统保留原有 Omarchy 内核，作为启动回退选项。人脸模块不改变你的内核选择。

| 模块 | 配置的组件 |
| :-- | :-- |
| 人脸认证 | Howdy、所选 PAM 服务、Omarchy 锁屏和授权界面 |
| 触摸屏 | linux-surface 软件源、内核、headers 与 iptsd |

### 从 Omarchy 配置人脸

中英双语配置组件可以检查就绪状态，并让你分别选择锁屏、sudo 和 Polkit。状态检查只读取配置，不启动摄像头。

独立插件导出已合入 `main` 并完成本地验证。**目前仍没有可用的 `omarchy plugin add` 安装地址：**配套插件仓库和目录上架仍需后续完成。现阶段请使用上方源码安装器；当前发布状态见[插件分发说明（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/face-setup-plugin-distribution.md)。

<details>
<summary>维护者：生成并验证插件导出</summary>

以下命令将当前 `main` 分支克隆到独立目录。导出目录需不存在或为空：

```bash
git clone --branch main https://github.com/menmer0859/omarchy-surface-restore.git "$HOME/.local/share/omarchy-surface-restore-dev"
python3 "$HOME/.local/share/omarchy-surface-restore-dev/modules/face-auth/scripts/export-setup-plugin.py" --output /tmp/surface-face-setup
omarchy plugin validate /tmp/surface-face-setup
```

</details>

## 隐私与恢复

人脸匹配由 Howdy 在本机完成。录入模型保存在 `/etc/howdy/models/`；提交 issue 或代码时，请勿包含模型、摄像头画面或系统备份。

### 风险与开放问题

| 问题 | 说明 |
| :-- | :-- |
| sudo 或应用会自动启动人脸识别吗？ | 必须先在终端或界面明确同意。锁屏与唤醒遵循上文规则。 |
| 安全能力等同于 Windows Hello 吗？ | 本项目集成 Howdy、PAM 与 Omarchy，不宣称具备同等级的防伪能力。 |
| 取消后能保证相机立即停止吗？ | 结束界面/PAM 请求，不能证明独立运行的 Howdy matcher 已释放摄像头。 |
| 可以恢复之前的配置吗？ | 安装器在 `/var/backups/omarchy-surface-restore` 保存快照，可检查并恢复对应模块。 |

**已知限制：** 不保证 matcher 与摄像头立即释放。**待验证：** 其他 Surface 型号和其他 Omarchy 版本。**待完成：** 发布独立插件仓库并申请插件目录上架。具体边界见[行为约定（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md)与[分发指南（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/face-setup-plugin-distribution.md)。

### 恢复之前的配置

更改认证配置时，请保留一个可用终端。检查并恢复人脸模块快照：

```bash
"$HOME/.local/share/omarchy-surface-restore/scripts/restore.sh" --module face-auth
```

恢复操作还原已保存的配置，不会卸载软件包或降级内核、Quickshell。只删除配置组件，也不会移除已经安装的系统认证配置。

## 参与改进

欢迎在 [GitHub Issues](https://github.com/menmer0859/omarchy-surface-restore/issues) 提交可复现的问题。请附 Surface 型号、Omarchy 和 Quickshell 版本、出问题的认证场景，以及脱敏后的诊断信息。其他 Surface 型号的成功记录和明确的失败记录，都有助于补全兼容性信息。

开发检查运行 `bash "$HOME/.local/share/omarchy-surface-restore/tests/run.sh"`；额外的运行时验证方式见[插件指南（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md#verification)。

基于 [linux-surface](https://github.com/linux-surface/linux-surface)、[Howdy](https://github.com/boltgolt/howdy) 与 Omarchy 插件接口构建。本项目是社区集成。

## 文档与路径索引

| 指南 | 内容 |
| :-- | :-- |
| [人脸认证](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/README.zh-CN.md) | 安装、可选接入、升级与恢复 |
| [触摸屏](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/touch/README.zh-CN.md) | 内核安装、重启验证与恢复 |
| [插件行为（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/plugin-development.md) | 锁屏与唤醒规则、交互、多语言及已知限制 |
| [插件分发（开发分支，英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/codex/omarchy-face-setup-wizard/docs/face-setup-plugin-distribution.md) | 独立导出方式和发布状态 |
| [本机验收（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/docs/local-acceptance-fixes.md) | 已修复问题与手动复测场景 |
| [Quickshell 打包（英文）](https://github.com/menmer0859/omarchy-surface-restore/blob/main/modules/face-auth/packaging/quickshell-polkit-restart/README.md) | 返回人脸选择页所需 API 及兼容运行时 |

## 许可证

[MIT](https://github.com/menmer0859/omarchy-surface-restore/blob/main/LICENSE)。
