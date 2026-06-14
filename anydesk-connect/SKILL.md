---
name: anydesk-connect
description: "Diagnose and recover AnyDesk on a remote Linux desktop over SSH when the client shows online but the connection times out, ends unexpectedly, returns desk_rt_ipc_error, or the user's recurring andy7 AnyDesk connection fails. Use for the default andy7 flow: restart AnyDesk service, clean stale user-side AnyDesk processes, reattach to the active X11 session, and verify real incoming/session evidence before calling it fixed."
---

# Anydesk Connect

## Overview

Run a narrow, deterministic recovery workflow for Linux hosts where AnyDesk is online but unusable.
For the recurring `andy7` issue, default to the remote repair wrapper first.
Prioritize X11 session type, service restart, stale user-side process cleanup, and X11 frontend reattachment before treating Mac UI or network issues as the primary cause.

## Completion Gate

For the user's recurring `andy7` AnyDesk issue, the specific recovery workflow is the default completion path.
Do not start by probing the local Mac AnyDesk UI or requiring Computer Use visual confirmation.

The repair phase passes when all of these are true:

- the host is reachable over SSH or Tailscale
- the active local desktop session is `Type=x11`
- the bundled repair or equivalent manual sequence restarts `anydesk.service`
- every stale user-side process with command name `anydesk` is terminated with `TERM`, then `KILL` if still present
- AnyDesk is relaunched with the active desktop `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS`
- post-repair checks show `anydesk.service`, `anydesk --tray`, a user-side frontend `anydesk`, `anydesk --get-status=online`, and the AnyDesk listener on `7070`

Do not describe the problem as fixed after process/listener checks alone.
Say only that remote repair is complete.
The connection passes only when remote evidence shows the full session sequence from the Mac client: `Accept request from <Mac ID>`, `Client-ID: <Mac ID>`, `Authenticated with permanent token`, and `Entering processing loop`, or when the user/screenshot confirms the remote desktop is visible.

If the user still cannot connect after remote repair, do not restart broad diagnosis.
Check `/etc/anydesk/connection_trace.txt` and `/var/log/anydesk.trace` for the Mac AnyDesk ID first.
Only inspect the local Mac AnyDesk UI after this remote trace check fails to show an outgoing/incoming attempt or the user explicitly reports the Mac UI cannot open.

## Recovery Loop

This skill is a specific exception to the common remote-desktop rule.
For this known issue, run the remote X11 reattachment workflow first.
Only use local Mac AnyDesk UI probing or Computer Use after the specific workflow fails or the context does not match the known `andy7` X11 attachment failure.

Use this ordered loop:

1. Confirm the remote host remains reachable over SSH or Tailscale.
2. Confirm the active desktop session is `Type=x11`; if it is `Wayland`, stop at the high-impact boundary.
3. Run the bundled remote repair wrapper from the local Mac, or the equivalent manual recovery sequence over SSH.
4. Treat `REMOTE_REPAIRED` as remote-side readiness only, not proof of a usable client session.
5. Confirm post-repair remote evidence: `anydesk.service` is active, `anydesk --get-status` is `online`, user-side `anydesk` and `anydesk --tray` are present, and listener `7070` is present.
6. If the user still reports failure, check remote traces for the Mac AnyDesk ID before looking at Mac UI.
7. Treat `REMOTE_SESSION_SEEN` or the full matching remote log sequence as the real connection gate; if absent, state that no verified client session completed on the remote host.

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
- If `--service` is alive but frontend/tray/backend state is stale, duplicated, missing, unstable, or returns `desk_rt_ipc_error`, treat the issue as a stale user-side AnyDesk attachment failure.

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
- Clears all user-side processes whose command name is exactly `anydesk`
- Re-exports `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS`
- Relaunches AnyDesk into the active desktop session
- Prints `REMOTE_REPAIRED` only after remote service, tray, frontend, online status, and listener checks pass
- Lets the wrapper print `REMOTE_SESSION_SEEN` only after remote trace evidence includes `Accept request from <Mac ID>`, `Client-ID: <Mac ID>`, `Authenticated with permanent token`, and `Entering processing loop`

Do not suggest this recovery path until `X11` has already been confirmed through low-impact checks.

## Manual Fallback

If the script needs environment-specific adjustment, run the equivalent sequence manually:

```bash
sudo -n systemctl restart anydesk
pgrep -u "$(id -u)" -x anydesk | xargs -r kill
sleep 2
pgrep -u "$(id -u)" -x anydesk | xargs -r kill -9
sudo -n systemctl restart anydesk
export DISPLAY=:0
export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
nohup /usr/bin/anydesk >/tmp/anydesk-launch.log 2>&1 &
sleep 6
ps -eo user:12,pid,ppid,stat,lstart,args | grep -i "[a]nydesk"
anydesk --get-status
tail -n 40 /tmp/anydesk-launch.log
```

Expect at least:

- `anydesk --service`
- `anydesk --tray`
- a user-side `anydesk` process that stays alive long enough for the client to reconnect
- listener `7070`

## Keep Network Diagnosis Secondary

Do not treat a green online dot as proof that an AnyDesk session can be established.
If SSH or Tailscale reaches the host and this recovery fixes the problem, record the issue as a desktop-session attachment failure rather than a primary NAT, firewall, or VPN fault.
Do not treat remote process evidence alone as proof of a working client connection.

## Escalation Data

If the recovery does not restore access, collect:

```bash
anydesk --version
journalctl -u anydesk -n 120 --no-pager
tail -n 100 /tmp/anydesk-launch.log
tail -n 40 /etc/anydesk/connection_trace.txt
tail -n 300 /var/log/anydesk.trace | grep -Ei 'Accept request|Client-ID|Authenticated|Entering processing loop|session|error|fail'
```

Only escalate toward reinstall or an alternative remote desktop stack after:

1. X11 is confirmed.
2. `ufw` is ruled out.
3. The recovery script has been attempted from SSH as the desktop owner.

If a future step would require reboot, session-stack changes, package changes, or display-manager edits, stop and ask for explicit approval for that high-impact class of action first.
