#!/usr/bin/env bash
set -euo pipefail

log_path="${ANYDESK_LOG_PATH:-/tmp/anydesk-launch.log}"
user_name="$(id -un)"
user_id="$(id -u)"
anydesk_bin="${ANYDESK_BIN:-/usr/bin/anydesk}"

resolve_desktop_env() {
  local candidate_pid
  local env_dump
  local line

  for candidate_pid in \
    "$(pgrep -u "$user_id" -n gnome-shell || true)" \
    "$(pgrep -u "$user_id" -n gnome-session-binary || true)" \
    "$(pgrep -u "$user_id" -n xfce4-session || true)" \
    "$(pgrep -u "$user_id" -n plasmashell || true)"; do
    [[ -n "$candidate_pid" ]] || continue
    [[ -r "/proc/$candidate_pid/environ" ]] || continue
    env_dump="$(tr '\0' '\n' < "/proc/$candidate_pid/environ" || true)"
    [[ -n "$env_dump" ]] || continue

    while IFS= read -r line; do
      case "$line" in
        DISPLAY=*)
          export DISPLAY="${line#DISPLAY=}"
          ;;
        XAUTHORITY=*)
          export XAUTHORITY="${line#XAUTHORITY=}"
          ;;
        DBUS_SESSION_BUS_ADDRESS=*)
          export DBUS_SESSION_BUS_ADDRESS="${line#DBUS_SESSION_BUS_ADDRESS=}"
          ;;
      esac
    done <<< "$env_dump"

    break
  done

  export DISPLAY="${DISPLAY:-:0}"
  export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$user_id/bus}"
}

clear_user_anydesk_processes() {
  local pids
  local remaining

  pids="$(pgrep -u "$user_id" -x anydesk || true)"
  if [[ -n "$pids" ]]; then
    echo "Terminating user-side AnyDesk processes:"
    printf '%s\n' "$pids" | sed 's/^/  pid=/'
    # shellcheck disable=SC2086
    kill $pids || true
    sleep 2
  else
    echo "No user-side AnyDesk processes to terminate."
  fi

  remaining="$(pgrep -u "$user_id" -x anydesk || true)"
  if [[ -n "$remaining" ]]; then
    echo "Force-killing remaining user-side AnyDesk processes:"
    printf '%s\n' "$remaining" | sed 's/^/  pid=/'
    # shellcheck disable=SC2086
    kill -9 $remaining || true
    sleep 1
  fi
}

count_exact_args_processes() {
  local user_filter="$1"
  local expected_args="$2"

  ps -eo user=,args= |
    awk -v user_filter="$user_filter" -v expected_args="$expected_args" '
      {
        line = $0
        user = $1
        sub(/^[^[:space:]]+[[:space:]]+/, "", line)
        if (user == user_filter && line == expected_args) { count++ }
      }
      END { print count + 0 }
    '
}

has_listener_7070() {
  ss -ltn 2>/dev/null | awk '$4 ~ /:7070$/ { found=1 } END { exit found ? 0 : 1 }'
}

session_line="$(loginctl list-sessions --no-legend | awk -v user="$user_name" '$3 == user && $4 == "seat0" {print $1; exit}')"
if [[ -z "$session_line" ]]; then
  echo "No local seat0 desktop session found for user $user_name." >&2
  exit 1
fi

session_type="$(loginctl show-session "$session_line" -p Type --value)"
if [[ "$session_type" != "x11" ]]; then
  echo "Active desktop session is '$session_type', not x11. Switch to Xorg before using this recovery." >&2
  exit 1
fi

resolve_desktop_env

sudo -n systemctl restart anydesk
sleep 2

clear_user_anydesk_processes

sudo -n systemctl restart anydesk
sleep 3

nohup env \
  DISPLAY="$DISPLAY" \
  XAUTHORITY="$XAUTHORITY" \
  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  "$anydesk_bin" >"$log_path" 2>&1 &
sleep 6

service_status="$(systemctl is-active anydesk 2>/dev/null || true)"
client_status="$("$anydesk_bin" --get-status 2>&1 || true)"
service_count="$(count_exact_args_processes root "$anydesk_bin --service")"
tray_count="$(count_exact_args_processes "$user_name" "$anydesk_bin --tray")"
frontend_count="$(
  ps -u "$user_id" -o args= |
    awk -v bin="$anydesk_bin" '$0 == bin { count++ } END { print count + 0 }'
)"
listener_status="missing"
if has_listener_7070; then
  listener_status="present"
fi

echo "Recovered AnyDesk with:"
echo "  DISPLAY=$DISPLAY"
echo "  XAUTHORITY=$XAUTHORITY"
echo "  DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo
echo "Post-repair status:"
echo "  anydesk.service=$service_status"
echo "  anydesk_status=$client_status"
echo "  root_service_processes=$service_count"
echo "  user_tray_processes=$tray_count"
echo "  user_frontend_processes=$frontend_count"
echo "  listener_7070=$listener_status"
echo
echo "Current AnyDesk processes:"
ps -eo user:12,pid,ppid,stat,lstart,args | grep -i "[a]nydesk" || true
echo
echo "Recent launch log:"
tail -n 40 "$log_path" 2>/dev/null || true

if [[ "$service_status" != "active" ||
      "$client_status" != "online" ||
      "$service_count" -lt 1 ||
      "$tray_count" -lt 1 ||
      "$frontend_count" -lt 1 ||
      "$listener_status" != "present" ]]; then
  echo "REMOTE_REPAIR_INCOMPLETE" >&2
  exit 1
fi

echo "REMOTE_REPAIRED"
