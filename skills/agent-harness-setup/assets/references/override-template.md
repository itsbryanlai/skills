# AGENTS.override.md template

Copy the structure. Replace every `<...>` with facts from the repo. Delete a
variant block that does not apply. Keep the section numbers: other files
and prompts cite them. Section 9 (mistakes list) is optional and
repo-specific; start it only when the user reports a mistake to remember.

Multi-repo: the orchestrator repo's file holds sections 2, 3, 6 (orchestrator
side), 8 (cleanup) and 10 for all repos. Every other repo's file keeps
0, 1, 4, 5, 6 (subagent side), 7, 8 (its worktree script), and short
pointers for 2–3 and 10 that restate the no-merge rule.

---

```markdown
# Local agent instructions: <repo> agent loop

Local-only file. Codex reads it in place of `AGENTS.md`; Claude Code loads it
through `CLAUDE.local.md`. It is the single source of truth for both. Edit this
file, never `CLAUDE.local.md`.

**Read `AGENTS.md` first.** Codex skips `AGENTS.md` when this file exists, so
its rules apply here in full<, except: <sections this file replaces, e.g. a
tracked Spec Kit workflow pending its removal issue>>.

<Multi-repo: name the other repos, their paths, and which checkout runs the
orchestrator.>

## 0. Local-only files: never commit, never push

Everything below is personal tooling. The team has not adopted it.

- `AGENTS.override.md`, `CLAUDE.local.md`, `.agent-loop/`, `.claude/skills/`,
  `.claude/agents/`, `.agents/skills/`, `.claude/settings.local.json`
  <, `.specify/`, `specs/` for an untracked Spec Kit>.
- Every one of them is listed in `.git/info/exclude`. That file is per clone,
  shared by all worktrees, and invisible to other contributors. **Never add
  them to `.gitignore`**, never rely on a global ignore, and never edit tracked
  files to mention them. A new local-only path gets a line in
  `.git/info/exclude` and in the guard's `HARNESS` pattern before it is
  created.
- The guard (`.agent-loop/hooks/guard.sh`) enforces this in Claude Code. It
  blocks `git add -f` of a harness path, a commit with a staged harness file,
  and a push while any unpushed commit adds one. Do not work around it; unstage
  the file or rewrite the local commit.
- Before every commit run `git status --short` and stage files by name. Never
  `git add -A` or `git add .`.
- A PR body or comment may describe what was verified. It must not ask
  reviewers to use these files.
- Before deleting or overwriting any untracked or excluded file, copy it to
  `<backup-root>/<what>-<date>/`. Git cannot restore it.

## 1. The rule that matters most: do not take the shortest path

Coding agents take the shortest path to the stated objective. Shortest is not
correct. **Before changing anything, understand how the surrounding system
already works and follow the repository's conventions, even when a narrower
patch would make the immediate test pass.**

The example that created this rule: an agent wired a new capability as a hook
that claimed every chat mention. It met its own objective and broke the other
capabilities sharing that path, because it never traced how they were routed.

Before writing code, every agent must be able to answer:

1. What is the entry point for this behaviour, and what runs before and after
   it? (<Name this repo's real entry points and order.>)
2. Which existing module, helper or pattern already owns this kind of work?
   Extend it rather than adding a parallel path.
3. What else shares the path being changed, and how is each verified to still
   work? (<Name shared modules, other consumers, the paired repo.>)
4. Which <design principle / invariant / ADR / constitution article> applies?

If an answer is unknown, find it in the code. If the code cannot answer it,
it is a clarification question (section 6).

### Always enforced: atomic commits and modular design

- **Atomic commits.** Each commit is one logical change that builds and passes
  its tests on its own: a refactor, a fix, a feature step, its docs. Never mix
  unrelated changes, and never leave a commit that only works with the next
  one. A commit message says what changed and why. Fixes after review or CI
  are new commits on the branch, not edits folded into unrelated ones.
- **Modular design.** Put code in the module that owns the behaviour, behind
  the seams the repo already uses (<name them>). One responsibility per
  function and module; no reach-ins to another module's private state; no
  copy-paste of logic that already lives elsewhere. If the right home does not
  exist, create it following the existing layout.

The orchestrator rejects work that breaks either rule, even when tests pass.

## 2. The agent loop

A scheduled orchestrator session performs **runs** (section 3). Each run reads
<GitHub> state, decides the work, and spawns **subagents** that do the work in
their own git worktrees. Humans review and merge PRs.

**No agent merges a PR, approves a PR, enables auto-merge, or pushes to
`main`. Merging into `main` always needs human review.** The hook
`.agent-loop/hooks/guard.sh` blocks these commands in Claude Code.

### Which issues the loop picks up

**Only open issues assigned to `<maintainer>`**, labelled `bug` or
`enhancement`<, in <repos>>. Assignment is the maintainer's go signal: every
issue stays on GitHub, and the maintainer chooses loop work by assigning it.
An unassigned issue, or one assigned to anyone else, is not loop work, even
when the loop opened it.

| Label on the issue | Workflow |
|---|---|
| `enhancement` | Feature (section 4) |
| `bug` | Bug fix (section 5) |

Issues with neither label are ignored, even when assigned.

**Approval gate** (optional, ask the user). An issue whose body has a
`## Approval gate` section runs in two phases. Phase 1: read-only research
(<pstack: Investigation playbook>), other repos through detached worktrees
only; the orchestrator posts findings and a phased plan as one `🤖 agent-loop`
issue comment ending "Reply `approved` to start implementation, or comment
with changes." and waits. Phase 2 (section 4 or 5) starts only after a newer
human comment approves; a change request means a revised plan.

