#!/usr/bin/env bash
# Scratch test for guard.sh: expected exit code, then command.
G=$1; T=$(mktemp -d); cd "$T"
git init -q --bare origin.git && git clone -q origin.git r 2>/dev/null && cd r
git commit -q --allow-empty -m init && git push -q origin HEAD:main 2>/dev/null && git branch -q -u origin/main 2>/dev/null
git switch -q -c fix/4-x
R=$PWD
t() { exp=$1; shift; printf '{"cwd":"%s","tool_input":{"command":%s}}' "$R" "$(jq -Rn --arg c "$*" '$c')" | "$G" >/dev/null 2>&1; got=$?; [ "$got" = "$exp" ] && s=PASS || s=FAIL; echo "$s exp=$exp got=$got | $*"; }

t 2 "gh pr merge 12 --squash"
t 2 "gh pr review 3 --approve"
t 2 "git push origin main"
t 0 "git push -u origin fix/4-x"
t 0 "gh pr create --base main"
t 2 "gh issue create -R o/r --label bug --assignee some-user --title x --body y"
t 2 "gh issue create -R o/r -a @me --title x"
t 2 "gh issue edit 12 --add-assignee some-user"
t 2 "gh issue edit 12 --remove-assignee some-user"
t 2 "gh api repos/o/r/issues/12/assignees -X POST -f assignees[]=x"
t 0 "gh issue create -R o/r --label bug --title x --body-file report.md"
t 0 "gh issue list -R o/r --state open --assignee some-user --label bug"
t 0 "gh issue comment 12 --body-file c.md"
t 2 "git add -f AGENTS.override.md"
t 2 "git add --force .claude/skills/verify-x/SKILL.md"
t 0 "git add src/app.ts"

echo x > app.ts; git add app.ts
t 0 "git commit -m feature"
echo local > CLAUDE.local.md; git add -f CLAUDE.local.md
t 2 "git commit -m oops"
t 2 "cd $R && git commit -m oops"
git reset -q CLAUDE.local.md
t 0 "git commit -m feature"
git commit -q -m feature
mkdir -p .agent-loop && echo s > .agent-loop/worktree.sh && git add -f .agent-loop/worktree.sh && git commit -q -m leak
t 2 "git push -u origin fix/4-x"
t 2 "git -C $R push origin HEAD"
git reset -q --hard HEAD~1
t 0 "git push -u origin fix/4-x"
rm -rf "$T"
