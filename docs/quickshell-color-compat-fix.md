# Quickshell 主题颜色兼容修复（2026-10-25）

## 问题与诊断复核

用户报告安装人脸插件后，状态栏插件弹窗中的文字、排序按钮和进度条颜色异常。另一位 agent 的交接指出自建 Quickshell `0.3.2.r7.g2b4501a-2` 缺少 Omarchy 加载补丁。复核确认这个方向成立：当前二进制不识别 shell 的 `OmarchyLoadPatch` pragma，实际会话有 `Color.polkit`、`Color.notifications` 为 undefined 以及向 QColor 赋 undefined 的错误。

需要修正交接中的源码归因：官方 Omarchy 包同样使用 `quickshell-mirror/quickshell` 的提交 `2b4501a282689792b62e94f3fb30d8f512324fe6`，并不是必须切换到另一个 fork 仓库。差异是官方打包额外应用 `load_qtquick_611.patch`，之前的自建包漏带了它。

官方补丁明确处理 Qt 6.12 新增的 `QtQuick.Color` 单例。它与 Omarchy 的主题 `Color` 重名，导致使用未限定 `Color.*` 的插件解析到错误对象。补丁在标有 `OmarchyLoadPatch` 的配置中，将未指定版本的 `import QtQuick` 限定到 6.11，并处理动态加载的配置目录外组件。只设置 `Color` 默认颜色或更改主题会掩盖原因。

## 独立复现

新增 `modules/face-auth/tests/run-omarchy-load-compat.sh`，只创建临时 QML 对象，不启动实际锁屏、PAM 或摄像头。测试在 shell 配置目录内及目录外各加载一个使用 `Color.accent`、`Color.polkit` 的组件：

- 本机 Qt 6.12 + 当前 `-2` 二进制：失败，`OMARCHY_COLOR_COLLISION`，accent 为 undefined。
- 从 pacman 缓存独立解出的官方 `-1` 二进制：同一测试通过，`OMARCHY_LOAD_COMPAT_PASS`。

因此没有移动 familiar-desktop 的测试桩，也没有更改其他插件、主题或 shell 配置。测试中的独立主题模块不含该插件的测试桩，足以直接复现名称冲突。

## 修复内容与来源

本地配方升级为 `0.3.2.r7.g2b4501a-3.1`，保留固定源码归档和两个原有 Polkit 补丁，补回官方 loader patch，三份补丁都使用 fuzz=0 应用。Distributor 标注为 `Omarchy (Surface Restore Polkit restart)`，区分官方原包与本地修改。

来源：[官方配方](https://github.com/omacom/omarchy-pkgs/blob/master/pkgbuilds/quickshell/PKGBUILD)、[官方补丁](https://github.com/omacom/omarchy-pkgs/blob/master/pkgbuilds/quickshell/load_qtquick_611.patch)。补丁 Git blob 为 `660965b4907bcd67f8d810898c9db5f19d198917`，SHA-256 为 `23b65d205d825f11a1cd8501acbc6e50250d09a6ce607e2ff8b3cf5d438bd0ce`，原样纳入仓库，不依赖构建时获取可变分支内容。

## 验证和安装记录

构建完成。源码归档和三份补丁的 `makepkg --verifysource` 全部通过；新包解出的实际二进制通过主题名称冲突回归，完整测试通过（63 个 Python 测试、JS 策略、安装/恢复、PAM 编译、QML 语法、loader 回归与两组离屏 QML）。原生 Polkit restart 会话回归通过，独立只读审阅未发现需修改的问题。ShellCheck 未安装，未记为通过。

2026-10-25 16:48（Asia/Singapore），用户从自行打开的正常系统终端完成安装。Quickshell 及 debug 包均核对为 `0.3.2.r7.g2b4501a-3.1`，安装脚本退出码 0，shell 重启后 ping 返回 ok。工具第一次启动的终端继承了 `no-new-privileges`，在提权之前停止；没有更改系统隔离设置。

实际会话日志对比（同一电脑，重新打开硬件监控面板）：

| 检查 | 修复前 | 安装重启后 |
| --- | --- | --- |
| 不识别 OmarchyLoadPatch | 1 | 0 |
| undefined 赋值给 QColor | 140 | 0 |
| undefined 主题属性错误 | 29 | 0 |
| Polkit 代理注册 | 已注册 | 已注册 |

硬件监控面板截图中，CPU/RAM 仪表弧线、用量进度条、RAM/分组选择按钮均恢复主题色且文字可读。锁屏状态仍报告 face=true、passwordPam=true；新包下真实 Wayland 服务类型编译通过（只编译、不发起锁屏/认证）。本轮未重新进行一次真实人脸匹配或管理员授权，不将服务状态冒充匹配成功记录。

本地构建、截图与核验资料位于忽略目录 `work/omarchy-load-compat/`。发布源码不包含这些资料或二进制包。该次本地包 SHA-256：

```text
41842328cd547f4d763ac06b480cd8f32966e5ba047af02b8a1b616c98b3b5dd  quickshell-0.3.2.r7.g2b4501a-3.1-x86_64.pkg.tar.zst
9d05af72bb3a8a0d86c74c187541bdff43bd8b350657dd16885941131734db58  quickshell-debug-0.3.2.r7.g2b4501a-3.1-x86_64.pkg.tar.zst
```

修复仅涉及 Quickshell 包，不需要重新录入人脸、修改 PAM 或重装 UI。保留官方 `-1` 缓存包及本地 `-2` 作为恢复资料。若需回退，先在解锁的桌面和正常系统终端中安装已知包，再重启 shell；官方 `-1` 没有本项目的 Polkit 返回 API，界面会隐藏不支持的返回入口。
