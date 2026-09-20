# skills

Portable AI-agent skills. Each skill's canonical instructions live in one file,
`skills/<name>/SKILL.md` — plain markdown, no vendor-specific syntax baked into the prose. Every
other tool gets a thin adapter generated from that file, not a rewrite.

## Skills

| Skill | Status | What it's for |
|---|---|---|
| [eval-driven-prompt-tuning](skills/eval-driven-prompt-tuning) | Beta | Raise an LLM pipeline's accuracy against a labelled eval set without touching the model or code |
| [model-feasibility-study](skills/model-feasibility-study) | Beta | Run an empirical build-vs-buy / model-choice feasibility study backed by experiment |

**Beta** means the skill is still being tested against real work and the steps may change —
usable, but don't treat it as final. Each skill's own README and its SKILL.md's status line say so
too.

## Use it

**Claude Code** — this is the canonical format already. Either:
- clone the repo and symlink (or copy) `skills/<name>` into your project's `.claude/skills/`, or
- add this repo as a plugin marketplace, if you set one up (not included here by default — this
  repo intentionally ships without a `plugin.json` so it stays usable outside Claude Code too).

**Cursor, Copilot, Windsurf** — run the adapter build script, then commit or copy the generated
files into your project:

```
./adapters/build.sh
```

This regenerates, from every `skills/*/SKILL.md`:

| Tool | Output |
|---|---|
| Cursor | `.cursor/rules/<name>.mdc` — thin, points at the canonical `SKILL.md` |
| Copilot | `.github/copilot-instructions.md` — inlines every skill's body (Copilot has no file-include) |
| Windsurf | `.windsurfrules` — same, inlined |

The generated files are checked in at the repo root as a working example; re-run the script after
editing any `SKILL.md` to keep them in sync.

**Any other tool / manual** — copy the body of a `SKILL.md` straight into your agent's system
prompt or a chat message. It's self-contained and reads as a standalone prompt.

## Adding a skill

1. `skills/<name>/SKILL.md` with `name:`/`description:` frontmatter and the instructions.
2. `skills/<name>/README.md` — what it does, which tools it's verified on.
3. `./adapters/build.sh` to regenerate the per-tool files.
4. Optionally symlink it into `.claude/skills/<name>` for local Claude Code use.
