---
name: agent-harness-setup
description: Set up a local, personal coding-agent harness for one or more repos - an unattended agent loop (orchestrator + subagents in git worktrees driven by GitHub issues), a project verification skill, a merge guard, and AGENTS.override.md / CLAUDE.local.md instructions - without committing anything to the repos. Use when the user asks to "set up the agent harness", "set up the agent loop", or to repeat an existing loop setup on another repo. Asks which workflow toolkit (pstack, Spec Kit, none, other) and verification approach to use; assumes neither. Not for one-off agent tasks or for changing a team's shared CI or repo settings.
---

# Agent harness setup

> **Status: Beta.** Run on three repos with Claude Code and Codex; the steps may still change.

This skill reproduces a proven setup: a personal agent loop that turns labelled
GitHub issues into reviewed PRs. Everything it creates is local to the user's
clones. The team sees only the PRs.

What the user ends up with, per repo:

| Piece | Path (all git-excluded) |
|---|---|
| Instructions, single source of truth | `AGENTS.override.md` (Codex reads it in place of `AGENTS.md`) |
| Claude Code entry point | `CLAUDE.local.md` containing only `@AGENTS.override.md` |
| Workflow toolkit skills | `.claude/skills/`, `.claude/agents/`, `.agents/skills/` (symlinks for Codex) |
| Verification skill | `.claude/skills/verify-<app>/` |
| Worktree script | `.agent-loop/worktree.sh` |
| Guard (no merge, no harness files in commits) | `.agent-loop/hooks/guard.sh` + `.claude/settings.local.json` |
| Reports and evidence | `.agent-loop/reports/`, `.agent-loop/evidence/` |

If the user already runs this harness on other repos, read those repos'
`AGENTS.override.md` and `.agent-loop/orchestrator.md` before you start. They
are examples, not templates: copy the structure, not their repo-specific
content.

**Assets.** This skill ships scripts and templates in `assets/scripts/` and
`assets/references/`. If they did not come with the skill (for example, the
text was pasted into a chat), write the equivalent from the behaviour each
step describes, and prove it with the step 7 checks.

## Hard rules for the whole setup

1. **Nothing the harness creates is committed or pushed** to the target repos.
   Every local-only path is listed explicitly in the repo's
   `.git/info/exclude` (per clone, shared by all worktrees, invisible to the
   team). Never use `.gitignore`, and never rely on a global ignore file
   (`~/.config/git/ignore` often covers `settings.local.json` by accident; list
   it anyway). Never edit a tracked file to mention the harness. Exclude rules
   stop `git add .` but not `git add -f`, so the guard (step 6) also blocks
   commits and pushes that add a harness path. Any new local-only path gets a
   line in `.git/info/exclude` and in the guard's `HARNESS` pattern *before*
   it is created.
2. **Read and back up before you delete or overwrite.** Run `ls -a` on every
   target path first. Copy any untracked or excluded file you will remove or
   replace to a backup folder outside the repo (`<backup-root>/<what>-<date>/`). Git cannot restore it.
   A Write that reports "updated" instead of "created" means you just lost a
   file. (Both mistakes happened in the second setup; recovery took
   transcript forensics.)
3. **Agents never merge to main** unless the user says otherwise. Install the
   merge guard (step 6) before any unattended run.
4. **Tracked tooling the user wants gone is removed by a normal PR**, not
   locally. Offer to open an issue for it.
5. Never write to a production database or remote service while proving the
   setup. Verification uses throwaway local state only.

## Step 1. Interview

Ask the user a few questions at a time. Recommend a default.
Do not assume an answer the user has not given.

- **Repos in scope.** One repo or several? If several (for example a frontend
  and its backend), which main checkout hosts the orchestrator?
- **Harnesses.** Claude Code, Codex, both, other? (Decides `CLAUDE.local.md`,
  `.agents/skills/` symlinks, and how the merge guard is enforced.)
