---
name: anydesk-connect
description: Diagnose and recover AnyDesk on a remote Linux desktop over SSH when the client shows online but the connection times out, ends unexpectedly, or returns desk_rt_ipc_error. Use when SSH or Tailscale reaches the host, anydesk.service is running, and the likely failure is that the AnyDesk frontend is not attached to the active X11 desktop session.
---

# Anydesk Connect

## Overview

Run a narrow, deterministic recovery workflow for Linux hosts where AnyDesk is online but unusable.
Prioritize X11 session type, service state, and frontend attachment before treating network issues as the primary cause.

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

- If the active GUI session is `Type=wayland`, do not use this skill as the primary fix path. Switch to Xorg first.
- If `ufw` is inactive and `anydesk.service` is active, do not treat firewall or basic service availability as the primary cause.
- If `--service` is alive but `--frontend` and `--backend` are missing, unstable, or return `desk_rt_ipc_error`, treat the issue as a frontend attachment failure.

## Primary Recovery

Use the bundled script when the host is reachable over SSH and the active desktop session is X11:

```bash
bash $CODEX_HOME/skills/anydesk-connect/scripts/revive_anydesk_session.sh
```

The script:

- Restarts `anydesk.service`
- Clears only AnyDesk-related user-side processes
- Re-exports `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS`
- Relaunches AnyDesk into the active desktop session
- Prints current AnyDesk processes and the tail of `/tmp/anydesk-launch.log`

## Manual Fallback

If the script needs environment-specific adjustment, run the equivalent sequence manually:

```bash
sudo systemctl restart anydesk
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
