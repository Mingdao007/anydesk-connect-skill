---
name: anydesk-connect
description: Diagnose and recover AnyDesk on a remote Linux desktop over SSH when the client shows online but the connection times out, ends unexpectedly, or returns desk_rt_ipc_error. Use when SSH or Tailscale reaches the host, anydesk.service is running, and the likely failure is that the AnyDesk frontend is not attached to the active X11 desktop session.
---

# Anydesk Connect

## Overview

Run a narrow, deterministic recovery workflow for Linux hosts where AnyDesk is online but unusable.
Prioritize X11 session type, service state, and frontend attachment before treating network issues as the primary cause.

## Completion Gate

Do not mark the repair as complete from SSH diagnostics, AnyDesk logs, process state, port reachability, or an online/green status alone.
Those checks are only intermediate evidence.

The workflow passes only after Codex manually uses Computer Use to start the real AnyDesk connection to the target computer and confirms that the remote desktop is visible and interactive.
If Computer Use is unavailable, the AnyDesk UI cannot be operated, authentication blocks the connection, or the connection cannot be visually confirmed, report the state as `recovered but unverified` or `not verified`, not as fixed.

## Recovery Loop

`recovered but unverified` is not a stopping state when more low-risk checks remain.
If Computer Use cannot operate the local AnyDesk UI, keep troubleshooting the local verification path before returning.

Use this ordered loop:

1. Confirm the remote host remains reachable over SSH or Tailscale and the remote AnyDesk listener is still present.
2. Confirm the local Mac AnyDesk service, frontend process, visible windows, menu/status item, and recent Mac AnyDesk logs.
3. Try low-risk ways to surface a usable local AnyDesk UI: activate the app, reopen the app, use the AnyDesk URL scheme, inspect menu-bar or Dock-accessible windows, and capture the screen to verify what is visible.
4. Once the local UI is visible, use Computer Use to start the connection and visually confirm the remote desktop.
5. Stop only at a concrete boundary: Computer Use cannot see or operate any AnyDesk UI after targeted attempts, macOS/AnyDesk permissions require a user action, authentication requires user-only credentials, or the next step is a high-impact system change.

When stopping at a boundary, state the exact boundary and the next action that would move verification forward.

## High-Impact Boundary

Default to low-impact diagnosis first.
Do not mix high-impact actions into ordinary troubleshooting output.

High-impact actions for this skill include:

- rebooting or shutting down the remote host
- editing `gdm3`, display-manager, login-manager, or session-manager config
- switching between `Wayland` and `Xorg` / `X11`
- firewall mutations
- package removal or reinstall

If the host is on `Wayland`, stop at read-only confirmation and explain that the current X11-targeted recovery path is not applicable.
Do not provide config-edit or reboot commands unless the user explicitly approves that class of action.
If the user later explicitly approves a high-impact path, present it as a separate approved-action block rather than blending it into the baseline diagnosis flow.

## Baseline Checks

SSH into the Linux host as the desktop owner and run:

```bash
loginctl list-sessions
loginctl show-session <gui-session-id> -p Type -p Name -p State -p Remote
systemctl status anydesk --no-pager
journalctl -u anydesk -n 80 --no-pager
ps aux | grep -i anydesk
sudo ufw status verbose
```

Interpret the results in this order:

- If the active GUI session is `Type=wayland`, do not use this skill as the primary fix path. Stop at read-only confirmation, report that the current recovery path requires `X11`, and wait for explicit user approval before suggesting any `Xorg` / config-change / reboot actions.
- If `ufw` is inactive and `anydesk.service` is active, do not treat firewall or basic service availability as the primary cause.
- If `--service` is alive but `--frontend` and `--backend` are missing, unstable, or return `desk_rt_ipc_error`, treat the issue as a frontend attachment failure.

## Primary Recovery

Use the bundled script when the host is reachable over SSH and the active desktop session is X11:

```bash
bash /Users/andyl/.codex/skills/anydesk-connect/scripts/revive_anydesk_session.sh
```

When launching the recovery from the local Mac, prefer the bundled local wrapper:

```bash
bash /Users/andyl/.codex/skills/anydesk-connect/scripts/run_remote_repair.sh andy7
```

The wrapper expects a narrow passwordless sudo rule for restarting AnyDesk only, such as allowing `/usr/bin/systemctl restart anydesk`.
Do not require or configure broad passwordless sudo.

The script:

- Restarts `anydesk.service`
- Clears only AnyDesk-related user-side processes
- Re-exports `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS`
- Relaunches AnyDesk into the active desktop session
- Prints current AnyDesk processes and the tail of `/tmp/anydesk-launch.log`

Do not suggest this recovery path until `X11` has already been confirmed through low-impact checks.

## Manual Fallback

If the script needs environment-specific adjustment, run the equivalent sequence manually:

```bash
sudo -n systemctl restart anydesk
pkill -u "$(id -un)" -f '/usr/bin/anydesk --frontend|/usr/bin/anydesk --backend|/usr/bin/anydesk --tray|^anydesk$' || true
export DISPLAY=:0
export XAUTHORITY="$HOME/.Xauthority"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
nohup anydesk >/tmp/anydesk-launch.log 2>&1 &
sleep 3
pgrep -af anydesk
tail -n 40 /tmp/anydesk-launch.log
```

Expect at least:

- `anydesk --service`
- `anydesk --tray`
- a user-side `anydesk` process that stays alive long enough for the client to reconnect

## Keep Network Diagnosis Secondary

Do not treat a green online dot as proof that an AnyDesk session can be established.
If SSH or Tailscale reaches the host and this recovery fixes the problem, record the issue as a desktop-session attachment failure rather than a primary NAT, firewall, or VPN fault.

## Escalation Data

If the recovery does not restore access, collect:

```bash
anydesk --version
journalctl -u anydesk -n 120 --no-pager
tail -n 100 /tmp/anydesk-launch.log
```

Only escalate toward reinstall or an alternative remote desktop stack after:

1. X11 is confirmed.
2. `ufw` is ruled out.
3. The recovery script has been attempted from SSH as the desktop owner.

If a future step would require reboot, session-stack changes, package changes, or display-manager edits, stop and ask for explicit approval for that high-impact class of action first.
