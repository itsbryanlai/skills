# agent-harness-setup

**Status: Beta** — set up and run on three repos so far; the steps may still change.

Set up a personal, local-only agent loop for one or more repos: an orchestrator turns GitHub
issues assigned to you into reviewed PRs, using subagents in git worktrees, a project verification
skill, and a guard that blocks merges and keeps harness files out of commits. Nothing it creates
is committed to the target repos; the team only sees the PRs. It asks which workflow toolkit
(pstack, Spec Kit, none) and verification approach to use, and includes the token-cost rules
measured on real runs (fresh chat per run, a one-call idle check, spawn caps).

Verified on: Claude Code (setup), Codex (scheduled runs). The scripts in `assets/` assume macOS
(`stat -f`, BSD `find`, APFS clones).

See [SKILL.md](SKILL.md) for the full instructions. It works without `assets/`: it says how to
write the equivalent scripts when they are absent.
