# 更新记录

本项目遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## 0.4.0 - 2026-10-14

### 修复与补全

- **端到端测试与质量防护网全面重构与补齐**：
  - 彻底消灭测试盲区：为此前 0 覆盖的 `omarchy.reminders`（提醒流）和 `omarchy.polkit`（权限认证）插件补充完整端到端测试断言，并在 Node.js 中对 `PolkitModel.authorizationLabel` 执行真实调用断言。
  - 补齐弱覆盖插件核心文案断言：涵盖 `monitor`、`power`、`weather`、`system-update`、`image-picker`、`bluetooth`、`dock`、`tray`、`clock` 的关键 UI 文本。
  - 动态错误拦截函数（`localizedCommandError`）升级为执行级验证：在 `integration.sh` 中通过大括号平衡算法精准提取 `wifiqr`、`speedtest`、`disk-speedtest` 的函数体并传入 mock 数据求值，覆盖全部 9 条核心报错与 5 组动态正则，并验证未知错误原样透传。
  - 补强通知中心动态正则断言：在 `NotificationLocalization.js` 测试中增加 12 条高危动态正则用例（含进程崩溃、低电量预警、会话未锁屏、录屏/截图目录、默认应用变更、时区与工作区布局等）。
  - 新增全量生成 JS 文件的 AST/VM 语法编译自检：递归扫描沙箱中由 25 个插件生成的全量 `.js` 文件，剥离 QML 专有顶层指令（`.pragma` 与 `.import`）后通过 `vm.compileFunction` 编译，杜绝语法损坏风险。
  - 增强安装卸载生命周期（`install-cycle.sh`）严密性：补充 `--dry-run` 零副作用断言（无文件与目录残留且保证有预览输出）、安装幂等性断言（重复安装不膨胀配置，绑定块严格单份）、卸载零残留断言（插件目录下 `testuser.*` 严格为 0）。
- **架构与脚本健壮性及安全修复**：
  - 修复卸载脚本 `uninstall.sh` 在恢复天气单位时 jq 过滤器缺失空值保护的致命缺陷：增加 `((.id // "") | endswith(".weather"))` 兜底，防止微件对象缺少 `.id` 属性时以退出码 5 崩溃中断卸载流程。
  - 修复 `bin/omarchy-zh-sync` 的 `syncShellSettings` 缺少微件非空防御的问题：遍历时增加 `if (widget && ...)` 守卫，杜绝格式异常导致的 Node.js TypeError。
  - 修复 Codex shim 仅支持空格分隔与 `--ask-for-approval=untrusted` 的问题：扩展支持 `-a=untrusted` 等内联参数形态。
  - 修复 Grok 收集器在预付余额刚好为 0 时被判定为 None 从而隐藏余额的问题：将判定范围放宽至 `remaining >= 0`。
  - 增强 Codex 收集器上游脚本寻找机制：优先通过 `$OMARCHY_PATH/bin` 探测开发检出中的脚本。
  - 消除 Kimi 收集器中非标准 `os.sys.stderr` 写法，重构为标准 `import sys`。
  - 补齐 Dropbox 插件 10 条动态同步文案（`正在归档文件`、`正在分发数据`、`正在整理文件夹`等）及开关操作提示（`暂停同步` / `恢复同步`）。
  - 补齐 Elsewhen 世界时钟微件的 7 项配置项 Schema 标签说明。
  - 修正 Tailscale 状态机逻辑比较保护：避免全局替换篡改底层 `backendState === "Stopped"` 枚举值。
  - 补全源码目录标准文档规范：为 `bin/`、`hooks/`、`tests/` 添加符合标准的 `README.md`，并将 `.planning/` 录入 `.gitignore`。
  - 修复测试套件否定断言失效缺陷：将 `tests/integration.sh` 与 `tests/install-cycle.sh` 中的裸 `! cmd` 断言统一重构为严格校验的 `refute` 函数，杜绝因 `set -e` 旁路导致负向测试契约伪通过的问题；并在 `smoke.sh` 及 CI 工作流中集成 `shellcheck` 静态检查。
  - 修复 `usage-update` 脚本在 `--except` 缺少对应参数时的参数越界与未绑定变量崩溃异常（提前防御退出），并优化排除项判定。
  - 同步器补齐 `USER` 环境变量合法性正则校验，与 `install.sh` 保持防御一致，杜绝潜在目录跨越隐患。
  - `menuUser` 写入升级为原子写入（`tmp` + `rename`），防止断电或信号中断产生破损配置。
  - 修正通知月份替换：同时支持国际日期格式（`15 May 2026` → `15 5月 2026`）与美式日期格式（`May 15, 2026`），并继续避免误伤情态动词 `May`。注意实现刻意不使用后行断言 `(?<=...)`：Quickshell 的 Qt V4 引擎不支持后行断言，且失败是静默的（整条正则连同前瞻分支一起失效，反而破坏 `May 15` 的既有汉化），故改用捕获组回引 `"$15月"`。
  - 修复音频模型正则中的 `Microphones` 词元在全局替换中被篡改为中文的问题，保证内部规范化逻辑正常执行。
  - 修正夜灯指示器提示（`Day Light`）为动作语义的 `关闭夜灯`：该文案是夜灯已开启时的 `activeTooltipText`，与同族指示器（`Allow Notifications`、`Stop recording`）一致应为动作导向，此前的 `日间模式` 系状态与动作语义倒置。
  - 修复 `install.sh` 收尾阶段的致命崩溃：无图形会话（`HYPRLAND_INSTANCE_SIGNATURE` 为空）时不再调用 `hyprctl`；`hyprctl reload` 在无会话下返回退出码 3 也不再触发 `set -euo pipefail` 中止，配置校验失败仍会如实报错退出。
  - 修复 `uninstall.sh` 恢复天气单位时 jq 表达式在配置缺失 `.bar.layout` 或其为 `null` 时以退出码 5 崩溃（`Cannot iterate over null`）的问题：取值与回写两处均加可选链 `?` 与类型守卫，损坏或不完整的 `shell.json` 不再中断卸载流程。
  - 消除上游脚本路径硬编码：`usage-update` 与 `codex-collector` 改为先经 `command -v` / 环境变量 `OMARCHY_CODEX_COLLECTOR` / `shutil.which` 动态查找上游可执行文件，仅在查找失败时回退 `/usr/bin/omarchy-agent-usage-*`，适配非标准前缀的上游安装。
  - 补强通知汉化测试契约：新增 `15 May 2026` 与 `May 15, 2026` 双向日期格式断言；同时修正既有情态动词 `May` 断言漏传 `appName` 导致 `translate` 提前返回、断言恒真空转的缺陷。
