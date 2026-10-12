#!/usr/bin/env bash
# Agent-loop worktrees. Local-only tooling; never commit.
#   .agent-loop/worktree.sh new <branch>      new branch from origin/main + worktree; registers the branch
#   .agent-loop/worktree.sh resume <branch>   worktree for a registered branch (PR follow-up)
#   .agent-loop/worktree.sh remove <branch>   remove worktree and local branch; keeps the registry row
#   .agent-loop/worktree.sh owned <branch>    exit 0 if the loop created this branch
#   .agent-loop/worktree.sh list              registry and worktrees
# Branch names follow the usual prefixes: feat/ feature/ fix/ bugfix/ hotfix/
# refactor/ docs/ chore/ test/ (e.g. feat/244-document-agent-architecture).
# The loop owns a branch only if it is in .agent-loop/branches.tsv (written by `new`).
# Worktrees live in ../<repo>-worktrees/<branch with / replaced by ->.
set -euo pipefail

MAIN=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
BASE="$(dirname "$MAIN")/$(basename "$MAIN")-worktrees"
REG="$MAIN/.agent-loop/branches.tsv"
cmd=${1:-}; branch=${2:-}
dir="$BASE/${branch//\//-}"

owned() { [ -f "$REG" ] && cut -f1 "$REG" | grep -qxF "$1"; }

# Files git does not carry into a worktree (all listed in .git/info/exclude).
# Copied, not symlinked, so a worktree can change its own copy.
# .venv is symlinked to the main checkout. node_modules is an APFS clone (cp -c):
# Turbopack crashes on a symlinked node_modules.
copy_local() {
  for f in AGENTS.override.md CLAUDE.local.md .claude/settings.local.json .codex/hooks.json .codex/config.toml; do
    [ -e "$MAIN/$f" ] && mkdir -p "$dir/$(dirname "$f")" && cp "$MAIN/$f" "$dir/$f"
  done
  for d in .claude/skills .claude/agents .agents/skills .agent-loop/hooks .agent-loop/templates; do
    [ -e "$MAIN/$d" ] && mkdir -p "$dir/$(dirname "$d")" && cp -R "$MAIN/$d" "$dir/$(dirname "$d")/"
  done
  [ -d "$MAIN/.venv" ] && [ ! -e "$dir/.venv" ] && ln -s "$MAIN/.venv" "$dir/.venv"
  [ -d "$MAIN/node_modules" ] && [ ! -e "$dir/node_modules" ] && cp -cR "$MAIN/node_modules" "$dir/node_modules"
  return 0
}

case "$cmd" in
  new)
    [[ "$branch" =~ ^(feat|feature|fix|bugfix|hotfix|refactor|docs|chore|test)/[a-z0-9][a-z0-9._-]*$ ]] \
      || { echo "branch must be <prefix>/<lowercase-slug>, prefix one of feat feature fix bugfix hotfix refactor docs chore test" >&2; exit 2; }
    git -C "$MAIN" fetch -q origin
    # Never take over an existing branch: it may be a human's.
    if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$branch" \
       || git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      echo "branch $branch already exists; pick another name" >&2; exit 3
    fi
    git -C "$MAIN" worktree add -q -b "$branch" "$dir" origin/main
    mkdir -p "$(dirname "$REG")"
    printf '%s\t%s\n' "$branch" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REG"
    copy_local; echo "$dir" ;;
  resume)
    owned "$branch" || { echo "$branch is not a loop branch (not in $REG)" >&2; exit 3; }
    git -C "$MAIN" fetch -q origin "$branch"
    if [ -d "$dir" ]; then git -C "$dir" pull -q --ff-only origin "$branch"
    else git -C "$MAIN" worktree add -q -B "$branch" "$dir" "origin/$branch"; copy_local; fi
    echo "$dir" ;;
  remove)
    owned "$branch" || { echo "$branch is not a loop branch (not in $REG)" >&2; exit 3; }
    git -C "$MAIN" worktree remove --force "$dir"
    git -C "$MAIN" branch -D "$branch" >/dev/null 2>&1 || true
    echo "removed $dir" ;;
  owned) owned "$branch" ;;
  list)
    echo "# loop branches ($REG)"; [ -f "$REG" ] && cat "$REG"
    echo "# worktrees"; git -C "$MAIN" worktree list ;;
  *) sed -n 2,11p "$0"; exit 2 ;;
esac
