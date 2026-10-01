# skills

Portable AI-agent skills. Each skill's canonical instructions live in one file,
`skills/<name>/SKILL.md` — plain markdown, no vendor-specific syntax baked into the prose. Every
other tool gets a thin adapter generated from that file, not a rewrite.

## Skills

| Skill | Status | What it's for |
|---|---|---|
| [eval-driven-prompt-tuning](skills/eval-driven-prompt-tuning) | Beta | Raise an LLM pipeline's accuracy against a labelled eval set without touching the model or code |
| [model-feasibility-study](skills/model-feasibility-study) | Stable | Run an empirical build-vs-buy / model-choice feasibility study backed by experiment |
| [session-handover](skills/session-handover) | Stable | Write a copy-paste handover so a new session can resume, read-only until you give the green light |

**Beta** means the skill is still being tested against real work and the steps may change —
usable, but don't treat it as final. **Stable** means it's been run against enough real work that
the steps are proven, though they can still be refined. Each skill's own README and its SKILL.md's
status line say so too.

## Tool compatibility

Having the file in the right place isn't enough — a skill also has to work with what that tool can
actually do. This is separate from the adapter setup below: the adapters get the instructions in
front of the tool, but they don't grant capabilities.

| Skill | Claude Code | Cursor | Codex |
|---|---|---|---|
| [eval-driven-prompt-tuning](skills/eval-driven-prompt-tuning) | ✅ | ✅ | ✅ |
| [model-feasibility-study](skills/model-feasibility-study) | ✅ | ✅ | ✅ |
| [session-handover](skills/session-handover) | ✅ | not evaluated | ✅ |

"not evaluated" is a gap in testing, not a claim that the skill fails. The table only covers the
tools actually tried; other AI coding tools (Copilot, Windsurf, xAI's Grok, etc.) aren't listed
simply because they're untested, not because they're known to be incompatible.

## Use it

**Claude Code** — this is the canonical format already. Either:
- clone the repo and symlink (or copy) `skills/<name>` into your project's `.claude/skills/`, or
- add this repo as a plugin marketplace, if you set one up (not included here by default — this
  repo intentionally ships without a `plugin.json` so it stays usable outside Claude Code too).

**Codex** — also reads `SKILL.md` natively. Symlink (or copy) `skills/<name>` into your project's
`.agents/skills/`, or into `~/.agents/skills/` for every project. This repo's own `.agents/skills/`
is a working example.

**Cursor** — run the adapter build script, then commit or copy the generated files into your
project:

```
./adapters/build.sh
```

This regenerates `.cursor/rules/<name>.mdc` from every `skills/*/SKILL.md` — thin rules that point
at the canonical file. They are checked in at the repo root as a working example; re-run the script
after editing any `SKILL.md` to keep them in sync.

A skill may also ship an `assets/` directory — scripts that are easier to ship than to describe in
prose. Copying only a `SKILL.md`'s text elsewhere loses those files, so a `SKILL.md` that relies on
one has to say what to do when it isn't there. See
[model-feasibility-study](skills/model-feasibility-study) for the pattern.

**Any other tool / manual** — copy the body of a `SKILL.md` straight into your agent's system
prompt or a chat message. It's self-contained and reads as a standalone prompt.

## Adding a skill

1. `skills/<name>/SKILL.md` with `name:`/`description:` frontmatter and the instructions.
2. `skills/<name>/README.md` — what it does, which tools it's verified on.
3. `skills/<name>/assets/` if it needs supporting scripts — optional, and `SKILL.md` must still
   work without them.
4. `./adapters/build.sh` to regenerate the per-tool files.
5. Optionally symlink it into `.claude/skills/<name>` and `.agents/skills/<name>` for local Claude
   Code and Codex use.
