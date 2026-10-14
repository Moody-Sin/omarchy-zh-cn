#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# Omarchy may run from a dev checkout instead of the packaged install, so the
# same resolution order as the syncer is used here.
omarchy_path=${OMARCHY_PATH:-}
if [[ -z $omarchy_path ]] && command -v omarchy >/dev/null 2>&1; then
  resolved=$(
    cd -- "$(dirname -- "$(command -v omarchy)")/.." 2>/dev/null && pwd
  ) || resolved=
  [[ -n ${resolved:-} && -d $resolved/shell/plugins ]] && omarchy_path=$resolved
fi
omarchy_path=${omarchy_path:-/usr/share/omarchy}

if [[ ! -d $omarchy_path/shell || ! -x $omarchy_path/bin/omarchy-menu-keybindings ]]; then
  echo "非 Omarchy 环境（找不到 $omarchy_path/shell 或 omarchy-menu-keybindings），集成检查未执行。"
  echo "CI 上这会显示为通过但没有真正校验任何内容；请在 Omarchy 4 机器上运行 ./tests/smoke.sh。"
  exit 0
fi

sandbox_home=$(mktemp -d)
cleanup() {
  [[ -n ${sandbox_home:-} && -d $sandbox_home && $sandbox_home == /tmp/* ]] && rm -rf -- "$sandbox_home"
}
trap cleanup EXIT

mkdir -p "$sandbox_home/.local/share/fcitx5/rime/opencc"
printf '笑脸\t笑脸 😀\n汽车\t汽车 🚗\n' \
  >"$sandbox_home/.local/share/fcitx5/rime/opencc/emoji.txt"

HOME="$sandbox_home" USER=testuser \
  "$ROOT_DIR/bin/omarchy-zh-sync" --quiet --no-restart

plugin_root="$sandbox_home/.config/omarchy/plugins"
plugin_count=$(find "$plugin_root" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l)
[[ $plugin_count -eq 25 ]] || {
  echo "生成的插件数量不正确：$plugin_count" >&2
  exit 1
}
# 菜单插件不再克隆：第三方菜单拿不到应用库，中文改由菜单配置承担。
test ! -e "$plugin_root/testuser.menu" || {
  echo "不应再生成菜单插件克隆" >&2
  exit 1
}

while IFS= read -r manifest; do
  jq -e '.omarchy.zhCnManaged == true and (.omarchy.clonedFrom | startswith("omarchy."))' \
    "$manifest" >/dev/null
done < <(find "$plugin_root" -mindepth 2 -maxdepth 2 -name manifest.json | sort)

menu_file="$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
node - "$menu_file" "$sandbox_home" <<'NODE'
const fs = require("fs")
const [menuPath, home] = process.argv.slice(2)
const raw = fs.readFileSync(menuPath, "utf8")
  .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
  .replace(/,(\s*[}\]])/g, "$1")
const menu = JSON.parse(raw)
if (Object.keys(menu).length < 318) throw new Error("菜单项目数量不足")
for (const [id, label] of Object.entries({
  apps: "应用",
  setup: "设置",
  install: "安装",
  remove: "卸载",
  system: "系统"
})) {
  if (menu[id].label !== label) throw new Error(`${id} 菜单未汉化`)
}
if (menu["learn.keybindings"].label !== "快捷键") throw new Error("快捷键菜单未汉化")
if (menu["root"].label !== "开始") throw new Error("根菜单标题未汉化")
if (menu["update.channel.edge"].label !== "前沿版") throw new Error("Edge 通道未汉化")
if (menu["remove.ai"].title !== "卸载") throw new Error("AI 卸载标题未汉化")
if (menu["install.service.1password"].label !== "1Password") throw new Error("1Password 占位符未修正")
if (menu["setup.security.sudoless-docker"].label !== "免 sudo 运行 Docker") throw new Error("免 sudo Docker 未汉化")
if (menu["remove.security.sudoless-docker"].label !== "免 sudo 运行 Docker") throw new Error("移除免 sudo Docker 未汉化")
if (menu["setup.security.ssh-agent"].label !== "SSH 代理") throw new Error("SSH 代理设置未对齐")
if (menu["setup.security.fido2"].label !== "FIDO2 安全密钥") throw new Error("FIDO2 设置未汉化")
if (menu["remove.security.fido2"].label !== "FIDO2 安全密钥") throw new Error("FIDO2 移除未汉化")
if (menu["learn.tmux-keybindings"].label !== "Tmux 快捷键") throw new Error("Tmux 快捷键菜单未汉化")
if (menu["learn.herdr-keybindings"].label !== "Herdr 快捷键") throw new Error("Herdr 快捷键菜单未汉化")
if (menu["remove.ai.chatgpt"].label !== "ChatGPT 桌面版") throw new Error("ChatGPT 移除未汉化")
if (menu["remove.ai.claude"].label !== "Claude 桌面版") throw new Error("Claude 移除未汉化")
if (menu["remove.ai.grok-bot"].label !== "Grok 机器人") throw new Error("Grok 机器人移除未汉化")
if (menu["install.ai.hermes"].label !== "Hermes 桌面版") throw new Error("Hermes 安装未汉化")
if (menu["remove.ai.hermes"].label !== "Hermes 桌面版") throw new Error("Hermes 移除未汉化")
if (menu["learn.keybindings"].action !== home + "/.local/bin/omarchy-menu-keybindings-zh") {
  throw new Error("快捷键入口路径不正确")
}
if (menu["update.omarchy"].action !== "omarchy-launch-floating-terminal-with-presentation " + home + "/.local/bin/omarchy-update-zh") {
  throw new Error("系统更新入口路径不正确")
}
NODE

node - "$sandbox_home" <<'NODE'
const path = require("path");
const home = process.argv[2];
const { translate } = require(path.join(home, ".config/omarchy/plugins/testuser.notifications/components/NotificationLocalization.js"));
// 注意必须传 appName="omarchy-action"：translate 对非 Omarchy 通知原样返回，
// 漏传会让断言恒真而空转。
if (translate("May I help you?", "omarchy-action") !== "May I help you?") {
  console.error("情态动词 May 误伤测试失败：", translate("May I help you?", "omarchy-action"));
  process.exit(1);
}
// 国际日期格式（日在前）与美式日期格式（月在前）都必须汉化。
for (const [input, expected] of [
  ["15 May 2026", "15 5月 2026"],
  ["May 15, 2026", "5月 15, 2026"]
]) {
  const actual = translate(input, "omarchy-action");
  if (actual !== expected) {
    console.error(`月份未汉化：${input} -> ${actual}（期望 ${expected}）`);
    process.exit(1);
  }
}
NODE

rg -Fq '重新登录 ' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '在新的' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '返回额度' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '添加订阅' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '自动切换' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '使用此账户' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '停止自动切换' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '用量数据尚未更新' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '已用' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '重置倒计时：' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '次免费重置' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '已消耗 ' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '词元' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '主要模型：' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '用量最高的一天：' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '已合并来自 ' "$plugin_root/testuser.agents/Panel.qml"

rg -Fq '登录 Dropbox' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq '未安装 Dropbox CLI' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq '开始身份认证流程' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq '从服务菜单安装 Dropbox' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq '已用 ' "$plugin_root/testuser.dropbox/Model.js"
rg -Fq '刚刚' "$plugin_root/testuser.dropbox/Model.js"

rg -Fq '日出' "$plugin_root/testuser.elsewhen/DaylightStrip.qml"
rg -Fq '日落' "$plugin_root/testuser.elsewhen/DaylightStrip.qml"

rg -Fq '开启 Tailscale' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq '关闭 Tailscale' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq '授权此设备' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'Tailscale 已断开连接' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq '选择 Mullvad 地区' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq '正在加密网络连接' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq '需要登录' "$plugin_root/testuser.tailscale/Service.qml"
rg -Fq '正在授权 Tailscale 操作员…' "$plugin_root/testuser.tailscale/Service.qml"

rg -Fq '需要登录网络' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '网络访问受限' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '固定使用 ' "$plugin_root/testuser.network/Panel.qml"

rg -Fq 'tooltipText: "世界时钟"' "$plugin_root/testuser.elsewhen/Panel.qml"
rg -Fq '本地当前时间为 ' "$plugin_root/testuser.elsewhen/Panel.qml"

rg -Fq '将周起始日设为 ' "$plugin_root/testuser.clock/Panel.qml"
rg -Fq '收缩窗口左侧' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq '切换顶栏' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq '全选' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq '轮换工作区布局' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq '顶栏面板' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"

rg -Fq '禁用免密码 sudo' "$plugin_root/testuser.indicators/indicators/PasswordlessSudo.qml"
rg -Fq '来自 ' "$plugin_root/testuser.indicators/indicators/RemoteSession.qml"

rg -Fq '"scrolling": "滚动布局"' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq 'Qt.locale("zh_CN")' "$plugin_root/testuser.weather/Panel.qml"
rg -Fq '"power-saver": "节能", "balanced": "平衡", "performance": "性能"' \
  "$plugin_root/testuser.power/Panel.qml"
rg -Fq 'text: rowRoot.isPinned ? "取消固定" : "固定"' "$plugin_root/testuser.tray/Tray.qml"
rg -Fq 'text: rowRoot.isHidden ? "显示" : "隐藏"' "$plugin_root/testuser.tray/Tray.qml"
rg -Fq '搜索剪贴板…' "$plugin_root/testuser.clipboard/Clipboard.qml"
rg -Fq 'cancelText: "取消"' "$plugin_root/testuser.clipboard/Clipboard.qml"
rg -Fq ' 个文件' "$plugin_root/testuser.clipboard/ClipboardHistory.js"
rg -Fq '，时间：' "$plugin_root/testuser.clipboard/ClipboardHistory.js"
rg -Fq '搜索表情…' "$plugin_root/testuser.emojis/Emojis.qml"
node - "$plugin_root/testuser.emojis/emojis.json" <<'NODE'
const items = require(process.argv[2])
const byEmoji = new Map(items.map(item => [item.e, item.k]))
if (!byEmoji.get("😀")?.includes("笑脸")) throw new Error("笑脸中文关键词缺失")
if (!byEmoji.get("🚗")?.includes("汽车")) throw new Error("汽车中文关键词缺失")
if (!byEmoji.get("🧑")?.includes("人物")) throw new Error("人物兜底关键词缺失")
if (!byEmoji.get("🚊")?.includes("有轨电车")) throw new Error("交通工具兜底关键词缺失")
NODE
rg -Fq '关闭无线网络' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '隐藏网络' "$plugin_root/testuser.network/Panel.qml"
rg -Fq 'return "自动"' "$plugin_root/testuser.network/Model.js"
rg -Fq '正在连接…' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '正在扫描设备…' "$plugin_root/testuser.bluetooth/Panel.qml"
rg -Fq '|| "设备"' "$plugin_root/testuser.bluetooth/Panel.qml"
rg -Fq '正在验证…' "$plugin_root/testuser.lock/LockView.qml"
rg -Fq "$plugin_root/testuser.agents/bin/usage-update" "$plugin_root/testuser.agents/Main.qml"
jq -e '.barWidget.defaults.providers.grok.enabled == true and .barWidget.defaults.providers.kimi.enabled == true' \
  "$plugin_root/testuser.agents/manifest.json" >/dev/null
for collector in codex codex-collector grok-collector kimi-collector usage-update; do
  test -x "$plugin_root/testuser.agents/bin/$collector"
done
test -f "$plugin_root/testuser.agents/assets/grok.svg"
test -f "$plugin_root/testuser.agents/assets/grok-light.svg"
test -f "$plugin_root/testuser.agents/assets/kimi.svg"
test -f "$plugin_root/testuser.agents/assets/kimi-light.svg"
# 状态指示器此前有两条遗漏的设置项标签。
jq -e '
  [.barWidget.schema[0].options[] | select(.label == "免密码 sudo")] | length == 1
' "$plugin_root/testuser.indicators/manifest.json" >/dev/null
jq -e '
  [.barWidget.schema[0].options[] | select(.label == "远程会话")] | length == 1
' "$plugin_root/testuser.indicators/manifest.json" >/dev/null
# 通知文案的补齐与修正：语音输入提示语上游改过，旧的 F9 版本已失效。
node - "$plugin_root/testuser.notifications/components/NotificationLocalization.js" <<'NODE'
const { translate } = require(process.argv[2])
const cases = {
  "Animations enabled": "动画已启用",
  "Background Intros": "背景动画",
  "Enabled": "已启用",
  "Herdr theme sync disabled": "Herdr 主题同步已禁用",
  "Theme not applied everywhere": "主题未完全应用",
  "Superwhisper Dictation Ready": "Superwhisper 语音输入已就绪",
  "Hold Right Alt or F9 to dictate (or toggle with Super + Ctrl + X).": "按住右 Alt 或 F9 开始听写（或按 Super + Ctrl + X 切换）。",
  "Could not complete reboot. Please try again.": "无法完成 reboot，请重试。",
  "Recording without microphone audio": "未录制 microphone 音频",
  "Battery is down to 15%": "电池电量已降至 15%"
}
for (const [input, expected] of Object.entries(cases)) {
  const actual = translate(input, "omarchy-action")
  if (actual !== expected) throw new Error(`通知未汉化：${input} -> ${actual}`)
}
// 非 Omarchy 发出的通知不翻译。
if (translate("Animations enabled", "other-app") !== "Animations enabled") {
  throw new Error("非 omarchy-action 的通知被误译")
}
NODE
rg -Fq ' · 当前' "$plugin_root/testuser.monitor/Panel.qml"
for speed_plugin in speedtest disk-speedtest; do
  rg -Fq 'text: "再次测试"' "$plugin_root/testuser.$speed_plugin/SpeedTestOverlay.qml"
done
rg -Fq '无法获取测速节点' "$plugin_root/testuser.speedtest/Panel.qml"
rg -Fq '测速未完成' "$plugin_root/testuser.disk-speedtest/Panel.qml"
rg -Fq 'function localizedCommandError' "$plugin_root/testuser.wifiqr/Panel.qml"
rg -Fq '没有正在使用的无线网络连接' "$plugin_root/testuser.wifiqr/Panel.qml"
# 新增克隆的四个插件：程序坞、Tailscale、Dropbox、世界时钟。
rg -Fq 'text: "自动隐藏"' "$plugin_root/testuser.dock/DockWindow.qml"
rg -Fq '确定要卸载 ' "$plugin_root/testuser.dock/AppGrid.qml"
# Agents 面板的账户与用量文案此前整块遗漏，这里做回归断言。
rg -Fq 'text: "做点有意思的东西"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'text: "需要登录"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'text: "余额"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'text: "使用中"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'text: "用量不可用"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq '重新登录 " + (section.provider' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'text: "指纹读取器不可用"' "$plugin_root/testuser.lock/LockView.qml"
rg -Fq 'text: "打开强制门户"' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '确定要删除 ' "$plugin_root/testuser.image-picker/ImagePicker.qml"
rg -Fq 'text: "连接"' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'text: "出口节点"' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'text: "设备"' "$plugin_root/testuser.tailscale/Panel.qml"
rg -Fq 'text: "最近的文件"' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq ': "同步已暂停"' "$plugin_root/testuser.dropbox/Panel.qml"
rg -Fq 'text: "世界"' "$plugin_root/testuser.elsewhen/HeroTitle.qml"
rg -Fq 'text: "时钟"' "$plugin_root/testuser.elsewhen/HeroTitle.qml"
rg -Fq 'placeholderText: "搜索城市' "$plugin_root/testuser.elsewhen/CitySearch.qml"
rg -Fq 'buttonText: "+  添加城市"' "$plugin_root/testuser.elsewhen/CitySearch.qml"
rg -Fq 'buttonText: "跳转到城市"' "$plugin_root/testuser.elsewhen/Globe.qml"
rg -Fq 'tooltipText: "移除"' "$plugin_root/testuser.elsewhen/CityRow.qml"
rg -Fq 'addStatus = "正在启动…"' "$plugin_root/testuser.agents/Panel.qml"
rg -Fq 'addStatus = "正在校验验证码…"' "$plugin_root/testuser.agents/Panel.qml"
# 城市名与品牌名保持原文，不能被汉化。
rg -Fq 'label: "Tokyo"' "$plugin_root/testuser.elsewhen/Model.js"
rg -Fq 'title: "Dropbox"' "$plugin_root/testuser.dropbox/Panel.qml"
# 全球问候语是功能数据（按各地语言显示），必须保留原文。
rg -Fq 'text: "Good morning"' "$plugin_root/testuser.elsewhen/Greetings.js"
# 协议值保持英文、仅展示汉化：DNS 服务商、W 快捷键、音频类型判断。
rg -Fq 'dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]' "$plugin_root/testuser.network/Panel.qml"
rg -Fq 'if (provider === "Custom")' "$plugin_root/testuser.network/Panel.qml"
rg -Fq 'provider: "Custom"' "$plugin_root/testuser.network/Panel.qml"
rg -Fq '{ "Custom": "自定义" })[provider] || provider' "$plugin_root/testuser.network/Panel.qml"
refute() {
  if "$@"; then
    echo "断言失败（预期不应匹配）：$*" >&2
    exit 1
  fi
}

refute rg -Fq 'provider === "自定义"' "$plugin_root/testuser.network/Panel.qml"
refute rg -Fq 't === "周"' "$plugin_root/testuser.clock/Panel.qml" "$plugin_root/testuser.network/Panel.qml"
refute rg -Fq 'indexOf("输出")' "$plugin_root/testuser.audio/Model.js"
refute rg -Fq 'indexOf("音源")' "$plugin_root/testuser.audio/Model.js"
refute rg -Fq '/\bMicrophones\b/g, "麦克风"' "$plugin_root/testuser.audio/Model.js"
rg -Fq '/\bMicrophones\b/g, "Microphone"' "$plugin_root/testuser.audio/Model.js"
rg -Fq 'backendState === "Stopped"' "$plugin_root/testuser.tailscale/Service.qml"
refute rg -Fq 'backendState === "已停止"' "$plugin_root/testuser.tailscale/Service.qml"
rg -Fq '"Filing files": "正在归档文件"' "$ROOT_DIR/bin/omarchy-zh-sync"
rg -Fq '"Zones (Label|IANA name, comma separated; blank seeds on first run)": "显示时区' "$ROOT_DIR/bin/omarchy-zh-sync"
rg -Fq '"Not installed": "未安装"' "$ROOT_DIR/bin/omarchy-zh-sync"
python3 - "$plugin_root" <<'PY'
import re, pathlib, sys
root = pathlib.Path(sys.argv[1])
pat = re.compile(r'(===?|!==?)\s*"[^"]*[\u3400-\u9fff]|(indexOf|includes|startsWith|endsWith)\(\s*"[^"]*[\u3400-\u9fff]')
bad = []
for path in sorted(root.rglob('*')):
  if path.is_dir() or path.suffix not in ('.js', '.qml'):
    continue
  if path.name == 'NotificationLocalization.js':
    continue
  for lineno, line in enumerate(path.read_text().splitlines(), 1):
    if pat.search(line):
      bad.append(f'{path.relative_to(root)}:{lineno}:{line.strip()[:120]}')
if (bad):
  print('逻辑比较位置出现中文：')
  print('\n'.join(bad))
  sys.exit(1)
PY
rg -Fq '拒绝使用不安全的显示器名称' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq '未找到 " + match[1] + " 在工作区 "' \
  "$plugin_root/testuser.notifications/components/NotificationLocalization.js"
rg -Fq "$sandbox_home/.local/bin/omarchy-update-zh" \
  "$plugin_root/testuser.system-update/SystemUpdate.qml"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
bash -n "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"

update_helpers=(
  omarchy-update omarchy-update-pkg-prune omarchy-update-lock
  omarchy-update-requires-free-space omarchy-snapshot omarchy-update-keyring
  omarchy-pkg-add
  omarchy-update-system-pkgs
  omarchy-update-system-pkgs-when-conflicted omarchy-migrate
  omarchy-update-aur-pkgs omarchy-update-mise omarchy-update-orphan-pkgs
  omarchy-update-restart omarchy-update-dev omarchy-update-stay-awake
  omarchy-update-analyze-logs omarchy-hook
  omarchy-restart-shell
)
for helper in "${update_helpers[@]}"; do
  test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
  bash -n "$sandbox_home/.local/share/omarchy-zh-cn/bin/$helper"
done
rg -Fq '更新过程中出现错误！' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
rg -Fq '创建系统快照' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-snapshot"
rg -Fq '清理软件包缓存' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-pkg-prune"
rg -Fq '更新 Arch 签名密钥' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-keyring"
rg -Fq '错误：软件包“' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-pkg-add"
rg -Fq 'echo -e "\e[32m\n更新系统软件包\e[0m"' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-system-pkgs"
rg -Fq 'echo -e "\e[32m\n更新 AUR 软件包\e[0m"' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-aur-pkgs"
rg -Fq '正在运行迁移' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-migrate"
rg -Fq '更新 mise 管理的工具' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-mise"
rg -Fq '重启前请检查日志' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-analyze-logs"
rg -Fq '钩子执行失败：' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-hook"
# Upstream merged logout/reboot/shutdown into one `omarchy system` command and
# deleted the three standalone scripts, so accept either shape.
session_bin="$sandbox_home/.local/share/omarchy-zh-cn/bin"
if [[ -x $session_bin/omarchy-system ]]; then
  rg -Fq '正在重启' "$session_bin/omarchy-system"
  rg -Fq '正在关机' "$session_bin/omarchy-system"
else
  rg -Fq '正在重启' "$session_bin/omarchy-system-reboot"
fi
rg -Fq 'Omarchy Shell 重启后未能就绪' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-restart-shell"
rg -Fq -- '--affirmative "是" --negative "否" --no-show-help' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
refute rg -Fq 'Omarchy update in progress' \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-stay-awake"

if rg -n '/home/[[:alnum:]_.-]+|/Users/[[:alnum:]_.-]+' "$sandbox_home"; then
  echo "生成结果包含开发机器信息。" >&2
  exit 1
fi

# usage-update 在 --except 缺少参数时应安全报错退出
if "$ROOT_DIR/agents-overlay/bin/usage-update" --except 2>/dev/null; then
  echo "usage-update --except 缺少参数时未能防御退出" >&2
  exit 1
fi

echo "Omarchy 隔离集成检查通过。"
