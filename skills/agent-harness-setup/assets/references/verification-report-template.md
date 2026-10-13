<!--
Verification report template. The subagent fills it in and saves it as
.agent-loop/reports/<branch-slug>.md in its worktree. Screenshots are local
paths relative to the checkout root; the orchestrator uploads them when it
publishes the report (Notion, or the PR comment fallback).
Keep every heading. Write "n/a: <reason>" under a heading that does not apply.
-->
---
title: <PR title, e.g. feat(search): add a date filter>
verdict: Pass | Partial | Fail
repo: <repo>[, <repo>]
kind: Feature | Bug fix | Upkeep
mode: Offline | Live
pr: <PR URL, filled in by the orchestrator>
issue: <issue URL>
branch: <branch>
commit: <short SHA the drives ran on>
verified_at: <YYYY-MM-DDTHH:MM:SSZ>
---

## Summary
<2-3 sentences: what changed for the user, and what this report proves.>

## Gates
| Check | Command | Result |
|---|---|---|
| <lint> | `<command>` | <pass / fail, counts> |

## Drives
### <Feature> — <entry point> (`<feature-id>`)
1. <user action> → <observed result>
2. <user action> → <observed result>

![<what the screenshot shows, before>](.agent-loop/evidence/<run-id>/<scenario>-<time>/01-<step>.png)
![<what the screenshot shows, after>](.agent-loop/evidence/<run-id>/<scenario>-<time>/02-<step>.png)

**Proof:** <API response excerpt, stored value read back, network.jsonl line>
**Judgment:** <holds / does not hold> against the feature file's proof: <why>

## Skipped or unverified
- <entry point>: <reason, e.g. live-skipped (cost), unreachable: needs X>

## Risks and follow-ups
- Page-height flags (the drive's result `flags`): <none | step, page height vs window, and whether the page really scrolls into blank space>
- <risk or follow-up>

<!-- Evidence directory: .agent-loop/evidence/<run-id>/ -->
