# 交接：Omarchy Surface 人脸与触摸模块

日期：2026-10-23。仓库：`menmer0859/omarchy-surface-restore`。

## 目标与范围

同一仓库中提供两个独立安装模块：`modules/face-auth` 恢复 Omarchy 红外人脸认证，`modules/touch` 恢复 Surface 触摸。用户明确批准此模块边界及实施计划。人脸模块不安装 Surface 内核；触摸模块不修改 Howdy、PAM 或人脸插件。根目录旧命令继续兼容。`./install.sh all` 继续旧语义：先触摸模块，再进行首次人脸配置，不自动启用可选 sudo/Polkit。

架构说明：[模块设计](superpowers/specs/2026-10-23-face-touch-modules-design.md)；实施计划：[模块拆分计划](superpowers/plans/2026-10-23-face-touch-modules.md)。本分支工作是本地代码与文档整合；未推送 GitHub、创建/更新 PR、合并或更改本机 PAM/系统配置。

## 入口与目录

| 功能 | 用户命令 | 核心位置 |
| --- | --- | --- |
| IR 人脸与锁屏 UI | `./install.sh face` | `modules/face-auth/install.sh`、`modules/face-auth/assets/`、`modules/face-auth/scripts/` |
| 可选终端 sudo | `./install.sh sudo-face` | face 模块的 sudo PAM/helper 安装器 |
| 可选图形 Polkit | `./install.sh polkit-face` | face 模块的 Polkit UI/PAM/device helper |
| 已安装 UI 更新 | `./install.sh plugin-ui` | 仅部署现有人脸插件 UI |
| Surface 触摸 | `./install.sh touch` | `modules/touch/install.sh` |
| 只读环境检查 | `./install.sh check` | 根入口 |
| 旧组合入口 | `./install.sh all` | 触摸，然后首次人脸安装 |

共用备份与恢复实现位于 `lib/common.sh`、`lib/restore.sh`。新快照带有 `face-auth` 或 `touch` 标签，可用 `./scripts/restore.sh --module face-auth` 或 `--module touch` 过滤；旧的无标签快照不能猜模块归属，需用未过滤恢复命令逐项查看。旧 `scripts/` 命令保留兼容入口，不应在两个模块中复制第二份实现。

当前和旧版 Quickshell 配方均归人脸模块所有：`modules/face-auth/packaging/quickshell-polkit-restart/` 与 `modules/face-auth/packaging/quickshell-xdg-session/`。前者针对验证过的固定源码提交，不能盲目降级更新的系统包。构建的 package、源树、Howdy 人脸模型、本地摄像头配置和备份都不能提交。

## 测试与交付边界

主测试入口为 `bash tests/run.sh`。完整运行后把实际结果、跳过项和依赖限制追加到 `docs/plugin-development-progress.md`，不要沿用此前模块化前的测试数量。其他相关检查：

```bash
bash modules/face-auth/tests/compile-services.sh
python3 -m unittest discover -s modules/face-auth/tests -p 'test_polkit*_package.py'
git diff --check
```

在 Omarchy 主机上，`tests/run.sh` 还会尝试离屏 QML 检查；Quickshell 原生回归需要显式提供该配方准备出的源码目录。`shellcheck` 不存在时，记录为 skipped，不能描述为通过。测试/构建只能验证代码，不代表摄像头、休眠、真实 sudo/Polkit 与每一款 Surface 已完成实机验收。

真实硬件基线为 Surface Laptop 5、Omarchy 4.5.0rc1、Quickshell 0.3.2.r7.g2b4501a-2。用户报告 UI 2.1 经多轮实际使用后整体满意；未逐项确认的场景仍按未逐项记录处理。其他 Surface 型号及版本要单独测试。Howdy matcher 在 PAM 中断后是否立即释放摄像头仍有限制，不能承诺硬件断电时限或 Windows Hello 同级防伪能力。

## 操作约束

- 不读取、复制或提交 `/etc/howdy/models/`、用户照片、密码、认证日志、系统 PAM 文件或 root 备份。
- 仅模块安装器在用户确认后才改系统；本次模块重构不触发安装器。
- GitHub 推送、PR 更新或合并需以用户对该具体远端操作的授权为准。
- 集成结束前检查 Git 变更列表，确保没有 `pkg/`、`src/`、二进制包、相机帧或忽略数据进入版本控制。
