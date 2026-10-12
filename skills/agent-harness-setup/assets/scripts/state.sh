#!/usr/bin/env bash
# Agent-loop change detection. Local-only tooling; never commit.
#   .agent-loop/state.sh check   fetch the lean queue state, write .agent-loop/state/current.json,
#                                print CHANGED (exit 0) or UNCHANGED (exit 10) against the last save
#   .agent-loop/state.sh save    store the current state's fingerprint as the baseline (end of a run)
# The fingerprint covers, per repo: assigned open issues (number, labels, updatedAt), the loop's
# open PRs (branch, updatedAt, CI result) and recently closed ones (merges), recently closed
# issues (blockers), loop branches, worktree heads, and whether a verification upkeep pass is due;
# plus the instruction files and today's local date (so the first run of each day is always full).
set -euo pipefail

# --- Configure per setup -------------------------------------------------------------------
ME="<github-user>"          # only open issues assigned to this user are loop work
TZ_LOOP="UTC"               # the maintainer's time zone, e.g. Asia/Kuala_Lumpur
# One entry per repo: "<owner/name> <checkout dir name, a sibling of this checkout>
#   [<upkeep SHA marker, relative to this checkout> <app paths that make the verify map stale>...]"
# The first entry is the orchestrator's own repo. Omit the marker to skip upkeep for a repo.
REPOS=(
  "<owner>/<repo> <repo> .agent-loop/maintain/verify-<app>.sha src"
)
# -------------------------------------------------------------------------------------------

ROOT=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
DIR="${STATE_DIR:-$ROOT/.agent-loop/state}"
mkdir -p "$DIR"
COLLECT_TMP=""
trap 'status=$?; [ -z "$COLLECT_TMP" ] || rm -rf "$COLLECT_TMP"; if [ "$status" -ne 0 ] && [ "$status" -ne 10 ]; then echo "ERROR: state collection failed; do not treat this as CHANGED or save state. If sandbox access blocked GitHub or Git metadata, retry with authorized escalation." >&2; fi' EXIT

# Only the loop's own PRs matter: their branches are in that checkout's .agent-loop/branches.tsv.
ci() { jq -c --argjson own "$1" '[.[] | select(.headRefName as $b | $own | index($b)) | {number, branch: .headRefName, updatedAt,
  ci: ([.statusCheckRollup[]? | (.conclusion // .state // .status)] | sort | unique)}] | sort_by(.number)'; }
own() { cut -f1 "$1" 2>/dev/null | jq -R . | jq -sc .; }

# Due when main has app-path commits since the SHA marker and the marker is older than 24 hours.
upkeep_due() { # <checkout> <marker> <paths...>
  local repo=$1 marker=$2; shift 2
  [ -f "$marker" ] || { echo true; return; }
  local age=$(( $(date +%s) - $(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker") ))
  local n; n=$(git -C "$repo" rev-list --count "$(cat "$marker")..origin/main" -- "$@" 2>/dev/null || echo 1)
  [ "$n" -gt 0 ] && [ "$age" -gt 86400 ] && echo true || echo false
}

collect() {
  local out="$DIR/current.json" tmp i=0 instr_files=("$ROOT/.agent-loop/orchestrator.md")
  tmp=$(mktemp -d); COLLECT_TMP="$tmp"
  for spec in "${REPOS[@]}"; do
    local f r co marker due o
    read -r -a f <<< "$spec"
    r=${f[0]}; co="$(dirname "$ROOT")/${f[1]}"; marker=${f[2]:-}
    o=$(own "$co/.agent-loop/branches.tsv")
    gh issue list -R "$r" --state open --assignee "$ME" --limit 200 --json number,title,updatedAt,labels \
      | jq -c '[.[] | {number, title, updatedAt, labels: [.labels[].name] | sort}] | sort_by(.number)' > "$tmp/issues"
    gh pr list -R "$r" --state open --limit 100 --json number,headRefName,updatedAt,statusCheckRollup | ci "$o" > "$tmp/prs"
    gh issue list -R "$r" --state closed --limit 30 --json number,closedAt | jq -c 'sort_by(.number)' > "$tmp/closed_issues"
    gh pr list -R "$r" --state closed --limit 30 --json number,headRefName,closedAt \
      | jq -c --argjson own "$o" '[.[] | select(.headRefName as $b | $own | index($b))] | sort_by(.number)' > "$tmp/closed_prs"
    # A sandbox may block writing FETCH_HEAD. A failed fetch only delays upkeep_due, so it must
    # not fail the check (and force an escalation on every idle run); a full run fetches.
    git -C "$co" fetch -q origin main 2>/dev/null || echo "NOTE: fetch failed in $r; upkeep_due may be stale" >&2
    due=false
    [ -z "$marker" ] || due=$(upkeep_due "$co" "$ROOT/$marker" "${f[@]:3}")
    jq -n --arg repo "$r" --arg due "$due" \
      --slurpfile is "$tmp/issues" --slurpfile ps "$tmp/prs" --slurpfile ci "$tmp/closed_issues" --slurpfile cp "$tmp/closed_prs" \
      --arg wt "$(git -C "$co" worktree list --porcelain | grep -E '^(worktree|HEAD) ')" \
      --arg reg "$(cat "$co/.agent-loop/branches.tsv" 2>/dev/null)" \
      '{repo: $repo, issues: $is[0], prs: $ps[0], closed_issues: $ci[0], closed_prs: $cp[0],
        worktrees: $wt, branches: $reg, upkeep_due: $due}' > "$tmp/repo-$(printf %02d $i).json"
    instr_files+=("$co/AGENTS.md" "$co/AGENTS.override.md")
    i=$((i + 1))
  done
  jq -s --arg date "$(TZ=$TZ_LOOP date +%F)" \
    --arg instr "$(cat "${instr_files[@]}" 2>/dev/null | shasum -a 256 | cut -c1-16)" \
    '{date: $date, repos: ., instructions: $instr}' "$tmp"/repo-*.json > "$tmp/current.json"
  fp=$(jq -cS . "$tmp/current.json" | shasum -a 256 | cut -c1-64)
  mv "$tmp/current.json" "$out"
  rm -rf "$tmp"
  COLLECT_TMP=""
}

case "${1:-}" in
  check)
    collect
    if [ -f "$DIR/fingerprint" ] && [ "$(cat "$DIR/fingerprint")" = "$fp" ]; then
      echo "UNCHANGED $fp"; exit 10
    fi
    echo "CHANGED $fp" ;;
  save)
    collect; echo "$fp" > "$DIR/fingerprint"; echo "saved $fp" ;;
  *) sed -n 2,9p "$0"; exit 2 ;;
esac