- **Workflow toolkit.** Which one drives feature and bug-fix subagents:
  - pstack (https://github.com/cursor/plugins/tree/main/pstack): poteto-mode
    Feature and Bug fix playbooks, `poteto-agent` subagents.
  - Spec Kit (`specify init`): specify → plan → tasks → implement → converge.
  - None: plain instructions in the override.
  - Other: ask for the source.
  Also ask whether any existing toolkit in the repo should be removed.
- **Verification.** pstack `create-verification-skill`, an existing harness
  (Playwright, simulator, test scripts), or hand-written? What surface does a
  user touch (web UI, API, CLI, chat bot)?
- **Work queue.** GitHub issues labelled `bug` / `enhancement` (default),
  other labels, or another tracker (Notion, Linear)? **Which GitHub user's
  assignment selects loop work?** Default: only issues assigned to the
  maintainer are picked up; agents never assign or unassign (the guard
  enforces it). This keeps every issue on GitHub while the maintainer chooses
  the loop's work by assigning.
- **Where verification reports go.** As a PR comment (default; screenshots
  stay local), or a Notion database the PR comment links to (screenshots
  embedded). For Notion: get the parent page, check the connector can edit
  it, and build the database: properties Report (title), Verdict
  (Pass/Partial/Fail), PR status (Open/Merged/Closed), Repo, Kind
  (Feature/Bug fix/Upkeep), Mode (Offline/Live), PR, Issue, Branch, Commit,
  Verified at, Report ID; views All reports (newest first, quick filters),
  Awaiting review (PR open), Needs attention (Fail or Partial), By verdict
  (board), Calendar. Put a callout at the top saying the reports come from
  "<maintainer>'s harness", what it does, that agents never merge, and whom
  to ask; add "How to read a report". Test one `notion-create-file-upload`
  with a real screenshot. Ask whether screenshots may show the test
  documents.
- **Order of new work.** When many issues are eligible, which go first?
  Default: lowest issue number. Ask whether readiness should rank first (for
  example, issues whose demo and sample documents already exist in a
  reference repo). There is no cap on PRs waiting for review unless the user
  asks for one.
- **Approval gate.** Should issues be able to ask for "research and propose a
  plan, wait for my approval"? Default: yes, triggered by an
  `## Approval gate` section in the issue body (template section 2).
- **Bugs the loop finds.** Default: the orchestrator opens real app bugs found
  by the verification upkeep pass as unassigned `bug` issues (deduplicated
  against open issues). They wait for the maintainer to assign them.
- **Merge policy.** Default: agents never merge, approve or push to main.
- **Schedule.** Set it up here, in another harness, or manual runs only?
  Default schedule: one hourly run, each in a fresh chat (step 8), at most 3
  active subagents, 3 spawns and 2 new tasks per run.
- **PR conventions.** Read them from the repo (merged PR titles, templates,
  user-level instructions). Ask only if they conflict.

## Step 2. Pre-flight

For each repo:

1. `git status --short`. If there is uncommitted work, ask, then commit it on
   its current branch (stage by name; do not push).
2. `git switch main && git pull --ff-only`.
3. `ls -a` the repo root, `.claude/`, `.agents/`, `.agent-loop/`, and read
   `.git/info/exclude`, `AGENTS.md`, `CLAUDE.md`, any existing
   `AGENTS.override.md` / `CLAUDE.local.md`. Back up anything you will change
   (hard rule 2).
4. Note the repo's test, lint and build commands, CI workflows (some repos have
   none; then the subagent's full test run is the gate), and how it runs
   locally.

## Step 3. Install the toolkit (project-scoped)

- Add the exclude block from `assets/references/exclude-block.txt` to each repo's
  `.git/info/exclude` before creating any harness file. Tracked files under
  those paths stay tracked (exclude rules only affect untracked files). If the
  user's toolkit or verify skill needs another local path, add it to the block
  and to `HARNESS` in `guard.sh`.
- **pstack:** it ships as a Cursor plugin. Clone `cursor/plugins` into the
  scratchpad, copy `pstack/skills/*` to `.claude/skills/`, `pstack/agents/*`
  to `.claude/agents/`, symlink each skill into `.agents/skills/` for Codex,
  and record the version in `.claude/skills/.pstack-version`. Cursor-only
  pieces need the adaptations listed in `assets/references/override-template.md`
  ("Toolkit adaptations").
- **Spec Kit:** `specify init --here --integration claude` (and/or `codex`),
  then keep `.specify/`, `specs/` and the `speckit-*` skills excluded.
- **Removing a toolkit:** tracked → open an issue (hard rule 4) and tell the
  override to ignore it until the issue merges. Untracked → back up, then
  delete.

## Step 4. Verification skill

Each repo needs a scripted way to prove behaviour on the real surface. If the
user chose pstack, follow its `create-verification-skill` SKILL.md, writing to
`.claude/skills/verify-<app>/` (not `.cursor/`). Delegate one subagent per
repo, in parallel. Give each these requirements, which the loop depends on:

- **Isolation per run**: a run id, free ports, throwaway data (temp SQLite or
  an `initdb` Postgres cluster), a generated API key, evidence under
  `.agent-loop/evidence/<run-id>/`. Never the developer's `.env` database.
  Prove in `doctor` that the app uses the throwaway store.
- **Worktree-safe**: resolve the root with `git rev-parse --show-toplevel`;
  load the worktree's code, not the main checkout's.
- **Offline by default**, live model calls opt-in; say which features need
  live.
- **Cross-repo pairing**: a frontend skill takes the backend path from an env
  var so a frontend worktree can test against a backend worktree.
- Helpers: `launch`, `doctor`, `drive`, `cleanup` scripts; cleanup kills only
  what it started and keeps evidence.
- **Screenshots**: capture the browser window, not the full page. An app
  with a fixed-height shell turns full-page captures into tall, mostly blank
  images, and Notion shrinks those. After each capture, compare the page's
  scroll height with the window height; when the page is taller, record a
  flag in the drive's result and print it. The report lists the flags: a
  page that scrolls into blank space is an app layout bug. Notion's API
  cannot set an image's display width, so crop to the element under test
  when its text must be readable.
- Proved once end to end before hand-over.

Then prove it yourself from a real worktree (step 7). See
`assets/references/lessons.md` for the traps the earlier setups hit.

**Feature map.** Each verify skill carries `features/README.md` (index,
conventions, proof rules, a `Full sweep` order) plus one file per feature, in
the shape of https://github.com/poteto/verification-skill-example. Every repo
with a user surface gets one, backends included (their user is the API
consumer). Add a journeys file only when flows cross several features in ways
a single feature file cannot drive.

**Keeping it honest.** The map is local-only, so team PRs never update it.
Wire two mechanisms into the override (template section 7):
- per task: the subagent updates and re-drives the feature files it touched;
  the orchestrator copies them to the main checkout after merge;
- upkeep: the orchestrator runs `maintain-verification-skill` (pstack) or an
  equivalent audit in a worktree when `main` has app-path commits since the
  SHA in `.agent-loop/maintain/<skill>.sha`, at most once a day. Seed that
  SHA at setup time. Ask the user how much live (paid) driving the pass may
  do.

## Step 5. Write the instructions

Write `AGENTS.override.md` per repo from `assets/references/override-template.md`.
Fill every section from the repo's real code and conventions. **Split the
instructions by reader**, because the harness loads `AGENTS.override.md` into
every agent: the override keeps what every agent needs (sections 0, 1, a
short section 2, 4, 5, 6, 7, a short section 8, interactive work); the
orchestrator-only parts (full section 2, 3, the upkeep pass, 8, 10 and the
harness setup) go in `.agent-loop/orchestrator.md`, which only the
orchestrator reads. In a multi-repo setup there is one orchestrator file, in
the orchestrator repo; each repo has its own agent-facing override. Keep each
override under about 16 KB. Write `CLAUDE.local.md` as exactly:

```
@AGENTS.override.md
```

Follow the repo's writing-style rules (for example ASD-STE100) in both files.

## Step 6. Loop tooling and guard

Copy into each repo's `.agent-loop/`:

- `assets/references/verification-report-template.md` → `.agent-loop/templates/verification-report.md`
  (`worktree.sh` copies `.agent-loop/templates/` into every worktree).

- `assets/scripts/worktree.sh` → `.agent-loop/worktree.sh`. It creates branches with
  the usual prefixes (`feat/`, `fix/`, `hotfix/`, `refactor/`, `docs/`,
  `chore/`, `test/`) and their worktrees under `../<repo>-worktrees/`. Branch
  names carry no agent marker: `new` records each branch it creates in
  `.agent-loop/branches.tsv`, the loop's ownership registry (`owned <branch>`
  checks it), and refuses any name that already exists locally or on `origin`
  so it never takes over a human branch. It also copies the local-only files,
  symlinks `.venv`, and APFS-clones `node_modules` (`cp -c`; a symlink breaks
  Turbopack). Add other dependency dirs the repo needs.
