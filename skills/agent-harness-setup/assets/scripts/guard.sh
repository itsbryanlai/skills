#!/usr/bin/env bash
# PreToolUse guard for the local agent harness (local only, never commit).
# 1. Agents never merge, approve, or push to main: merging needs human review.
#    Agents never assign issues: assignment selects the loop's work.
# 2. Harness files (local-only, see .git/info/exclude) are never committed or pushed.
# Input: the hook JSON on stdin. Exit 2 blocks the command; stderr goes to the agent.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[ -z "$cmd" ] && exit 0
cmd=$(sed -E 's/gh[[:space:]]+(-R|--repo)[[:space:]]+[^[:space:]]+[[:space:]]+/gh /g' <<<"$cmd")

cwd=$(jq -r '.cwd // empty' <<<"$input")
deny() { echo "Blocked by agent-harness guard: $1" >&2; exit 2; }
NM="Merging into main needs human review."

grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' <<<"$cmd" && deny "gh pr merge. $NM"
grep -Eq 'gh[[:space:]]+pr[[:space:]]+review[^|;&]*(--approve|-a([[:space:]]|$))' <<<"$cmd" && deny "PR approval. $NM"
grep -Eq 'gh[[:space:]]+api[^|;&]*(pulls/[0-9]+/merge|/merges([[:space:]]|$|\?)|mergePullRequest|enablePullRequestAutoMerge|/reviews)' <<<"$cmd" && deny "merge or review through gh api. $NM"
grep -Eq 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push[^|;&]*([[:space:]:+]|refs/heads/)(main|master)([[:space:]]|$)' <<<"$cmd" && deny "push to main. $NM"
grep -Eq 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push[^|;&]*[[:space:]](--mirror|--all)' <<<"$cmd" && deny "push of all branches. $NM"

# Assignment is the maintainer's go signal for the loop. Agents never assign or unassign.
NA="Only the maintainer assigns issues; the loop picks up only issues assigned to the maintainer."
grep -Eq 'gh[[:space:]]+(issue|pr)[[:space:]]+(create|edit)[^|;&]*[[:space:]](-a|--assignee|--add-assignee|--remove-assignee)([[:space:]=]|$)' <<<"$cmd" && deny "issue or PR assignment. $NA"
grep -Eq 'gh[[:space:]]+api[^|;&]*(/assignees|addAssigneesToAssignable|removeAssigneesFromAssignable|-f[[:space:]]+assignees|assignees\[\])' <<<"$cmd" && deny "assignment through gh api. $NA"

HARNESS='^(AGENTS\.override\.md|CLAUDE\.local\.md|\.agent-loop/|\.claude/skills/|\.claude/agents/|\.agents/skills/|\.claude/settings\.local\.json|\.codex/(hooks\.json|config\.toml))'
LOCAL="is local-only harness tooling and must never be committed or pushed (see .git/info/exclude)."

if grep -Eq 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?add[^|;&]*[[:space:]](-f|--force)' <<<"$cmd" \
   && grep -Eq '(^|[[:space:]/])(AGENTS\.override\.md|CLAUDE\.local\.md|\.agent-loop|\.claude/skills|\.claude/agents|\.agents/skills|settings\.local\.json|\.codex/(hooks\.json|config\.toml))' <<<"$cmd"; then
  deny "force-adding a harness file. It $LOCAL"
fi

grep -Eq 'git[[:space:]].*(commit|push)' <<<"$cmd" || exit 0
# Directories this command may act on: the hook cwd plus every `cd X` / `-C X` target.
dirs=$( { echo "$cwd"; grep -Eo '(cd|-C)[[:space:]]+("[^"]+"|[^[:space:];&|]+)' <<<"$cmd" | sed -E 's/^(cd|-C)[[:space:]]+//; s/^"//; s/"$//'; } | sort -u)
while IFS= read -r d; do
  [ -n "$d" ] && [ -d "$d" ] || continue
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
  if grep -Eq 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push' <<<"$cmd"; then
    current=$(git -C "$d" branch --show-current)
    [[ "$current" = main || "$current" = master ]] && deny "push from $current. $NM"
  fi
  bad=$(git -C "$d" diff --cached --name-only | grep -E "$HARNESS" | head -3)
  [ -n "$bad" ] && deny "staged harness file(s) in $d: $(tr '\n' ' ' <<<"$bad")- unstage them. It $LOCAL"
  bad=$(git -C "$d" log --branches --not --remotes --name-only --format= 2>/dev/null | grep -E "$HARNESS" | sort -u | head -3)
  [ -n "$bad" ] && deny "unpushed commit(s) in $d add harness file(s): $(tr '\n' ' ' <<<"$bad")- remove them from history first. It $LOCAL"
done <<<"$dirs"
exit 0
