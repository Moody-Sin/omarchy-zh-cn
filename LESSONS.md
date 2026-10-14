# 经验教训

## 不要硬编码 `/usr/share/omarchy`

Omarchy 可能从开发检出运行：`omarchy` 命令在 PATH 上指向 `/home/<user>/omarchy/bin/omarchy`，
而 `/usr/share/omarchy` 仍是旧包版本。此时读包目录会得到过期的菜单与脚本，且不会报错。

解析顺序应为：`OMARCHY_PATH` → PATH 上 `omarchy` 所在目录的上一级 → `/usr/share/omarchy`。
`omarchy-plugin-catalog` 已经用 `OMARCHY_PATH`，插件克隆天然是对的，但菜单、更新脚本、
快捷键面板和测速组件需要自己解析，容易漏。判断依据：目录下存在 `shell/plugins`。

## 上游会合并或删除脚本

`omarchy-system-logout` / `-reboot` / `-shutdown` 被合并成 `omarchy system <action>`。
同步器对"找不到脚本"直接抛错，会导致整次汉化失败。应对：缺失就跳过，并删除上一版生成的
副本——否则私有 bin 目录里的旧命令会继续遮蔽上游新命令。

## 验证汉化结果时不要拿英文原值比中文值

菜单是扁平 ID 键（`trigger.appearance.dock`），不是嵌套结构。判断"是否漏翻"要按 ID 取
汉化后的值再判断它是否仍是纯英文，且与英文原值对比无意义（本来就该不同）。专有名词
（应用名、语言名、品牌）保留英文是预期行为，统计时要先排除，否则噪声淹没真实缺口。

## 改完仓库里的同步器要重新同步才能看到效果

已安装的副本在 `~/.local/bin/omarchy-zh-sync`，直接跑 `omarchy-zh-sync` 用的是它。
验证时要么用 `node bin/omarchy-zh-sync`，要么先 `cp` 过去。

## 扫描"残留英文"要认属性名，不能只认 text:

写检查脚本时容易只扫 `text:`，漏掉 `meta:`、`tooltip:`、`placeholderText:`、`label:`、
`message:`、`buttonText:`。曾据此误判——明明已汉化却报"缺失"，手工验证又是通过，浪费时间。
另外断言里的属性名必须跟生成结果一致（例如 `meta: "同步已暂停"` 不是 `text:`），
报错先用 `rg -n` 看实际行，再写断言。

## 上游会把 `…` 写成字面 `\u2026`

世界时钟等文件里是反斜杠 + `u2026` 六字节，不是真省略号字符。同步器的全局替换按
`JSON.stringify` 比较字面量，两者在 JS 里 `"…"` 与 `"\u2026"` 相等但文件字节不同，
所以**都匹配不到**。这类字符串要在克隆阶段按原文字节替换。

## 上游文案会静默变更，导致汉化失效

`Hold F9 to dictate` 被改成 `Hold Right Alt or F9 to dictate …`。旧映射还在表里但永远
不命中，界面直接回退英文，**没有任何报错**。定期把上游 `bin/` 里的通知文案抽出来，
跟本地化映射做差集比对，比人工翻 QML 可靠。

## 汉化"拼接字符串"要保留动态部分

`"Do you want to delete " + 名称 + "?"` 这类，只能翻译固定前缀和末尾标点，中间的运行时
值必须留在拼接里。而且中文要在变量名两侧补空格：`无法完成 reboot` 不能写成 `无法完成reboot`。

## 新增插件克隆要同步四处

`install.sh` 的 `PLUGIN_IDS`、同步器的 `pluginIds`、README 与 README.en 的"创建 N 个
插件克隆"、两个测试里的数量断言。漏一处就会测试红或被 UI 计数打脸。

## 测试否定断言切忌裸写 `! cmd`

在开启 `set -e` 的 Bash 脚本中，直接裸写 `! grep ...` 或 `! rg ...` 会因为 `!` 操作符
反转退出码导致 `errexit` 机制被旁路忽略，即使匹配到非法字符串脚本也会继续执行并伪通过。
必须使用显式的 `if cmd; then echo "断言失败" >&2; exit 1; fi` 辅助函数（如 `refute`）
严格保证负向契约有效，并在 CI 中集成 `shellcheck` 静态拦截。

## 通知汉化正则不能用后行断言 `(?<=...)`

Quickshell 的 Qt V4 引擎**不支持后行断言**，而且失败是静默的：含 `(?<=...)` 的正则
整条失效，连其中本可工作的前瞻分支 `\bMay\b(?=\s+\d{1,2}\b)` 也一起不再匹配。
曾据此把 `May` 规则合并成 `(?<=\b\d{1,2}\s+)May\b|\bMay\b(?=\s+\d{1,2}\b)`，
结果国际日期没修好，反而把原本正常的 `May 15, 2026` 打回英文。

更麻烦的是 **Node 与 Qt V4 行为不一致**：同一正则 Node 完全正常，测试套件照样全绿，
所以这个问题只有真实运行时能暴露。改写此类规则时，用捕获组回引
`/(\b\d{1,2}\s+)May\b|\bMay\b(?=\s+\d{1,2}\b)/g → "$15月"`（非参与捕获组为空，
`$15月` 不会被误解析为组 15），不要用后行断言。

验证手段：本机跑着 Hyprland 时可直接用 `qs -p <dir>/shell.qml` 加载真实
`NotificationLocalization.js`，在 Qt V4 里断言结果，比 `node -e` 可信。

## `translate(value, appName)` 漏传 appName 会让断言空转

`NotificationLocalization.translate` 在 `appName !== "omarchy-action"` 时**原样返回**输入。
测试里写成 `translate("May I help you?")` 期望等于自身，等于恒真——无论汉化规则错成
什么样都会通过。凡是调用 `translate` 的断言，必须显式传 `"omarchy-action"`。

## 全局词典替换切忌误伤状态机枚举与逻辑比较

在向 `zh` 字典添加通用短词（如 `"Stopped": "已停止"`）时，如果某些插件的 `Service.qml`
中直接使用字面量作为系统守护进程返回的状态码判断（例如 `backendState === "Stopped"`），
全局替换会导致逻辑表达式被篡改为 `=== "已停止"`，从而破坏底层的状态机与事件流转。
凡是在全局字典中加入可能作为内部状态枚举的词汇，必须在对应的插件分支中显式恢复逻辑比较
（或在测试套件中通过正则反向断言严格拦截 `=== "中文"`），确保显示文案汉化与逻辑判断隔离。

