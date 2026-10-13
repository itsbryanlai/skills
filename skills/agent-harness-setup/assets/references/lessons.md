# Lessons from earlier setups

Each line cost real time once. Check them before you declare a step done.

## Setup safety
- `rm -rf` of excluded, untracked folders (`specs/`, `.specify/`) is permanent. Back up first.
- `Write` on an existing local file overwrites it silently. `ls -a` first; "updated" in the result means it existed.
- zsh aborts the whole command when a glob has no match (`rm -rf a speckit-*` does nothing). Use `find ... -exec rm` or `(N)`.
- A toolkit can be tracked in one repo and local-only in another. Check `git ls-files` before removing.
- Recovery, if it is too late: replay Write/Edit/Bash edits from `~/.claude/projects/**/*.jsonl` and Codex `apply_patch` calls from `~/.codex/sessions/**`, starting from the last full read, and check each step against the output the original session printed.

## Harness behaviour
- Codex reads `AGENTS.override.md` *instead of* `AGENTS.md`. The override must tell it to read `AGENTS.md` and name any section it replaces.
- `.claude/settings.local.json` is often globally git-ignored, so worktrees do not get it. `worktree.sh` copies it with the hook.
- Removing a worktree deletes its `.agent-loop/evidence` and reports. Copy them to the main checkout first.
- A git-excluded skill is not in a fresh worktree. `worktree.sh` copies `.claude/skills` and friends.

## Verification skills
- Next.js: one `next dev` per checkout. Launch must refuse, not kill, when the user's dev server runs.
- Next.js/Turbopack crashes on a symlinked `node_modules`. Use an APFS clone (`cp -cR`).
- Next.js: `process.env` beats `.env.local` only for keys that are set. Set every key named in `.env*` explicitly, even to blank.
- Seed scripts often force TLS or hold fixed passwords. Build the throwaway DB with the repo's schema and migration steps, and make a fresh user with a random password.
- A Python editable install points at the main checkout. Put the worktree on `PYTHONPATH` and have the server refuse to start from other code.
- `launch.sh` must record the server's pid, not its wrapper shell's pid.
- Services that always call a model need a replay mode (recorded replies) so offline drives are possible.
- An admin user may hit forced MFA. Drive as the least-privileged role that can reach the feature.

## Token cost (measured in the second setup, Codex, Oct 2026)
- 74M input tokens in two days, 96% cached, output only 0.17M. Cost is context size times model calls.
- The biggest driver was one day-long orchestrator chat with hourly runs inside it: per-call context grew 44k → 222k, so an idle run cost ~1M tokens. Use a fresh chat per run and a cheap change check (`state.sh`) that ends idle runs after one call.
- The harness auto-loads `AGENTS.override.md` into every agent. Keep orchestrator-only text in `.agent-loop/orchestrator.md`.
- Never list issues with `--json body,comments`: one embedded spec made each run re-read 26 KB.
- pstack's Feature playbook mandates a nested code delegate and `architect`; with `interrogate` in both worker and orchestrator, one task became 4–8 agents. Waive the delegate, gate `architect`, run `interrogate` once.

## Migrating an existing harness (single-repo loop, Spec Kit → pstack, 2026-10-12)
- Check for a live run before removing toolkit files: a Codex usage-limit stop kills the workers but leaves `run.lock`, which stalled the loop for 6 hours before `start.sh` learned to take dead locks over. Confirm the run is dead from the chat log before you remove toolkit files.
- In-flight worktrees may hold the old toolkit's artifacts (specs/ symlinks). Back up their local files, then resume or restart them as the user chooses; a clean restart is simplest.
- Old harnesses often have no guard at all. Install it (Codex `.codex/hooks.json` + `codex-guard.py`, Claude `.claude/settings.local.json`) and add repo-specific local files (for example `.env`, a simulator) to `worktree.sh`'s copy list.
- After switching branch naming, check for open PRs on the old prefix; register any that are still open, or say none are.

## Run cost (measured 2026-10-12, Codex, after the fresh-chat change)
- A full single-repo run cost 26M input tokens and 60% of a 5 h quota in 25 min. The causes: 60 s `wait_agent` polls and steering messages (each wake re-sends 120–170k tokens), fresh retry spawns, two `interrogate` reviewers per diff (both on the parent model, so no diversity), and the orchestrator reading worker skills and source files.
- Fixes: long waits, a complete brief, at most 3 spawns and 2 new tasks per run, resume workers with `send_message`, one reviewer per diff, an orchestrator context budget.
- Idle runs took 5–8 calls: the model read files before the lock, and `git fetch` failed in the sandbox (FETCH_HEAD) and forced an escalation. Use one `start.sh` call for lock + check + memory note, and never fail the check on a fetch error.
- A run killed by the usage limit leaves `run.lock`. `start.sh` takes over a lock when no Codex session for the repo is mid-turn (last `task_started`/`task_complete` event in its rollout log). Log mtime is not a liveness signal: opening a dead chat in the app writes to its log.
- Codex does not pass `exec_command`'s `workdir` to PreToolUse hooks. The guard then saw the main checkout (on `main`) and blocked every worktree push as "push from main". The guard now judges each push by its own `git -C` target or the last `cd`; the orchestrator pushes with `git -C <worktree> push`.
- Orchestrators ignored "wait 15 minutes" and polled `wait_agent` at the 60 s default. Name the value: `timeout_ms: 900000`.
- Full-page screenshots of a fixed-height app came out 4000–5300 px tall and mostly blank; Notion shrank them until they were unreadable, and it has no API for image width. Capture the window, and flag a page taller than the window: here it exposed a real bug (an absolutely positioned `sr-only` label escaping an unpositioned scroll list stretched the page).
