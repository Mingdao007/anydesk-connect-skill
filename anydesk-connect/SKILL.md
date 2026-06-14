---
name: anydesk-connect
description: Diagnose and recover AnyDesk on a remote Linux desktop over SSH when the client shows online but the connection times out, ends unexpectedly, or returns desk_rt_ipc_error. Use when SSH or Tailscale reaches the host, anydesk.service is running, and the likely failure is that the AnyDesk frontend is not attached to the active X11 desktop session.
---

# Anydesk Connect

## Overview

Run a narrow, deterministic recovery workflow for Linux hosts where AnyDesk is online but unusable.
Prioritize X11 session type, service state, and frontend attachment before treating network issues as the primary cause.

## Completion Gate

For the user's recurring `andy7` AnyDesk issue, the specific recovery workflow is the default completion path.
Do not start by probing the local Mac AnyDesk UI or requiring Computer Use visual confirmation.

The workflow passes when all of these are true:

- the host is reachable over SSH or Tailscale
- the active local desktop session is `Type=x11`
- the bundled repair or equivalent manual sequence restarts `anydesk.service`
- user-side AnyDesk processes are cleared and relaunched with the active desktop `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS`
- post-repair checks show `anydesk.service`, a user-side `anydesk` process, `anydesk --tray`, and the AnyDesk listener present

If the user still cannot connect after this specific workflow, then escalate to the general remote-desktop verification path, including local Mac UI inspection and Computer Use visual confirmation when feasible.

## Recovery Loop

This skill is a specific exception to the common remote-desktop rule.
For this known issue, run the remote X11 reattachment workflow first.
Only use local Mac AnyDesk UI probing or Computer Use after the specific workflow fails or the context does not match the known `andy7` X11 attachment failure.

Use this ordered loop:

1. Confirm the remote host remains reachable over SSH or Tailscale.
2. Confirm the active desktop session is `Type=x11`; if it is `Wayland`, stop at the high-impact boundary.
3. Run the bundled remote repair wrapper from the local Mac, or the equivalent manual recovery sequence over SSH.
4. Confirm post-repair remote evidence: `anydesk.service` is active, user-side `anydesk` and `anydesk --tray` are present, and the AnyDesk listener is present.
5. If the user still reports failure after the specific repair, then continue with the common troubleshooting-to-boundary path: inspect local Mac AnyDesk UI, use Computer Use when feasible, collect logs, or stop at the first concrete user-only or high-impact boundary.

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

From this skill directory, use the bundled script when the host is reachable
over SSH and the active desktop session is X11:

```bash
bash scripts/revive_anydesk_session.sh
```

When launching the recovery from the local Mac, prefer the bundled local
wrapper from this skill directory:

```bash
bash scripts/run_remote_repair.sh andy7
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