**Agents never assign issues.** No agent adds or removes an assignee. The
guard blocks `--assignee`, `--add-assignee` and the assignees API.

**Issues the loop opens.** Only for a real app bug found by the verification
upkeep pass (section 7): unassigned, labelled `bug`, in the repo that owns
the broken code. Body starts with `🤖 agent-loop`: symptom, repro steps,
evidence path, commit seen on. Search open issues first and comment on a
match instead of opening a duplicate.

### Roles

**Orchestrator** (one per run)
- Owns all GitHub writes: pushes its own branches, opens PRs, posts comments,
  opens unassigned issues for real app bugs (above), answers subagent
  questions, watches CI. Never assigns an issue.
- Never writes application code itself. It reviews.
- Is the only agent allowed to open a PR. No agent may merge, approve, close a
  human's PR, or push to `main`.

**Subagent** (one per task)<, spawned as `subagent_type: "poteto-agent"`>
- Works only inside its assigned worktree. Commits locally. Never pushes,
  never touches GitHub, never edits a main checkout.
- Never answers its own clarification questions (section 6).
- Returns: branch, commits, test results, verification report path,
  verification-map changes, section 1 answers, open risks.

### Concurrency: at most <3> tasks

A **task** is one unit of work handled by one subagent in one worktree. A
task may cover several related issues.

- At most <3> subagents are active at any moment in the session, across all
  runs<and repos>. New work, PR follow-ups and CI fixes all count.
- An open PR waiting for human review is not active. Resuming its worktree
  makes it active again.
- At capacity, start nothing new.
- At most <3> spawns per run, counting retries and reviewers, and at most
  <2> new-work tasks per run<, because the loops share one quota>.
- Resume a failed or incomplete worker with `send_message`; spawn fresh only
  when it is gone (a later run, or it died). A fresh worker pays the full base
  context again and re-reads everything.
- Priority for a free slot: CI failures and human comments on open loop
  PRs, then unfinished worktrees, then a due verification upkeep pass
  (section 7), then new issues.

### Identifying agent-written content

Every comment the orchestrator posts starts with the line `🤖 agent-loop`.
Any comment without it is human.

Branch names follow the usual conventions with the issue number first:
`feat/<n>-<slug>` (enhancement), `fix/<n>-<slug>` (bug), and `hotfix/`,
`refactor/`, `docs/`, `test/`, `chore/` where they fit <use the forms the
repo's history already uses, e.g. `feat/` vs `feature/`>. The name does not
mark the loop's work. The loop owns a branch only if `worktree.sh new`
created it and recorded it in `.agent-loop/branches.tsv` (check with
`worktree.sh owned <branch>`). `new` refuses names that already exist locally
or on `origin`, so the loop never takes over a human branch. A PR on any
other branch is human-owned; the loop does not touch it.

