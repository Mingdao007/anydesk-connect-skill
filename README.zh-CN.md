# AnyDesk Connect Skill

可移植的 AnyDesk 恢复 skill，用于处理 Linux 主机在线但无法正确 attach 到 active desktop 的远程桌面问题。

## 适合谁

| 适合使用 | 不适合使用 |
| --- | --- |
| SSH 或 Tailscale 可以连到 Linux 主机 | 需要从零安装 AnyDesk |
| AnyDesk 显示在线但连接超时或异常结束 | 网络层完全无法到达主机 |
| 疑似 frontend 没有 attach 到 active X11 session | 要求 Wayland-only 且不接受 X11 fallback |

## 为什么需要它

- 让远程恢复保持窄域、diagnosis-first。
- 把 desktop-session attachment 和泛化网络调试分开。
- 升级到高影响动作前先明确风险。

## 包含内容

| Component | 作用 |
| --- | --- |
| [`anydesk-connect`](./anydesk-connect) | 可安装的 Codex App skill package |
| [`anydesk-connect/agents/openai.yaml`](./anydesk-connect/agents/openai.yaml) | Codex App 界面 metadata |
| [`anydesk-connect/scripts`](./anydesk-connect/scripts) | 随包发布的 helper scripts |
| [`anydesk-connect/test-prompts.json`](./anydesk-connect/test-prompts.json) | trigger / non-trigger 示例 |
| [`CHANGELOG.md`](./CHANGELOG.md) | release history |
| [`LICENSE`](./LICENSE) | license |

## 安装 / 使用

### Codex App

- 从本 repo 的这个路径安装 skill：`anydesk-connect`
- GitHub install target:
  - repo: `Mingdao007/anydesk-connect-skill`
  - path: `anydesk-connect`
- 安装后重启 `Codex App`，让新 skill 被重新发现。

## 工作流

```mermaid
flowchart LR
    A["可达主机"] --> B["AnyDesk 故障触发"]
    B --> C["Session 诊断"]
    C --> D["Service/frontend 恢复"]
    D --> E["恢复访问或收集日志"]
```

## 覆盖范围

- 深入恢复前先判断 X11 与 Wayland
- 通过 SSH 执行 service restart 与 frontend reattachment
- 恢复失败时收集 log 供 escalation 使用

## 预期结果 / 验证

| 检查项 | 预期结果 |
| --- | --- |
| 安装路径 | `anydesk-connect` |
| GitHub target | `Mingdao007/anydesk-connect-skill`，path 为 `anydesk-connect` |
| Skill 入口 | 存在 `anydesk-connect/SKILL.md` |
| 触发样例 | `anydesk-connect/test-prompts.json` |
| 隐私检查 | 公开包不包含私人本机路径或 live user state |

## 触发示例

- `Recover this Linux AnyDesk host over SSH.`
- `The host is online but the AnyDesk client times out.`
- `Diagnose desk_rt_ipc_error on a remote desktop.`

## 不应触发

- `Set up AnyDesk from scratch on a new machine.`
- `Debug a VPN that cannot reach the host at all.`
- `Fix a Wayland-only desktop workflow without switching to Xorg.`

## 隐私边界

这个公开仓库只保留通用、可复用的 workflow。

- 公开包不包含特定机器 IP、用户名或 hostname。
- 恢复命令使用环境推导路径，不写入私人绝对路径。

## 仓库结构

| 路径 | 作用 |
| --- | --- |
| [`anydesk-connect`](./anydesk-connect) | 可安装的 Codex App skill package |
| [`anydesk-connect/agents/openai.yaml`](./anydesk-connect/agents/openai.yaml) | Codex App 界面 metadata |
| [`anydesk-connect/scripts`](./anydesk-connect/scripts) | 随包发布的 helper scripts |
| [`anydesk-connect/test-prompts.json`](./anydesk-connect/test-prompts.json) | trigger / non-trigger 示例 |
| [`CHANGELOG.md`](./CHANGELOG.md) | release history |
| [`LICENSE`](./LICENSE) | license |

English:

- [README.md](./README.md)
