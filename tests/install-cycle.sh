#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

omarchy_path=${OMARCHY_PATH:-}
if [[ -z $omarchy_path ]] && command -v omarchy >/dev/null 2>&1; then
  resolved=$(
    cd -- "$(dirname -- "$(command -v omarchy)")/.." 2>/dev/null && pwd
  ) || resolved=
  [[ -n ${resolved:-} && -d $resolved/shell/plugins ]] && omarchy_path=$resolved
fi
omarchy_path=${omarchy_path:-/usr/share/omarchy}

if [[ ! -d $omarchy_path/shell || ! -x $omarchy_path/bin/omarchy-menu-keybindings ]]; then
  echo "非 Omarchy 环境（找不到 $omarchy_path/shell 或 omarchy-menu-keybindings），安装周期检查未执行。"
  echo "CI 上这会显示为通过但没有真正校验任何内容；请在 Omarchy 4 机器上运行 ./tests/smoke.sh。"
  exit 0
fi

sandbox_root=$(mktemp -d)
sandbox_home="$sandbox_root/home"
stub_bin="$sandbox_root/bin"
mkdir -p "$sandbox_home" "$stub_bin"

cleanup() {
  [[ -n ${sandbox_root:-} && -d $sandbox_root && $sandbox_root == /tmp/* ]] && rm -rf -- "$sandbox_root"
}
trap cleanup EXIT

cat >"$stub_bin/omarchy" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  "version ")
    echo "4.0.0-test"
    ;;
  "plugin clone")
    source_id=$3
    target_id="${USER}.${source_id#omarchy.}"
    target="$HOME/.config/omarchy/plugins/$target_id"
    mkdir -p "$target"
    jq -n --arg id "$target_id" --arg source "$source_id" \
      '{id: $id, omarchy: {clonedFrom: $source}}' >"$target/manifest.json"
    ;;
  "plugin remove")
    rm -rf -- "$HOME/.config/omarchy/plugins/$3"
    ;;
  "hook install")
    target="$HOME/.config/omarchy/hooks/$3.d/$(basename "$4")"
    mkdir -p "$(dirname "$target")"
    cp "$4" "$target"
    chmod 755 "$target"
    ;;
  "restart shell")
    ;;
  *)
    echo "未处理的 omarchy 测试调用：$*" >&2
    exit 1
    ;;
esac
STUB

cat >"$stub_bin/omarchy-shell" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

cat >"$stub_bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  configerrors) exit 0 ;;
  reload) echo ok; exit 0 ;;
esac
exit 0
STUB
chmod 755 "$stub_bin/omarchy" "$stub_bin/omarchy-shell" "$stub_bin/hyprctl"

test_path="$stub_bin:$PATH"

# --dry-run 必须是纯预览：在尚未安装、尚未播种旧文件的干净 HOME 下，
# 它不能克隆任何插件、不能落地同步器、也不能碰 bindings.lua。
dry_run_output=$(HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" --dry-run)
test ! -e "$sandbox_home/.config/omarchy/plugins"
test ! -e "$sandbox_home/.local/bin/omarchy-zh-sync"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn"
test ! -e "$sandbox_home/.config/hypr/bindings.lua"
test ! -e "$sandbox_home/.local/state/omarchy-zh-cn"
# 预览输出必须说明将要做什么，否则 --dry-run 只是静默空转。
rg -Fq '将克隆：omarchy.audio -> testuser.audio' <<<"$dry_run_output"

mkdir -p "$sandbox_home/.local/bin" \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin" \
  "$sandbox_home/.config/omarchy/hooks/post-update.d" \
  "$sandbox_home/.config/omarchy"
printf '#!/usr/bin/env bash\necho old-sync\n' >"$sandbox_home/.local/bin/omarchy-zh-sync"
printf '#!/usr/bin/env bash\necho old-keybindings\n' >"$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
printf '#!/usr/bin/env bash\necho old-update\n' >"$sandbox_home/.local/bin/omarchy-update-zh"
printf '#!/usr/bin/env bash\necho old-update-confirm\n' >"$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
printf '#!/usr/bin/env bash\necho old-hook\n' >"$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
chmod 755 "$sandbox_home/.local/bin/omarchy-zh-sync" \
  "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh" \
  "$sandbox_home/.local/bin/omarchy-update-zh" \
  "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm" \
  "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
cat >"$sandbox_home/.config/omarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [],
      "center": [{"id": "omarchy.weather", "unit": "imperial"}],
      "right": []
    }
  },
  "plugins": [],
  "disabledPlugins": []
}
JSON

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" >/dev/null

test -x "$sandbox_home/.local/bin/omarchy-zh-sync"
test -x "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
test -x "$sandbox_home/.local/bin/omarchy-update-zh"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/grok-collector"
test -x "$sandbox_home/.local/share/omarchy-zh-cn/agents/bin/kimi-collector"
test -x "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
rg -Fq '准备更新吗？' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l) -eq 25 ]]
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == metric ]]

# 重复安装必须幂等：安装器是“配置 + 克隆 + 追加绑定块”，若不去重，
# 第二次运行会把同一个绑定块再追加一遍，卸载也只能剥掉一层。
HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" >/dev/null
[[ $(grep -c -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua") -eq 1 ]]
[[ $(grep -c -- '-- <<< omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua") -eq 1 ]]
[[ $(grep -c 'omarchy-menu-keybindings-zh' "$sandbox_home/.config/hypr/bindings.lua") -eq 1 ]]
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 2 -maxdepth 2 -name manifest.json | wc -l) -eq 25 ]]

HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/uninstall.sh" --yes >/dev/null

rg -Fq 'old-sync' "$sandbox_home/.local/bin/omarchy-zh-sync"
rg -Fq 'old-keybindings' "$sandbox_home/.local/bin/omarchy-menu-keybindings-zh"
rg -Fq 'old-update' "$sandbox_home/.local/bin/omarchy-update-zh"
rg -Fq 'old-update-confirm' "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-confirm"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-update-restart"
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/agents"
rg -Fq 'old-hook' "$sandbox_home/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update"
test ! -e "$sandbox_home/.config/omarchy/extensions/omarchy-menu.jsonc"
refute() {
  if "$@"; then
    echo "断言失败（预期不应匹配）：$*" >&2
    exit 1
  fi
}

refute rg -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
[[ $(jq -r '.bar.layout.center[0].unit' "$sandbox_home/.config/omarchy/shell.json") == imperial ]]
# 卸载必须零残留：插件目录里不能再留下任何 testuser.* 克隆。
[[ $(find "$sandbox_home/.config/omarchy/plugins" -mindepth 1 -maxdepth 1 \
  -name "testuser.*" | wc -l) -eq 0 ]]

# 上游把 logout/reboot/shutdown 合并成 omarchy-system；私有 bin 目录若残留
# 该脚本会遮蔽上游同名命令，所以卸载后必须消失。
test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/omarchy-system"
for retired in omarchy-system-logout omarchy-system-reboot omarchy-system-shutdown; do
  test ! -e "$sandbox_home/.local/share/omarchy-zh-cn/bin/$retired"
done
# 同步器与安装器必须共用同一个状态目录，否则卸载会留下孤立目录。
test ! -e "$sandbox_home/.local/state/omarchy-zh"
# 首次安装前 bindings.lua 不存在，应记录“原本不存在”标记而不是伪造备份。
archived_state=$(find "$sandbox_home/.local/state" -maxdepth 1 -name 'omarchy-zh-cn-uninstalled-*' | head -1)
[[ -n $archived_state && -f $archived_state/original/bindings-was-absent ]]

# 标记行被破坏时的回滚路径：块内容仍在（引用中文快捷键面板）但剥离标记失效，
# 必须改用安装前备份恢复，而不是放任残留。
cat >"$sandbox_home/.config/hypr/bindings.lua" <<'LUA'
hl.bind("SUPER + Q", "关闭窗口")
LUA
HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/install.sh" >/dev/null
rg -Fq 'omarchy-menu-keybindings-zh' "$sandbox_home/.config/hypr/bindings.lua"
# 破坏标记，模拟用户手改或写入中断。
grep -v -e '^-- >>> omarchy-zh-cn$' -e '^-- <<< omarchy-zh-cn$' \
  "$sandbox_home/.config/hypr/bindings.lua" >"$sandbox_home/bindings.tmp"
mv "$sandbox_home/bindings.tmp" "$sandbox_home/.config/hypr/bindings.lua"
refute grep -Fq -- '-- >>> omarchy-zh-cn' "$sandbox_home/.config/hypr/bindings.lua"
HOME="$sandbox_home" USER=testuser PATH="$test_path" "$ROOT_DIR/uninstall.sh" --yes >/dev/null
refute grep -Fq 'omarchy-menu-keybindings-zh' "$sandbox_home/.config/hypr/bindings.lua"
grep -Fq '关闭窗口' "$sandbox_home/.config/hypr/bindings.lua"

echo "隔离安装与卸载周期检查通过。"