- **安装器兼容性增强**：
  - 修复开发工作区（Dev Checkout）环境下 `omarchy version` 输出 `dev (<hash>)` 导致安装器版本检查误拒的问题：安装器现能自动追溯解析并读取开发检出中的真实版本文件，确保开发环境与正式包一致平滑安装。
- **顶栏指示器与微件漏译**：
  - 补齐免密码 Sudo 指示器提示与通知：`Disable Passwordless Sudo`（禁用免密码 sudo）、`Passwordless Sudo`（免密码 sudo）、`Could not disable passwordless sudo`（无法禁用免密码 sudo）、`Check the sudo configuration and try again.`（请检查 sudo 配置并重试。）。
  - 补齐麦克风状态提示：`Microphone muted`（麦克风已静音）、`Microphone in use`（麦克风正在使用）、`Microphone live`（麦克风已开启）。
  - 修复远程会话指示器动态拼接漏译：将 `Remote session from ...` 汉化为 `来自 ... 的远程会话`。
  - 补齐时钟微件右键提示：`Right-click to toggle format`（右键点击切换时间格式）。
- **AI 助手（`omarchy.agents`）面板全量动态语法与文案修复**：
  - 修复状态展示：`Sign-in expired`（登录已过期）、`Waiting for auth`（等待身份认证）、`Limits paused`（额度统计已暂停）、`The sign-in didn't finish.`（登录未完成。）、`Add an account`（添加账户）、`Subscriptions`（订阅与额度）。
  - 修复动态额度与时长拼接缺陷：将 `Add an ${provider} account` 汉化为 `添加 ${provider} 账户`；将 `free reset(s)` 汉化为 `次免费重置`；将 `next expires in` 汉化为 `下次过期倒计时：`；将 `spent of ... funded` 汉化为 `已消耗 ... / 已注入 ...`；将 `estimated` 汉化为 `预估`；将 `tokens this week/today` 汉化为 `本周/今日 ... 词元`；将 `Mostly ...` 汉化为 `主要模型：...`；将 `Busiest day: ...` 汉化为 `用量最高的一天：...` 并同步将星期转换为中文；将 `prompts/sessions today` 汉化为 `今日 ... 次提问/会话`；将 `Merged from ... devices` 汉化为 `已合并来自 ... 台设备的数据`。
  - 本地化快速启动卡片（Starter Prompts）：将默认英文主题、插件与应用开发 Prompt 替换为地道、优质的中文提示词。
