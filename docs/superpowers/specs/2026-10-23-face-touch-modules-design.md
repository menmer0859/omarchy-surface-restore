# Omarchy Surface Restore：人脸解锁与触摸模块设计

## 状态

设计已由用户于 2026-10-23 确认。此文定义下一阶段代码整合的边界；落地前仍需审阅实施计划。

## 目标

在现有 GitHub 仓库中提供两个可各自选择、安装、升级和恢复的功能模块：Surface 红外人脸解锁、Surface 触摸支持。人脸安装不得隐式添加 linux-surface 内核或触摸守护进程；触摸安装不得修改 PAM、Howdy、人脸模型或 Omarchy 认证 UI。

保持单一 Git 仓库、中英文文档和已有用户命令。避免要求已安装用户重录人脸或失去已有认证配置。

## 用户与模块行为

根 `install.sh` 仍作入口。用户可以直接选 face 或 touch；也可以沿用 `sudo-face`、`polkit-face`、`plugin-ui` 这些现存细分命令。老的 `all` 明确定义为旧行为，即 touch + 首次 face 配置，不暗中添加 sudo/Polkit 配置。交互菜单同时清晰展示两个主模块及人脸可选能力。

人脸模块包含 2.1 Omarchy 锁屏插件、面部模型/Howdy/PAM 配置、双语共用 UI、可选终端 sudo 同意、可选图形 Polkit 同意和匹配版本的 Quickshell 补丁/能力检查。UI 更新与初次后端配置继续区别说明。触摸模块只配置签名来源、linux-surface 内核/headers 和 iptsd，并保留 Omarchy 内核回退。

两个主模块可独立安装，也可同机共存。推荐的模块目录是 `modules/face-auth/` 与 `modules/touch/`；`lib/` 放真正共享的备份、检查、路径与恢复函数。根安装器调用模块入口。可先由根入口兼容原脚本路径，避免重构造成用户升级断路。

## 仓库边界

建议目标结构：

```text
install.sh
README.md
README.zh-CN.md
lib/
  common.sh
  restore.sh
modules/
  face-auth/
    install.sh
    README.md
    README.zh-CN.md
    assets/
    scripts/
    packaging/quickshell-polkit-restart/
    tests/
  touch/
    install.sh
    README.md
    README.zh-CN.md
    scripts/
    tests/
tests/run.sh
```

实际可按文件性质保留独立入口和公共根测试，但目标须满足同样的职责隔离。仅移动文件而不调整资源相对路径、源码发现、测试 root、restore 识别、打包 patch、文档链接不算完成。

测试按行为模块化。锁屏/Polkit/Howdy/i18n/Quickshell 检查属于 face-auth；签名来源/内核包/iptsd 属于 touch；全仓的旧 CLI 转发、模块之间不互相触发、共同备份格式兼容测试属于根集成层。

## 兼容策略

以下调用必须保留且有自动覆盖：

- `./install.sh touch`
- `./install.sh face`
- `./install.sh sudo-face`
- `./install.sh polkit-face`
- `./install.sh plugin-ui`
- `./install.sh check`
- `./install.sh all`

兼容路径转发到模块实现，不重复维护两份安装逻辑。当前首次 face 不自动配置 sudo 或 Polkit，继续保持分别选择。`all` 保持历史 touch + face 含义，新增/变更菜单须写清后端组件与确认步骤。

保留已有安装的插件发现能力，不能假设目录名称是某个用户、`surface.lock` 或旧 `eclipse.lock`；拒绝冲突或不受管克隆。升级 UI 不重复录入模型或覆盖 PAM。共享 restore 能读取已有快照格式；新增快照记载模块身份，使两个模块恢复互不删除对方文件。已经存在的系统全局文件例如 `/etc/pam.d/sudo` 必须按本模块备份前后差异恢复，不简单删除。

## 数据与系统变更约束

Howdy 模型、相机图像和私人机器配置不得进入仓库或日志。二进制包不纳入源码 Git。安装日志不能收集用户密码。PAM 更新使用校验和管理标记；所有变更保持回滚路径。触摸安装不调用面部入口，面部安装不调用触摸入口。摄像头设备规则只允许 Howdy 所需设备，不放宽整台 helper 的全设备访问。

