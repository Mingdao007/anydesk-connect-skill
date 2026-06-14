#!/usr/bin/env bash
set -euo pipefail

host="${1:-andy7}"
skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote_repair_script="$skill_dir/revive_anydesk_session.sh"
remote_tmp="/tmp/codex_anydesk_repair.sh"
local_anydesk_bin="${LOCAL_ANYDESK_BIN:-/Applications/AnyDesk.app/Contents/MacOS/AnyDesk}"
session_wait_seconds="${ANYDESK_SESSION_WAIT_SECONDS:-20}"

if [[ ! -f "$remote_repair_script" ]]; then
  echo "Missing repair script: $remote_repair_script" >&2
  exit 1
fi

local_id=""
if [[ -x "$local_anydesk_bin" ]]; then
  local_id="$("$local_anydesk_bin" --get-id 2>/dev/null | tr -dc '0-9' || true)"
fi

if [[ -n "$local_id" ]]; then
  echo "Mac AnyDesk ID: $local_id"
else
  echo "Mac AnyDesk ID: unavailable"
fi

remote_conn_start="$(
  ssh "$host" "wc -l < /etc/anydesk/connection_trace.txt 2>/dev/null || echo 0" |
    tr -dc '0-9'
)"
remote_log_start="$(
  ssh "$host" "wc -l < /var/log/anydesk.trace 2>/dev/null || echo 0" |
    tr -dc '0-9'
)"
remote_conn_start="${remote_conn_start:-0}"
remote_log_start="${remote_log_start:-0}"

echo "== step 1 / 2: upload repair script to $host =="
ssh "$host" "cat > '$remote_tmp' && chmod 700 '$remote_tmp'" < "$remote_repair_script"

echo
echo "== step 2 / 2: revive AnyDesk session on $host =="
ssh "$host" "bash '$remote_tmp'; rc=\$?; rm -f '$remote_tmp'; exit \$rc"

echo
echo "REMOTE_REPAIRED: remote AnyDesk was cleanly reattached. This is not yet proof that a client session connected."

if [[ -z "$local_id" ]]; then
  echo "REMOTE_SESSION_CHECK_SKIPPED: Mac AnyDesk ID is unavailable."
  exit 0
fi

echo "== optional session check: waiting up to ${session_wait_seconds}s for incoming session from $local_id =="
deadline=$((SECONDS + session_wait_seconds))
while (( SECONDS <= deadline )); do
  if ssh "$host" \
    "log_slice=\$(tail -n +$((remote_log_start + 1)) /var/log/anydesk.trace 2>/dev/null || true)
     printf '%s\n' \"\$log_slice\" | grep -F 'Accept request from $local_id' >/dev/null &&
     printf '%s\n' \"\$log_slice\" | grep -F 'Client-ID: $local_id' >/dev/null &&
     printf '%s\n' \"\$log_slice\" | grep -F 'Authenticated with permanent token' >/dev/null &&
     printf '%s\n' \"\$log_slice\" | grep -F 'Entering processing loop' >/dev/null"; then
    echo "REMOTE_SESSION_SEEN: remote trace saw Accept request, Client-ID, token authentication, and processing loop for Mac AnyDesk ID $local_id."
    exit 0
  fi
  sleep 2
done

echo "REMOTE_SESSION_NOT_SEEN: remote trace did not show the full Accept request, Client-ID, token authentication, and processing loop sequence for Mac AnyDesk ID $local_id during the wait window."
