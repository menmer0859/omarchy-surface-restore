# Surface Laptop 5 + Omarchy：系统级人脸认证调研与实施计划

> 调研日期：2026-10-05。本文是待审方案；本轮只读取配置和上游资料，没有修改系统认证、安装软件或启用新入口。目标是在适用的本机认证场景中提供一致的人脸与密码选择，而不是声称 Linux/Howdy 能复制 Windows Hello 的全部安全架构。

> 状态更新（2026-10-06）：本仓库加入锁屏人脸一次性尝试策略：secure 后需新的用户意图，单次最长 12 秒，失败需显式重试；Polkit 失败反馈回到密码框。`tests/run.sh` 自动化检查通过。此次变更没有部署到本机；锁屏相机次数、休眠中断、Polkit 图形回退和终端实时体验均仍待 Surface Laptop 5 实测。Surface Laptop 8 未验证。下方 2026-10-05 的“自动锁屏扫描”描述是旧决策，已由本段和“当前状态”表格取代。

## 结论

旧版锁屏行为和交互式终端 `sudo` 曾在本机验证；本次锁屏一次性触发改动尚未实测。图形程序弹出的全屏管理员密码框属于 **Polkit**：Omarchy 的 Quickshell 授权界面接收 Polkit 请求，Polkit 再通过名为 `polkit-1` 的 PAM 服务认证。它不调用 `sudo`，所以现有的 `sudo` 人脸设置对这个场景无效。这是第三种场景仍只显示密码的直接原因。

下一步应把“明确选择人脸或密码”做成 Polkit 的完整认证流程：Omarchy 图形提示提供两个清晰入口；PAM 层在收到明确的人脸选择**之后**才启动 Howdy；拒绝、超时、摄像头故障和识别失败均回到密码。不能仅在图形上增加按钮，因为 Quickshell 收到请求时就会启动 PAM 会话；如果 PAM 直接运行 Howdy，摄像头会在用户点击前启动。[Quickshell 0.3.1 Polkit 流程](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/)说明了这一时序。

“系统级”在这里指以认证入口为单位覆盖 PAM 和 Polkit，而不是修改每个软件的密码框。任何自行管理密码、密钥或加密数据的应用，都不能靠一条全局 PAM 规则自动接入人脸。[Polkit 架构文档](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)也把应用授权、图形代理和本机认证分为不同层。

## 这台机器的现状与证据