## 3. Orchestrator: one run, step by step

**Context budget.** Every orchestrator call re-sends the whole chat, so a
file read early is paid again on every later call. Do not read worker
material (toolkit skills, the worker agent file, `interrogate` references):
name it in the brief. Do not read whole source files: review with
`git log --stat`, `git diff --stat` and the hunks you check. Read a report's
verdict and flags first. Cap command output.

0. **Start.** The first call is `.agent-loop/start.sh <automation-id>`
   (`assets/scripts/start.sh`). It takes the lock, runs `state.sh check`, and writes
   the automation memory line for idle runs. It takes over a dead lock: older
   than 6 hours, or no Codex session for this repo still mid-turn (a run
   stopped by the usage limit is not mid-turn). `LOCKED` or `UNCHANGED`:
   reply `no change` and end the turn. `CHANGED`: hold the lock; remove it
   at the end, also on failure. `ERROR`: retry once with authorized
   escalation, then stop without saving state.
1. **Sync.** `git switch main && git pull --ff-only` in every main checkout.
   Read `AGENTS.md` and this file once. `AGENTS.override.md` is already in
   context: do not re-read it.
2. **Collect state** from `.agent-loop/state/current.json`, written by
   `state.sh check` (lean lists: numbers, labels, `updatedAt`, CI results, only
   the loop's own PRs). Never list issues or PRs with bodies or comments; fetch
   one with `gh issue view` / `gh pr view` only when this run acts on it.
3. **Clean up** (section 8).
4. **Classify each assigned issue:** unassigned since an earlier run (a
   loop branch or PR exists) → withdrawn, start nothing new, note it;
   blocked (an open GitHub "blocked by" issue via
   `gh api repos/<repo>/issues/<n>/dependencies/blocked_by`, or a
   `## Blocked by` section naming an open issue) → skip every phase;
   PR on a branch the loop does not own → skip; open loop PR →
   step 6; waiting on a human answer → skip; worktree without PR → resume
   with a fresh subagent and the consolidated brief; otherwise new work.
5. **Plan new work.** Group issues by root cause or code path into tasks; do
   not run two tasks on the same code path in parallel. <Order of new issues,
   agreed with the user: e.g. prefer issues whose source material (a related
   demo and sample documents) already exists in <reference repo>, checked
   read-only on its `origin/main`; then demo only; then neither; lowest issue
   number first within a tier.>
   <Multi-repo: split cross-repo issues into one task per repo; backend first,
   backward compatible; the frontend verifies against the backend worktree.>
6. **Review open loop PRs:** human comments newer than the last
   `🤖 agent-loop` comment and failing checks; resume the worktree for
   changes.
7. **Spawn subagents** (free slots only): `worktree.sh new <prefix>/<n>-<slug>`; give the
   path, the issue text, the section 4 or 5 workflow, and section 1 verbatim.
   Make the brief complete so the worker needs no steering (acceptance
   criteria, decisions made, verification scope, report path). The worker
   creates its report file first and fills it as it goes.
8. **Wait, then answer questions** (section 6). Wait with one long
   `wait_agent` call (15 minutes or more), not short polls: every wake
   re-sends the whole chat. Message a worker only to answer a question or
   return review findings.
9. **Review each result:** diff traces to the issue; no local-only files;
   atomic commits and modular code (`git log --stat origin/main..HEAD`);
   section 1 answers hold; tests and verification report acceptable; docs
   updated where `AGENTS.md` requires. <pstack: at most one reviewer per
   diff, only for multi-module or cross-repo diffs: spawn one reviewer agent
   that applies the `interrogate` references itself; apply its lead judgment
   to the findings. Reviewers on the parent model add no model diversity, so
   one is enough.> Send failures back to the same subagent with
   `send_message`; spawn fresh only when it is gone.
10. **Open the PR** (ready, not draft) in the repo's title style, with
    `Closes #<n>`. No AI-attribution footers.
11. **Publish the verification report.** <Variant PR comment: post the
    report Markdown as the PR comment.> <Variant Notion: upload each
    screenshot with `notion-create-file-upload` (POST the file to the
    returned `upload_url` with the returned headers; swap the local path for
    `suggested_markdown`), create one page in the reports database with the
    front-matter fields as properties and the body as content, save its URL
    beside the report as `<branch-slug>.notion`, and post a short PR comment:
    `🤖 agent-loop`, verdict, gate results, skipped items, report link. Fall
    back to the PR-comment variant if Notion is unreachable. A follow-up
    round updates the same page.> Copy the report to the main checkout's
    `.agent-loop/reports/`.
12. **Watch CI** (`gh pr checks --watch`); fix failures through a subagent;
    stop after three rounds and ask on the PR. Green = merge-ready. **Stop
    there. Never merge.**
13. **Finish.** One `🤖 agent-loop` comment per issue with the PR link. Remove
    the lock. One-line summary when nothing happened; notify only for a new
    or updated PR, a failure, or a question for a human.

## 4. Subagent: feature workflow (`enhancement`)

<Token budget, pstack variant: read `poteto-mode` once and only the named
playbook; open a principle's leaf skill only when applying it; `how` only on
the named subsystem; `architect` only when the change crosses a boundary or
repos; the worker writes the code itself (waive the mandatory nested
delegate and `arena`); no `interrogate` in workers — the orchestrator runs it
once, only on multi-module or cross-repo diffs.>

<Variant pstack>
Run the poteto-mode **Feature** playbook steps 1–7 without stopping for human
review; stop before step 8 (Opening a PR). The PR is the review gate.

<Variant Spec Kit>
Run `specify → plan → tasks → implement → converge` without stopping. **The
maintainer waives the Spec Kit review gates for loop features in this repo.**
Add `clarify` and `analyze` for <risky areas>. Artifacts live in `specs/`.

<Variant none>
Trace the entry point (section 1), name the data shape, implement in small
commits, write tests that fail without the change.

Always: answer the section 1 questions in the report; update the behaviour
reference (<spec / ADR / docs>) in its own commit; questions go to the
orchestrator (section 6); then verify (section 7), commit, report back.

## 5. Subagent: bug-fix workflow (`bug`)

<pstack: poteto-mode **Bug fix** playbook steps 1–5; stop before Opening a PR.>

1. Reproduce the symptom on the real surface (section 7). Find every caller
   of what you will change.
2. Reproduce it in a failing test; commit the test before the fix.
3. Fix the root cause where all callers route through.
4. Verify (section 7), commit, report the root cause in one paragraph.

## 6. Clarification protocol

A subagent never answers its own question: an agent defends work it has
already done. It returns the question to the orchestrator with the options
and evidence. <pstack: an empirical fork is settled with the Prototype
playbook, not asked.> The orchestrator decides from, in order: the issue and
its comments; repo conventions (code, ADRs, specs, docs); section 9. Product,
security, data-exposure or hard-to-reverse choices go to a human: post the
question on the issue (`🤖 agent-loop` first line), pause the task, resume
after a human replies.

## 7. Verification

### Unit tests
<Exact commands for the relevant subset and for the full gate (lint,
typecheck, tests, drift checks). Say whether CI exists; if not, the full
suite run is the gate.>

### Running app: `verify-<app>`
<launch / doctor / drive / cleanup commands, run from the worktree; which
features are offline vs live; pairing env var for multi-repo.>

### Keeping the feature map honest
- Per task: a behaviour change updates the touched `features/` files in the
  worktree copy and drives the new steps; the orchestrator copies them to the
  main checkout after the PR merges.
- Upkeep (orchestrator, at most once a day): due when `main` has commits since
  `.agent-loop/maintain/<skill>.sha` touching <app paths>. Run
  <`maintain-verification-skill` | the chosen audit> in a
  `chore/maintain-verify-<skill>-<date>` worktree. Outcome `changed` edits the
  worktree copy (no PR, the skill is local); the orchestrator copies it back.
  Live drives: <limit agreed with the user>. A product gap (the app is
  broken, not the map) becomes an unassigned `bug` issue (section 2) and a
  line in the run summary; the loop fixes it only after the maintainer
  assigns it. Then update the
  SHA, save notes in `.agent-loop/maintain/`, remove the worktree.
- Full sweep: walk `features/README.md`'s `Full sweep` order.

### Verification report
The subagent fills in `.agent-loop/templates/verification-report.md` (from
`assets/references/verification-report-template.md`) and saves it as
`.agent-loop/reports/<branch-slug>.md`: front matter (title, verdict, repo,
kind, mode, PR, issue, branch, commit, verified_at), then Summary, Gates,
Drives (steps, before and after screenshots as image lines with local
evidence paths, proof, judgment), Skipped or unverified, Risks. The
orchestrator reviews it and publishes it (section 3 step 11).

## 8. Worktrees and cleanup

- `.agent-loop/worktree.sh new|resume|remove|list`; worktrees under
  `../<repo>-worktrees/`. The script copies local-only files and links or
  clones dependencies.
- Each run: for a loop worktree whose PR is merged or closed (or whose
  issues are all closed with no PR), copy its `.agent-loop/reports/` and
  `.agent-loop/evidence/`, and its verify-map changes (merged only), to the
  main checkout, then `worktree.sh remove`. Never remove
  one with uncommitted changes unless its PR is merged or closed. Never touch
  other worktrees.

## 10. Setting the loop up in a harness

1. Clone; copy in the local-only files; `CLAUDE.local.md` = `@AGENTS.override.md`.
2. Exclude the section 0 paths in `.git/info/exclude`.
3. Install the toolkit (<source and version>).
4. Check `gh auth status`, dependencies, secrets the verify skill needs.
5. Guard in every harness before unattended runs (no merge, no harness files
   in commits); branch protection on
   GitHub recommended.
6. Do not edit global harness instructions or other repos for this setup.
7. Schedule one hourly run, each in a fresh chat (never one day-long chat:
   each call re-sends the whole chat). Each run starts with
   `.agent-loop/start.sh`; on LOCKED or UNCHANGED it ends after one call. No
   catch-up runs. Run prompt:

   > You are the agent-loop orchestrator for <repos>. Work in the <repo> main
   > checkout. Follow `.agent-loop/orchestrator.md` section 3 for one complete
   > run. The first call is `.agent-loop/start.sh <automation-id>`, before
   > reading anything. If it prints LOCKED or UNCHANGED, reply `no change`
   > and end the turn. Never merge a PR.

   Per harness: Codex — one hourly automation that opens a new chat per run;
   Claude Code desktop — an hourly local scheduled task; elsewhere — an hourly
   cron that starts a new session. GitHub, git and `.agent-loop/` are the
   source of truth; each run re-derives state.

## Interactive work outside the loop

When the maintainer works with an agent directly, sections 0, 1 and 7 still
apply, and so does the no-merge rule. Workflow phases run without gates only
inside the loop; interactively, stop where the maintainer asks.
```

---

## Toolkit adaptations

### pstack in Claude Code / Codex (it is written for Cursor)
- Model roles: set every role to `inherit-parent` (omit `model` on subagents)
  unless the user names models.
- `Task` = the Agent tool; `subagent_type: "poteto-agent"` needs
  `.claude/agents/poteto-agent.md`.
- Not shipped: `cursor-team-kit` (`/deslop`, `control-cli`, `control-ui`).
  Skip `/deslop`; the control skill is the repo's `verify-<app>`.
- Cursor's `/loop`, `/create-skill` and custom modes do not exist; use the
  harness's own equivalents (`skill-creator` for skills).
- `create-verification-skill` writes to `.cursor/skills/`; write to
  `.claude/skills/` and symlink into `.agents/skills/`.
- Off-limits under the no-merge rule: **Shipping** and **Autopilot-full**
  playbooks; **Babysit** only to merge-ready.
- Subagents stop before **Opening a PR**; the orchestrator opens PRs.

### Spec Kit
- Loop features waive the review gates explicitly (section 4); interactive
  sessions keep them.
- `specs/` is shared across worktrees by symlink to the main checkout;
  `.specify/feature.json` is per worktree.
