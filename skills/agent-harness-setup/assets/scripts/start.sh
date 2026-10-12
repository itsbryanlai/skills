#!/usr/bin/env bash
# One-call start of an agent-loop run: take the lock, then check for change. Local-only; never commit.
#   .agent-loop/start.sh [automation-id]
# Prints one of:
#   LOCKED <age>s   a live run holds the lock; this run ends
#   UNCHANGED ...   nothing to do; the lock is released
#   CHANGED ...     do a full run; this run holds the lock
#   ERROR           the state check failed; the lock is released
# With an automation id, LOCKED and UNCHANGED also append the one-line run note to
# that Codex automation's memory.md, so an idle run needs no other call.
# A lock counts as dead, and is taken over, when it is older than 6 hours or when no Codex
# session for this repo or its worktrees is mid-turn: its last turn event is task_complete
# (a run stopped by the usage limit also ends with task_complete). Sessions created in the
# last 2 minutes belong to this run.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LOCK="$HERE/run.lock"
MEM="${CODEX_HOME:-$HOME/.codex}/automations/${1:-}/memory.md"
note() { [ -n "${1:-}" ] && [ -f "$MEM" ] && printf '%s — %s\n' "$(date -Iseconds)" "$2" >> "$MEM"; return 0; }

ROOT=$(dirname "$HERE")
alive() {
  local f
  while IFS= read -r -d '' f; do
    head -n1 "$f" | grep -q "\"cwd\":\"$ROOT" || continue
    [ "$(grep -oE '"type":"task_(started|complete)"' "$f" | tail -n1)" = '"type":"task_started"' ] && return 0
  done < <(find "${CODEX_HOME:-$HOME/.codex}/sessions" -name 'rollout-*.jsonl' -mmin -360 -Bmin +2 -print0 2>/dev/null)
  return 1
}

if ! mkdir "$LOCK" 2>/dev/null; then
  age=$(( $(date +%s) - $(stat -f %m "$LOCK") ))
  if [ "$age" -lt 21600 ] && alive; then
    echo "LOCKED ${age}s"; note "${1:-}" "skipped; run.lock is ${age}s old"; exit 0
  fi
  rmdir "$LOCK" && mkdir "$LOCK" || { echo ERROR; exit 1; }
fi

"$HERE/state.sh" check
case $? in
  0) ;;
  10) rmdir "$LOCK"; note "${1:-}" "no change; lock released" ;;
  *) rmdir "$LOCK"; echo ERROR; exit 1 ;;
esac