- **Dropbox 与 Tailscale 插件操作提示补齐**：
  - 修复 Dropbox 容量展示拼接：`used of quota` 规范为 `已用 ... / 共 ...`。
  - 补齐 Dropbox 相对时间格式化（`刚刚`、`分钟前`、`小时前`、`天前`、`个月前`、`年前`、`未知时间`）。
  - 补齐 Dropbox 与 Tailscale 操作状态与错误弹窗（操作员授权、节点列表拉取失败、登录失败、命令执行失败等）。
- **快捷键（`keybindings`）覆盖与术语统一**：
  - 补齐上游全部 27 个原生快捷键缺失动作汉化：`Toggle full screen desktop`（切换桌面全屏）、`Capture highlighted window`（截取高亮窗口）、`Capture entire screen`（截取整个屏幕）、`Select (next/previous) window to capture`（选择截图窗口/上一个/下一个）、`Select all`（全选）、`Switch input language (back)`（切换/反向切换输入语言）、`Cycle workspace layout (back)`（轮换/反向轮换工作区布局）、`Direct input for the terminal prefix`（直接输入终端前缀）、`Minimize window to the dock`（将窗口最小化到程序坞）、`Toggle transparency on a window`（切换窗口透明度，修复上游命名不匹配导致的漏译）、`World clock`（世界时钟）、`Apps`（应用）、`Zoom in (JIS + key)`（放大（JIS + 键））、Google 系列应用等，实现上游 193 项快捷键 100% 汉化覆盖。
  - 统一动态顶栏术语：将 awk 动态替换中的 `状态栏面板` 修正为规范的 `顶栏面板`。
- **菜单（Menu）对齐与规范化**：
  - 统一安装与卸载菜单项名称对齐：`install/remove.ai.hermes`（Hermes 桌面版）、`remove.ai.chatgpt`（ChatGPT 桌面版）、`remove.ai.claude`（Claude 桌面版）、`remove.ai.grok-bot`（Grok 机器人）。
  - 规范学习菜单项名称：`learn.tmux-keybindings`（Tmux 快捷键）、`learn.herdr-keybindings`（Herdr 快捷键）。
  - 统一安全密钥与代理命名：`setup.security.ssh-agent` 对齐为 `SSH 代理`；FIDO2 相关菜单项规范为 `FIDO2 安全密钥`。
- **面板微件与极客文案润色**：
  - 补齐 Elsewhen 世界时钟城市条（`CityRow.qml`）删除按钮悬浮提示：`Remove`（移除）。
  - 补齐 AI 助手面板（`Panel.qml`）授权添加状态：`Starting…`（正在启动…）、`Checking the code…`（正在校验验证码…）。
  - 补充设置菜单中默认 Agent 的 Cursor CLI 标签：`setup.default.agent.cursor-agent`（Cursor CLI）。
  - 补齐 Elsewhen 世界时钟日照条（`DaylightStrip.qml`）日出与日落标记汉化：`Sunrise`（日出）、`Sunset`（日落）。
- **通知中心与极客文案润色**：
  - 补充 `NotificationLocalization.js` 缺失通知精确匹配（免密码 sudo 失败、FIDO2 认证处理、Taildrop 传输失败等）。
  - 润色蓝牙状态趣味文案（`正在召唤耳机`、`正在打磨数据包`、`正在联络维京海盗（蓝牙）`、`正在召唤扬声器`、`正在驯服无线电`、`正在解开虚拟线缆`、`正在调教编解码器`）。

## 0.3.0 - 2026-10-13

### 修复

