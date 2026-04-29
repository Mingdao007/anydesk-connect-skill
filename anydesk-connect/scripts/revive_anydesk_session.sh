#!/usr/bin/env bash
set -euo pipefail

log_path="${ANYDESK_LOG_PATH:-/tmp/anydesk-launch.log}"
user_name="$(id -un)"
user_id="$(id -u)"

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

pkill -u "$user_name" -f '/usr/bin/anydesk --frontend|/usr/bin/anydesk --backend|/usr/bin/anydesk --tray|^anydesk$' || true
sleep 1

nohup env \
  DISPLAY="$DISPLAY" \
  XAUTHORITY="$XAUTHORITY" \
  DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  anydesk >"$log_path" 2>&1 &
sleep 3

echo "Recovered AnyDesk with:"
echo "  DISPLAY=$DISPLAY"
echo "  XAUTHORITY=$XAUTHORITY"
echo "  DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo
echo "Current AnyDesk processes:"
pgrep -af anydesk || true
echo
echo "Recent launch log:"
tail -n 40 "$log_path" 2>/dev/null || true
