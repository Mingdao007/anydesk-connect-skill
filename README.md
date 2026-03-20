# AnyDesk Connect Skill

Portable recovery skill for Linux AnyDesk sessions that are online but fail to attach to the active desktop.

## What Ships

- installable skill: [`anydesk-connect`](./anydesk-connect)
- bundled helper scripts: [`anydesk-connect/scripts/`](./anydesk-connect/scripts)

## Install / Use

- `Codex App`: install the skill from this repo path `anydesk-connect`
- GitHub install target:
  - repo: `<owner>/anydesk-connect-skill`
  - path: `anydesk-connect`
- Restart `Codex App` after installation so the new skill is discovered.

## Coverage

- X11-versus-Wayland diagnosis before deeper recovery steps
- service restart plus frontend reattachment workflow over SSH
- log collection for escalation when recovery does not restore access

## Trigger Examples

- `Recover this Linux AnyDesk host over SSH.`
- `The host is online but the AnyDesk client times out.`
- `Diagnose desk_rt_ipc_error on a remote desktop.`

## Non-Trigger Examples

- `Set up AnyDesk from scratch on a new machine.`
- `Debug a VPN that cannot reach the host at all.`
- `Fix a Wayland-only desktop workflow without switching to Xorg.`

## Privacy Boundary

This public repository keeps the workflow generic and reusable.

- The public package contains no machine-specific IPs, user names, or hostnames.
- Recovery commands use environment-derived paths instead of private absolute paths.

## Repository Layout

- `anydesk-connect/`: installable `Codex App` skill
- `anydesk-connect/scripts/`: bundled public scripts
- `CHANGELOG.md`: release history
- `LICENSE`: `MIT`

Chinese:

- [README.zh-CN.md](./README.zh-CN.md)