- 修复上游 `install.service.1password` 菜单占位符泄漏问题：上游原生菜单将 1Password 服务标签硬编码为 `1Password`，现已在 `menuZh` 中清洗并显式声明为正确服务名称。
- 修复 AI 助手 (`omarchy.agents`) 面板多处漏译与动态拼接：顶栏返回额度与添加订阅提示、多账户自动切换与手动使用按钮、数据未更新状态，以及紧凑用量卡片悬停详情（已用百分比、重置倒计时、最后更新时间、额度占比），彻底消除英文残留。
- 修复 Dropbox 插件在未安装 CLI 或未登录状态下的英文界面残留（登录入口、未安装 CLI 说明、引导认证与服务菜单安装说明）。
- 修复 Tailscale 插件开关状态、设备授权、出口节点选择、底层服务通知及 10 条链路扫描极客趣味文案漏译。
- 修复网络面板大标题中的强制门户与网络受限状态标签（`SIGN-IN REQUIRED`、`LIMITED INTERNET ACCESS`）。
- 修复无线频段锁定标签拼接黏连问题：将 `Stay on ` 规范为带尾部空格的 `固定使用 `。
- 修复世界时钟悬停提示与本地时间拼接语法（`It's ... here` 替换为 `本地当前时间为 ...`）。
- 修复日历面板周起始提示语拼接生硬问题：将 `Start weeks on ` 调整为符合中文习惯的 `将周起始日设为 `。
- 清理 `NotificationLocalization.js` 中重复定义的 `Voxtype Dictation Ready` 键及多余的 `Theme not applied everywhere` 正则分支。

### 优化与调整

- 统一桌面“顶栏/状态栏”术语体系：快捷键面板 `Toggle top bar` 统一对齐为“切换顶栏”。
- 规范平铺窗口调整快捷键动作描述：将“从左侧/上方收缩窗口”规范为“收缩窗口左侧/上方”。
- 润色系统设置菜单文案：将 `setup.security.sudoless-docker` 润色为更自然的“免 sudo 运行 Docker”。
- 清理 `menuZh` 中 13 处因上游菜单重构而废弃的历史遗留死代码键。
- 润色蓝牙扫描、网络监测与电源能耗状态下的趣味极客文案（保留维京海盗、光信号折射、比特连接与阶梯耗电等幽默风味）。

## 0.2.0 - 2026-10-13

### 修复

- 修复卸载后残留中文版 `omarchy-system` 遮蔽上游同名命令的问题：上游把注销、重启、关机合并为 `omarchy system`，卸载器此前只清理已被删除的 `omarchy-system-reboot`，导致重启和关机会执行一份陈旧的汉化脚本。现在同时清理合并前后的四种写法。
- 修复安装时不备份 `~/.config/hypr/bindings.lua` 的问题。该文件是追加写入的，一旦标记行被用户改动或写入中断，原先没有原始副本可回滚；现在首次安装会留下备份，卸载时按标记剥离失败则回退到安装前内容（当前内容仍另存为备份）。
- 修复同步器与安装器状态目录不一致的问题：同步器用 `~/.local/state/omarchy-zh`，而安装器与卸载器用 `~/.local/state/omarchy-zh-cn`，卸载后会在用户目录留下无人管理的残留。现已统一为后者。
- 修复语音输入就绪提示的汉化失效问题：上游文案已从 `Hold F9 to dictate` 改为 `Hold Right Alt or F9 to dictate (or toggle with Super + Ctrl + X).`，同步器按新文案重新匹配。
- 修复 CI 上集成检查与安装周期检查“假通过”的问题：这两个脚本在非 Omarchy 环境下静默 `exit 0`，而 GitHub Runner 没有 Omarchy，因此从未真正校验任何内容。现在跳过时会显式说明未执行，CI 也把它拆成独立任务，跳过状态在检查列表里可见。

### 新增汉化

- 补齐 AI 助手面板此前整块遗漏的 18 处文案：入门引导、添加账户流程（命名说明、验证码确认与粘贴提示、重新打开登录页）、额度与用量展示（余额、使用中、用量不可用）、悬浮提示等。
- 补齐状态指示器插件两项未汉化的设置项：免密码 sudo、远程会话及其说明。
- 新增四个插件的汉化克隆：程序坞右键菜单（自动隐藏、新建窗口、保留/移出、退出、打开、卸载、搜索应用、方位选项）、Tailscale 连接面板（连接、出口节点、设备、地区搜索、授权操作员）、Dropbox 同步面板（最近的文件、同步已暂停、已用容量）与世界时钟界面（世界、时钟、添加/搜索城市、加载提示）。插件克隆数量由 21 个调整为 25 个。
- 补齐通知汉化：动画开关、背景动画、免打扰状态、Herdr 主题同步、主题未完全应用、语音输入就绪（含 Superwhisper）、操作失败、添加账户失败、设备账户切换、录制音频缺失等。其中带 shell 变量或用 `.failed` 结尾的文案改用模式匹配，运行时按实际值展开。
- 修正世界时钟省略号文案的汉化：上游把 `…` 写成字面 `\u2026`（反斜杠加 `u2026`，不是省略号字符），全局替换按 JSON 字面量比较匹配不到，改为在克隆时按原文字节替换。