| 入口 | 本机观察 | 影响 |
| --- | --- | --- |
| Omarchy 锁屏 | 用户插件调用独立的 `omarchy-lock-face` PAM，保留密码服务；旧版曾实机验证 | 旧版“锁屏自动尝试/失败持续重试”已废弃；新实现要求 secure 后的用户意图，单次最长 12 秒，失败后显式重试；新行为尚未实机验证 |
| 终端 `sudo` | `/etc/pam.d/sudo` 调用本项目的同意 helper；用户已验证 `n` 走密码、`y` 显示 `Identified face` | 已满足“管理员操作先明确同意”的要求；成功认证可能被 `sudo` 缓存 |
| 图形管理员提示 | Omarchy 4.0.4 的 `/usr/share/omarchy/shell/plugins/polkit/PolkitAgent.qml` 使用全屏 `PanelWindow`，当前把输入交给 `AuthFlow.submit()`，界面只有密码交互 | 需要改 Omarchy 用户插件及 Polkit PAM；全屏外观本身不是故障 |
| Polkit PAM | 本机仅有软件包提供的 `/usr/lib/pam.d/polkit-1`，其 `auth` 直接包含 `system-auth`；尚无 `/etc/pam.d/polkit-1` | 当前走通用密码认证，未接入 Howdy。Linux-PAM 允许用同名 `/etc/pam.d/` 文件覆盖 vendor 文件，实施时应保留原件与回滚路径，不能直接改 `/usr/lib`。[Linux-PAM 配置手册](https://man7.org/linux/man-pages/man5/pam.conf.5.html) |
| 图形登录 | 本机 SDDM 配有自动登录 | 当前开机时通常不会出现登录认证；如要开机也使用人脸，需另行审视自动登录、SDDM 界面与 PAM，不能把它算作已经覆盖 |

以上是对**本机文件和已完成的实机验证**的结论；尚未实际触发每一种图形提权动作，也尚未验证候选的 Polkit 人脸交互。因此“Polkit 方案可落地”目前是有依据的设计方向，仍须按下方第一阶段做小范围验证。

## 认证场景地图

| 场景与例子 | 实际入口 | 拟采用的行为 / 边界 |
| --- | --- | --- |
| 锁屏、空闲后恢复 | Omarchy 锁屏 + 专用 PAM | 新锁屏行为：锁定/secure 本身不启动摄像头；新的用户操作或用户唤醒插件熄灭的屏幕后触发一次识别；失败后只允许显式重试，密码可立即中断。 |
| 终端 `sudo`、经 `sudo` 安装软件 | `sudo` PAM | 保持现有 `[y/N]` 同意；无控制终端时保留密码或由调用程序自身处理。缓存未到期时不弹框属于正常行为。 |
| 图形软件安装、磁盘挂载/格式化、网络或系统设置、服务管理等**要求管理员授权的动作** | 如该动作通过 Polkit，则是 `polkit-1` PAM + 图形认证代理 | 目标是统一出现“使用人脸 / 使用密码”；只对确实走 Polkit 且要求认证的动作生效。已有授权或政策允许的动作不会弹框。 |
| `pkexec`、桌面外的 Polkit 请求 | Polkit，可能使用文本代理 `pkttyagent` | 若 PAM 对话在文本代理中可用，允许文本选择；否则安全地回退密码。不能假设 Omarchy 图形按钮总在场。 |
| 开机图形登录、切换用户 | SDDM PAM；本机当前自动登录 | 单独的可选阶段：先明确是否关闭自动登录，再验证 SDDM 的认证对话及密码回退；人脸登录后还须检查密钥环是否仍要求密码。 |
| 本机 TTY 登录、`su`、`passwd` / 用户管理 | 各自的 PAM 服务；`passwd` 还涉及更改凭据 | 不放入首批；逐项确认身份语义后再决定是否适合人脸。尤其不能把“验证当前用户”误当成“验证另一管理员”或“更改密码”。 |
| SSH、远程会话、无人值守服务 | 远程 PAM 或无交互入口 | 不启用本机摄像头人脸认证；保留各自凭据。远程请求不应在有人看屏幕时触发本地面容认证。 |
| 开机磁盘解密、LUKS、固件密码 | 启动链/加密解锁，不是正常桌面 PAM/Polkit | Howdy 摄像头栈尚未可用，需继续使用密码或另外研究 TPM/FIDO2 等专用机制。 |
| 密钥环、SSH/GPG 私钥、浏览器/应用保险库、网页账号 | 各应用的加密密钥或身份提供者 | 不属于管理员 PAM 授权；是否支持生物识别取决于应用、FIDO2/WebAuthn 或密钥架构，不能通过改 `polkit-1` 解锁。 |

特别注意 Polkit 有“认证会话本人”和“认证管理员”两种语义；不同动作可要求不同身份，且某些授权会临时缓存。人脸必须匹配 Polkit 当前选择的身份，不能固定按桌面登录用户的模型来授权另一位管理员。[Polkit 授权与缓存语义](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)、[Quickshell `selectedIdentity`/`submit()` 接口](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/AuthFlow/)。

## 推荐的 Polkit 实施设计（待验证）

1. **保留策略层。** 不通过添加“一律允许”的 Polkit 规则跳过身份校验；软件仍按原政策决定是否需要管理员、由谁认证。
2. **保留服务边界。** 新增独立的 `/etc/pam.d/polkit-1` 本机覆盖，复用现有 `system-auth` 的密码、账户和会话处理，必要时按原 PAM 控制流维护 `faillock`。不向全局 `system-auth` 直接加入 Howdy；这样不会意外影响 SSH、TTY、`su` 和其他 PAM 服务。
3. **把同意放进 PAM 对话。** 首先由 PAM 对话请求“使用人脸吗”；只有明确肯定才继续 Howdy，否则进入密码流程。现有 `sudo` helper 依赖控制终端 `PAM_TTY`，图形 Polkit 没有同等终端，不能原样复用。优先研究是否可用现有、可审计的 PAM 对话模块表达该选择；若不行，再评估一个很小的专用 PAM 模块。Linux-PAM 提供 `pam_prompt()` 对话接口，[Quickshell 的 `AuthFlow` 支持多轮输入](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/)，但两者与 Howdy、失败回退一起工作的细节还需原型验证。[Linux-PAM `pam_prompt` 手册](https://www.man7.org/linux/man-pages/man3/pam_prompt.3.html)。
4. **把选择呈现在可信的图形代理中。** 使用 Omarchy 的插件克隆机制修改用户级 Polkit 插件，不编辑 `/usr/share/omarchy/` 的内置文件。只有在 PAM 发出同意提示时，按钮才提交相应的对话响应；人脸成功后关闭提示，失败后明确转入密码。显示要执行的动作与当前认证身份，避免只凭一个泛化的“管理员操作”提示做决定。
5. **默认保持密码可用。** 没有面容模型、用户选密码、没有本地摄像头、识别超时或服务异常时，应能完成原本的密码认证；取消授权则直接取消动作。所有高权限文件改动先备份，提供一键恢复到密码专用 Polkit 的路径。

可选的简单做法是在 `polkit-1` 直接放置 `pam_howdy.so`，但由于 Quickshell 会立即启动 PAM 对话，这会在用户点击前开始人脸识别，违反此前确认的“管理员操作先主动选择人脸”要求，因此**不推荐**。仅改 QML 而 PAM 仍只收密码，也不能真正完成授权。

## 分阶段执行计划（本轮不实施）

1. **可行性关口。** 在可恢复、限定范围的测试中证明：Polkit 的 PAM 对话确实能先停在“人脸 / 密码”选择；未选择时摄像头不启动；所选身份正确传给 Howdy；拒绝、超时和错误能进入密码。若这一步不能可靠完成，先回报技术阻碍，不扩大 PAM 改动。
2. **本机图形授权。** 克隆 Omarchy Polkit 插件；建立并备份 `/etc/pam.d/polkit-1`；实现按钮、清晰提示、身份选择和密码回退。仅覆盖 Polkit，不触动已正常运行的锁屏、`sudo` 和全局 PAM。
3. **跨入口验证。** 逐项触发至少两类图形动作及 `pkexec`，检查同意前摄像头关闭、点击人脸成功、选密码成功、识别失败回退、取消、错误身份、无模型、相机不可用、授权缓存与并发请求；回归锁屏和 `sudo`。修改认证文件期间保留已认证终端和可启动的回滚手段。
4. **可选扩展。** 根据实际需求决定是否取消 SDDM 自动登录，并单独设计图形登录、用户切换和密钥环处理。TTY/`su`/`passwd` 按服务逐项评估；远程、磁盘加密和应用保险库保持独立机制。
5. **项目发布。** 只有在实机通过后才把安装/恢复脚本、测试、版本兼容说明和故障排查更新到 GitHub。对其他 Omarchy/Surface 版本先进行能力检测，不写死这台机器的用户名、摄像头节点或面容数据。

验收重点是**没有任何管理员人脸认证在用户明确选择前启动**，并且密码、取消和恢复始终可用。无提示并不一定是故障：`sudo` 和 Polkit 都可能缓存既有授权，测试时需明确排除缓存影响。

## Windows Hello 对标的实际边界

体验上可以追求“系统登录/解锁/本机提权有一致的人脸入口和密码回退”。安全架构上，Howdy 是接入 Linux PAM 的软件人脸匹配；Windows Hello 还涉及 Windows 生物识别框架、设备支持的红外与防伪机制，以及在适用场景下与设备绑定的密钥和 TPM。[Microsoft 的人脸认证说明](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/windows-hello-face-authentication)、[Windows Hello 密钥架构](https://learn.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-how-it-works)。Howdy 项目也明确警告其安全性不能与密码等同，不能作为系统唯一认证方式。[Howdy 安全说明](https://github.com/boltgolt/howdy#-a-note-on-security)。因此目标是接近 Windows Hello 的**本机交互覆盖面**，同时如实保留密码和各独立安全边界。