Quickshell 的 `restartAuthentication()` 是 Polkit 返回脸验证的原生依赖。将本轮 `quickshell-polkit-restart` 配方保留在人脸模块，记录源码提交和校验；安装前检查系统版本/能力，不盲目覆盖更新发行包。旧 Quickshell 仍保留可用密码路径并隐藏不支持的返回动作。不要将已有的 0.3.1 配方当作新默认。

实测能力仍以 Surface Laptop 5、对应 Omarchy/Quickshell 版本为准。硬件矩阵每条支持声明都要匹配实际证据；recipe 中包含架构名称不等于该硬件通过测试。

## 安装器契约

每个模块有自己的 usage、前置检查、变更摘要、用户确认、备份标记和完成信息。主入口负责模块选择/旧 CLI dispatch，不执行重复业务。`check` 汇报设备、OS、运行时及依赖，但只读。

人脸主安装允许用户选择/分阶段启用锁屏、sudo、图形 Polkit。每条路径准确描述涉及的 PAM、Howdy、UI、摄像头设备权限和可撤销快照。没有可识别的 IR 设备或支持能力时明确失败，不猜测 `/dev/video0`。触摸主安装只加入已校验的 linux-surface 签名 key/repo、内核/headers/iptsd，说明 `pacman -Syu` 可能更新其他系统包、保留 stock kernel 和用户需要重启。

已有 `restore.sh` 用法保持兼容；恢复交互可以增加模块筛选。回滚 sudo/Polkit/lock 分别验证文件此前存在与新建两种情形。共享函数只收纳真实共用逻辑，不为减少目录数强行抽象。

## 文档要求

根中英 README 是模块选型首页，明确只需 IR face 或 touch 的用户分别运行什么。各模块 README 说明依赖、系统变更、安装、验收、升级、卸载/恢复。人脸文档准确地区分锁屏/PAM、sudo、Polkit，不能宣称接管所有需要管理员密码的应用；列出 Howdy matcher 取消后摄像头释放等已知限制。

记录实际验证版本：Surface Laptop 5 与当前已装版本；旧 Omarchy 4.0.4 内容标为历史基线或更新，不要和本机 4.5.0rc1 实测混淆。双语 UI 已完成不代表所有项目文档、依赖提示或第三方认证消息均已翻译。把本轮安装和用户多轮总体满意写入依据，不推测未逐项报告的验收结果。

保留用户未提交的研究/验收文档，先判断隐私和公开价值，不因模块化重构丢失或未经审核批量公开原始采集材料。清除 README 中“未部署/未验证”的过期主述，同时保留事实受限条件。

## 验收条件

1. 独立运行 face 流程不执行触摸包安装、repository 或 iptsd 命令；独立 touch 不触碰 PAM/Howdy/model/plugin 文件。
2. 根旧 CLI 和主菜单全部转发到新模块；`all` 保持既有含义，未知参数报用法错误。
3. 安装一个模块后安装另一模块，两者共存；各自重复升级/分别恢复不会破坏另一模块。
4. 受管插件升级找到现存目录、完整部署共享 UI/i18n 资源，并拒绝重复克隆、符号链接或非受管目标。
5. Face UI、终端、Polkit、原生 Quickshell restart 行为、touch installer fixture 分别仍通过原有测试；重构后的测试入口从根目录可执行。
6. 从空目录、已有旧版本、人脸已录入但未配置 sudo/Polkit、备份恢复、缺驱动/缺相机和版本不匹配模拟器覆盖关键路径。
7. 所有相对资源和 patch 路径在源 checkout 与用户安装场景均稳定；本机 live 安装不依赖仓库保持原位置。
8. 双语 README/模块说明与实际 CLI、依赖、权限、回退及实机证据一致。
9. 最终变更不含人脸模型、图像、credentials、worktree、构建包或本机备份。
10. 完成后进行代码差异审阅，记录实际测试和未覆盖场景。远端 push/PR/merge 作为独立发布步骤，不属于模块文件布局的验收。
