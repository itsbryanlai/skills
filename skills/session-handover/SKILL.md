---
name: session-handover
description: Write a copy-paste handover so a fresh agent session can pick up where this one leaves off, read-only until the user gives the green light. Use when the user wants to continue in a new session, asks for a handover, handoff, or "continue elsewhere" summary, or is about to clear or compact a long conversation they want to resume.
---

# Session handover

> **Status: Stable.** Run against enough real session hand-offs that the steps are proven — still expect refinements.

The reader is a fresh agent with **zero memory of this conversation** and no access to it. The
handover is everything it will know. The user pastes it in as the first message.

## Output

One fenced markdown block, nothing else inside it, so the user copies it in a single click. A line
or two outside the block is fine (what you left out, what to verify). Write it from the
conversation, not from asking the user questions; ask only if the project itself is unidentifiable.

## Sections

Include each that has content; drop the ones that don't. Every claim is **checkable** — a path, a
command, a commit — so the new agent verifies instead of trusting.

1. **Opening instruction** — first lines of the block, verbatim in spirit: *This is a handover.
   Your job now is read-only understanding: read the referenced material, restate your
   understanding briefly, then wait. Do not edit, run, or start any work until the user gives the
   green light.*
2. **Background** — the project and goal in a few sentences: what it is, why it exists, who it is for.
3. **Current status** — done, in progress, blocked. Name the exact files, branches, or commits
   touched, and the state of tests or builds. Mark what is **verified** versus **assumed**.
4. **Decisions and rejected paths** — what was settled and the reason; what was tried and dropped,
   so the new agent does not re-propose it.
5. **References** — absolute paths or URLs to the docs, guidelines, `AGENTS.md`/`CLAUDE.md`, specs,
   and key source files, each with one line on why to read it, in reading order. Point; don't
   paste the contents.
6. **Preferences** — the user's stated working style for this session: tone, format, tools,
   things they corrected. Quote corrections as given.
7. **Next steps** — ordered, concrete, each with a clear done-condition. Mark which are awaiting
   the user's decision.
8. **Open questions and gotchas** — unresolved choices, traps hit, environment quirks.

## Completion criterion

Read the draft as the fresh agent: every named file, term, and acronym resolves from the block or
a reference in it, and the next step can be started without asking what "it" refers to. Fix any
miss before delivering.

## Exclusions

Secrets, tokens, and credentials stay out — name where they live instead. Leave out chat history
that no longer bears on the next steps.