- `assets/scripts/start.sh` → `.agent-loop/start.sh`: the one-call run start (lock,
  dead-lock takeover, `state.sh check`, automation memory line). Idle runs
  need no other call. Prove it: `start.sh` prints `CHANGED` and holds the
  lock; remove the lock after the test.
- `assets/scripts/state.sh` → `.agent-loop/state.sh`: the per-run change check
  (`check` / `save`). Set its repos, assignee and upkeep paths. Prove it:
  `save` then `check` must print UNCHANGED (exit 10); delete
  `.agent-loop/state/fingerprint` afterwards so the first real run is full.
- `assets/scripts/guard.sh` → `.agent-loop/hooks/guard.sh`, and
  `assets/scripts/settings.local.json` → `.claude/settings.local.json` (merge it into
  an existing file; never overwrite). It blocks `gh pr merge`, approvals,
  merge calls through `gh api`, and pushes to main or master. It also blocks
  `git add -f` of a harness path, a commit with a staged harness file, and a
  push while any unpushed local commit adds one (it checks the hook cwd and
  every `cd X` / `git -C X` target, so it covers worktrees and the other repo
  of a multi-repo setup). The settings file also denies the desktop app's
  auto-merge tool. Other harnesses wrap the same script in their own
  pre-command hook: it reads `{"cwd", "tool_input": {"command"}}` JSON on
  stdin and exits 2 to block.
