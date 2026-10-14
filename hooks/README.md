# omarchy-zh-cn 系统钩子

此目录包含与 Omarchy 更新生命周期集成的钩子脚本。

## 目录内容

- `omarchy-zh-post-update`：在 Omarchy 执行系统更新后自动触发。负责调用 `omarchy-zh-sync --quiet` 重新编译同步最新的中文插件克隆，若失败则发送系统桌面通知告警。

## 安装位置

通过 `omarchy hook install post-update` 安装到用户配置目录：
`~/.config/omarchy/hooks/post-update.d/omarchy-zh-post-update`。
