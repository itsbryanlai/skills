# AGENTS.md

This repo is a pack of **tool-neutral agent skills**. Each skill's canonical instructions live in
one file, `skills/<name>/SKILL.md`; every other tool gets a thin generated adapter. Read
[README.md](README.md) for the user-facing overview.

## Layout

- `skills/<name>/SKILL.md` — canonical instructions. The only file to hand-edit for behaviour.
- `skills/<name>/README.md` — what it does, status, tools it is verified on.
- `skills/<name>/assets/` — optional scripts easier to ship than describe.
- `adapters/build.sh` — regenerates `.cursor/rules/*.mdc`, `.github/copilot-instructions.md`,
  `.windsurfrules`. **Never hand-edit those outputs**; they are overwritten wholesale.
- `.claude/skills/<name>` — symlinks to `skills/<name>` for local Claude Code use.

## Adding or changing a skill

1. Write `skills/<name>/SKILL.md` and `README.md`, mirroring the existing skills.
2. Run `./adapters/build.sh`, then commit the regenerated files with the skill.
3. Add the symlink: `ln -s ../../skills/<name> .claude/skills/<name>`.
4. Add a row to both tables in `README.md` (Skills, Tool compatibility). Mark tools you did not
   run it on as `not evaluated`; never mark ✅ untested.

## Writing a skill that works in any agent

Load the `writing-for-agents` skill first when it is available; its rules apply in full. On top:

- **Frontmatter is `name:` and `description:` only**, `name` equal to the directory name. Write
  `description` on one line (`build.sh` reads one line) as the trigger pointer: what the skill is,
  then the distinct cases that fire it, then what it is not for. No tool-specific keys.
- **Body is plain markdown.** Describe behaviour in tool-neutral terms ("search the codebase",
  "run a command"), not named tools, slash commands, or vendor syntax. Copilot and Windsurf get
  the body inlined into one file, so it must read as a standalone prompt.
- **Start the body** with the title, then the status line: `> **Status: Beta|Stable.** …`. Keep it
  in step with the skill's README and the README table. New skills are Beta.
- **Self-contained.** No relative links to other files in the pack: adapters inline only the body,
  so links break. Link out to external URLs only where the skill can still run without them.
- **`assets/` stay optional.** The adapters don't carry them, so `SKILL.md` must say what to do
  when a script is absent (write the equivalent) and not depend on it.
- **Steps end on a checkable completion criterion**; state the target behaviour positively.
- **Keep it short.** Disclose bulk reference into `assets/` or a clearly marked section rather
  than sprawling the main flow; cut what the model already does by default.
- **Never inline secrets**, absolute user paths, or project-specific names.

## Verifying

No test suite. After edits: run `./adapters/build.sh`, check `git status` shows only intended
changes, and confirm each `SKILL.md` description is a single line.