### 其他

- 集成检查新增断言：四个新克隆插件的关键文案、AI 助手面板此前遗漏的条目、通知本地化映射表（含“非 Omarchy 通知不翻译”的反向断言），以及城市名与多语言问候语必须保留原文的保护断言。
- 安装周期检查新增断言：卸载后不得残留 `omarchy-system` 等私有脚本、不得留下旧状态目录、绑定块标记被破坏时能回滚到安装前内容。
- 补充 `.gitignore`：Python 缓存、虚拟环境与本地同步临时产物。

### 本次一并包含此前未发布的改动

- 修复 Omarchy 从开发工作区运行时汉化内容停留在旧版本的问题：同步器原先硬编码读取 `/usr/share/omarchy`，而 `omarchy` 命令可能来自开发检出。现按 `OMARCHY_PATH`、PATH 上的 `omarchy`、包目录的顺序解析真实安装根，菜单、更新脚本、快捷键面板与测速组件都从同一来源读取；两个测试脚本也使用同样的解析顺序。
- 兼容上游把 `omarchy-system-logout`、`omarchy-system-reboot`、`omarchy-system-shutdown` 合并为 `omarchy system <注销|重启|关机>`：新增 `omarchy-system` 的翻译，并让同步器跳过上游已删除的脚本、同时清理上一版残留的副本，避免私有目录里的旧命令继续遮蔽新命令。
- 补齐开发版新增的 60 多个菜单项翻译：程序坞与顶栏（位置、背景、指示器、电池百分比）、窗口圆角与透明度、窗口间距、工作区布局、动画、Herdr 主题同步、输入法与键盘布局、默认语音输入、Antigravity 与 Ori、Voxtype 与 Superwhisper、SSH 代理、Claude 桌面版等。
- 时钟格式示例按中文习惯改写（如 `星期日 14:30`、`2026年5月3日 第18周`），而不是逐字翻译英文示例；ISO 与 24 小时制时间保留数字格式。
- 集成检查改为同时接受合并后的 `omarchy-system` 与合并前的 `omarchy-system-reboot`。
- 修复安装后“应用”子菜单为空的问题：不再克隆 `omarchy.menu`，菜单中文改由用户级 `omarchy-menu.jsonc` 承担，原生菜单直接读取，应用列表恢复正常；安装与同步时自动移除旧版本留下的菜单克隆并恢复原生菜单。
- 修复全局字符串替换误伤代码逻辑的问题：DNS 服务商（Custom）、日历与网络面板 W 快捷键、音频 PipeWire 类型判断（Output/Source）恢复英文协议值，展示层单独映射中文；此前点击 DNS“自定义”会执行错误命令。
- 补齐菜单翻译：更新通道 Edge（前沿版）、卸载 AI 标题、免 sudo Docker（设置与卸载）。
- 插件克隆数量由 22 个调整为 21 个；菜单根标题通过配置显式汉化为“开始”。
- 新增集成检查：协议值位置不得出现中文的断言，防止同类回归。
- 修复电源模式标签定位失效导致同步中断的问题：新版 Omarchy 在模式标签前加了 `root.managedByWindows ? … :` 三元表达式，锚点去掉 `text: ` 前缀后重新匹配。
- Agents 状态栏新增 Grok Build 与 Kimi Code 的订阅用量和限额展示。
- 为 Grok、Kimi 增加随 Omarchy 主题切换的浅色与深色图标。
- 兼容新版 Codex CLI 的审批策略，并延长 app-server 初始化等待时间。
- 安装与更新后同步会自动重新应用 Agents 扩展；卸载时一并清理。

## 0.1.0 - 2026-08-20

- 首次公开版本。
- 汉化 22 个 Omarchy 4 用户插件克隆。
- 汉化主菜单、快捷键面板和 Omarchy 动态通知。
- 日期与星期使用 `zh_CN` 区域格式。
- 天气默认使用摄氏度和 `km/h`。
- 增加安装、卸载、更新后同步和静态检查脚本。
