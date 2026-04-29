#!/usr/bin/env bash
set -euo pipefail

host="${1:-andy7}"
skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote_repair_script="$skill_dir/revive_anydesk_session.sh"
remote_tmp="/tmp/codex_anydesk_repair.sh"

if [[ ! -f "$remote_repair_script" ]]; then
  echo "Missing repair script: $remote_repair_script" >&2
  exit 1
fi

echo "== step 1 / 2: upload repair script to $host =="
ssh "$host" "cat > '$remote_tmp' && chmod 700 '$remote_tmp'" < "$remote_repair_script"

echo
echo "== step 2 / 2: revive AnyDesk session on $host =="
ssh "$host" "bash '$remote_tmp'; rc=\$?; rm -f '$remote_tmp'; exit \$rc"
