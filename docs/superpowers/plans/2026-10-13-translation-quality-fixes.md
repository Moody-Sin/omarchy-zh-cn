# 完善 Omarchy 简体中文本地化与修复翻译缺陷 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复上游占位符泄露、QML 动态字符串拼接漏译、日历与网络拼接中文语法、清理菜单废弃键、统一“顶栏/状态栏”术语体系、去重通知逻辑并提升极客文案品质。

**Architecture:** 
1. 在 `bin/omarchy-zh-sync` 的 `menuZh` 中加入 `install.service.1password` 清洗与翻译，移除已失效的废弃菜单键。
2. 在 `bin/omarchy-zh-sync` 中针对 `omarchy.agents` 补充专用 QML 代码替换分支，解决动态拼接漏译。
3. 规范日历与网络面板的动态前缀替换规则，调整快捷键动作与顶栏术语一致性。
4. 清理 `NotificationLocalization.js` 中的重复键与多余正则。
5. 润色极客风味的趣味文案（蓝牙/网络/电源）。
6. 在 `tests/integration.sh` 添加新增项的回归断言，跑通全量测试。

**Tech Stack:** Node.js, Shell, QML, JSONC, Bash

**Spec:** 用户指令“全部实施”之前述全面评审报告。

## Global Constraints
- 必须全程使用简体中文。
- 称呼用户为老大。
- 严禁修改 `/usr/share/omarchy`，所有汉化基于用户级插件克隆与用户级配置。
- 遵循约定式提交（Conventional Commits）和 Keep a Changelog 格式更新 CHANGELOG.md。

## Review Focus
- 1Password 菜单项必须显示为真实服务名而非上游占位符 `1Password`。
- `omarchy.agents` 账户悬停提示和新项目启动提示必须为中文。
- `tests/smoke.sh` 必须无报错通过。
- 菜单总条目与已翻译条目逻辑兼容。

---

### Task 1: 修复高优先级翻译与漏译缺陷（1Password、Agents 动态拼接、日历与网络前缀）

**Files:**
- Modify: `bin/omarchy-zh-sync:110-1840`
- Test: `tests/integration.sh`

**Interfaces:**
- Consumes: `menuZh`, `syncPlugin()`
- Produces: 修复的 QML 插件与 `omarchy-menu.jsonc`

- [ ] **Step 1: 编写新增修复项的失败断言**
在 `tests/integration.sh` 中添加断言：
1. `menu["install.service.1password"].label` 为 `"1Password"`
2. `omarchy.agents` 的 Panel.qml 包含 `"重新登录 "` 和 `"启动默认 AI 助手"`
3. 日历 ToolTip 包含 `"将周起始日设为 "`

- [ ] **Step 2: 运行测试验证失败**
Run: `./tests/smoke.sh`
Expected: FAIL

- [ ] **Step 3: 在 `bin/omarchy-zh-sync` 中实现修复**
1. 在 `menuZh` 增加 `install.service.1password`: `{"label": "1Password"}`
2. 在 `bin/omarchy-zh-sync` 插件转换中增加 `omarchy.agents` 专用的拼接替换。
3. 修正日历与网络的前缀拼接：针对 clock Panel.qml 替换 `Start weeks on ` 为 `将周起始日设为 `；优化 `Stay on `。

- [ ] **Step 4: 运行测试验证通过**
Run: `./tests/smoke.sh`
Expected: PASS

- [ ] **Step 5: 提交**
```bash
git add bin/omarchy-zh-sync tests/integration.sh
git commit -m "fix: 修复 1Password 菜单占位符与 Agents 动态拼接漏译"
```

---

### Task 2: 统一顶栏术语、清理废弃菜单键与快捷键动词润色

**Files:**
- Modify: `bin/omarchy-zh-sync`
- Test: `tests/integration.sh`

- [ ] **Step 1: 增加术语与快捷键测试断言**
在 `tests/integration.sh` 验证：
- `keybindingZh` 中窗口收缩动作对齐为“收缩窗口左侧 / 上方”
- `Toggle top bar` 对齐为“切换顶栏”

- [ ] **Step 2: 运行测试验证失败**
Run: `./tests/smoke.sh`
Expected: FAIL

- [ ] **Step 3: 修改 `bin/omarchy-zh-sync`**
1. 统一顶栏术语（Top Bar -> 顶栏）。
2. 清理 `menuZh` 中已失效的 13 个废弃键。
3. 调整窗口调整方向词：`Shrink window left` -> `收缩窗口左侧`，`Shrink window up` -> `收缩窗口上方`。
4. 润色 Docker 选项：`setup.security.sudoless-docker` -> `免 sudo 运行 Docker`。

- [ ] **Step 4: 运行测试验证通过**
Run: `./tests/smoke.sh`
Expected: PASS

- [ ] **Step 5: 提交**
```bash
git add bin/omarchy-zh-sync tests/integration.sh
git commit -m "refactor: 统一顶栏术语并清理已失效菜单键"
```

---

### Task 3: 优化通知模块与极客文案，更新更新日志并闭环

**Files:**
- Modify: `bin/omarchy-zh-sync`
- Modify: `CHANGELOG.md`
- Test: `tests/smoke.sh`

- [ ] **Step 1: 清理 `NotificationLocalization` 重复键与正则**
去除 `Voxtype Dictation Ready` 重复键，去除冗余的 `Theme not applied everywhere` 正则。

- [ ] **Step 2: 润色趣味极客文案**
优化蓝牙、网络、电池等诙谐状态文案的翻译传神度。

- [ ] **Step 3: 运行全量测试**
Run: `./tests/smoke.sh`
Expected: PASS

- [ ] **Step 4: 更新 `CHANGELOG.md`**
记录本次评审与修复的所有具体条目。

- [ ] **Step 5: 提交**
```bash
git add bin/omarchy-zh-sync CHANGELOG.md tests/integration.sh
git commit -m "docs: 记录翻译缺陷修复与语言润色更新日志"
```