- The guard scans command text, so a command that merely *mentions* a blocked
  string (a heredoc writing a script, a test case) is blocked too. Write such
  files with the editor tool, and keep guard test cases in a script file.
- Recommend GitHub branch protection on `main` (required approving review,
  no admin bypass). Do not change GitHub settings yourself.

## Step 7. Prove the harness

Before you report done:

1. Run `bash assets/scripts/test-guard.sh <repo>/.agent-loop/hooks/guard.sh`. It
   builds a throwaway repo with a bare origin and checks 29 cases (merge,
   approval, push to main, issue assignment, force-add, staged harness file,
   unpushed commit adding a harness file, worktree pushes from a main checkout, and the allowed loop commands such
   as an unassigned `gh issue create`). All must PASS. Then
   pipe a `git commit` check through the installed guard with each real repo
   as `cwd`; it must exit 0 (no false positive on the user's own branches).
2. Audit the excludes with the global ignore switched off. Every harness path
   must print, and `git status --short` must not list any of them:
   `git -c core.excludesFile=/dev/null ls-files --others --ignored --exclude-from=.git/info/exclude --directory`
3. `worktree.sh new test/harness-check`, then in the worktree: verify-skill
   `launch` → `doctor` → one drive → `cleanup`. For cross-repo setups, pair a
   frontend worktree with a backend worktree. Then `worktree.sh remove` both,
   and check that no process is left and `git status` is clean in every main
   checkout.
4. Confirm `CLAUDE.local.md` loads the override (start a new session or check
   the instructions list).

5. For Codex, prove hook dispatch in the actual scheduled app chat. Shell
   calls, including `exec_command` and nested code-mode shell calls, match
   `Bash`. A `Bash|mcp__.*` matcher does not need a literal `exec_command` entry.
   Use one harmless shell call:
   `printf '%s\n' 'gh pr merge GUARD_PROBE_DO_NOT_EXECUTE'`.
   It only prints text if the hook is absent. The installed guard must reject
   it before execution with `Command blocked by PreToolUse hook` and its
   merge-denial reason. If it prints successfully, stop unattended work.
   Saved trust hashes, `/hooks` status in another process and direct script
   tests do not prove enforcement in the scheduled chat. Reload the app after
   installing or trusting hooks from another process, then repeat the probe
   there. Keep fresh CLI proof separate from scheduled app proof.

## Step 8. Schedule or hand off

Schedule **one hourly run, each in a fresh chat**. Never one chat per day
with hourly runs inside it: every model call re-sends the whole chat, so the
second setup measured an idle hourly run at about 1M input tokens by evening
(context grew from 44k to 222k tokens over 8 runs). GitHub, git and
`.agent-loop/` carry all state between runs.

- Each run's first call is `.agent-loop/start.sh <automation-id>`
  (`assets/scripts/start.sh`, which runs `assets/scripts/state.sh`; edit its repo list,
  assignee and upkeep paths). On `LOCKED` or `UNCHANGED` the run ends after
  that one call. Put this first call in the automation prompt itself, so the
  model reads nothing before it. The first
  run of each local date is always full. Each run that acts ends with
  `state.sh save`, except a run that leaves an action undone (a blocked
  push, a failed publish): it skips the save so the next run retries.
- Codex: one hourly automation that opens a new chat per run (not a
  heartbeat attached to an existing chat). Claude Code desktop: an hourly
  local scheduled task. Elsewhere: an hourly cron that starts a new session.
- If the user schedules it in another harness, give them the run prompt from
  the orchestrator file's section 10 and the list of local files to carry.

Report: what was installed where, what was removed and where its backup is,
what was proved and how, and what was not proved (for example live model
drives skipped to save cost).
