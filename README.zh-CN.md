# AnyDesk Connect Skill

用于修复 Linux 上 AnyDesk 在线但无法正确附着到当前桌面会话问题的可移植恢复 skill。

## 提供内容

- 可安装 skill: [`anydesk-connect`](./anydesk-connect)
- 辅助脚本: [`anydesk-connect/scripts/`](./anydesk-connect/scripts)

## 安装 / 使用

- `Codex App`：从本仓库路径 `anydesk-connect` 安装
- GitHub 安装目标：
  - repo：`<owner>/anydesk-connect-skill`
  - path：`anydesk-connect`
- 安装后重启 `Codex App`，让新 skill 被发现。

## 覆盖范围

- 优先检查 X11 与 Wayland 会话类型
- 支持通过 SSH 做服务重启和前端重附着恢复
- 恢复失败时收集日志供后续排障

## 触发示例

- `Recover this Linux AnyDesk host over SSH.`
- `The host is online but the AnyDesk client times out.`
- `Diagnose desk_rt_ipc_error on a remote desktop.`

## 不触发示例

- `Set up AnyDesk from scratch on a new machine.`
- `Debug a VPN that cannot reach the host at all.`
- `Fix a Wayland-only desktop workflow without switching to Xorg.`

## 隐私边界

这个公开仓库只保留可复用、可公开的工作流部分。

- The public package contains no machine-specific IPs, user names, or hostnames.
- Recovery commands use environment-derived paths instead of private absolute paths.

## 仓库结构

- `anydesk-connect/`: installable `Codex App` skill
- `anydesk-connect/scripts/`: bundled public scripts
- `CHANGELOG.md`: release history
- `LICENSE`: `MIT`

English:

- [README.md](./README.md)
