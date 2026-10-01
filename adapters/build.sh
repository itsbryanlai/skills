#!/usr/bin/env bash
# Generates per-tool adapters from skills/*/SKILL.md. SKILL.md is the only file
# to hand-edit; everything this script writes is regenerated wholesale on each run.
# Claude Code (.claude/skills) and Codex (.agents/skills) read SKILL.md natively, so
# they are plain symlinks and need no generation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p .cursor/rules

for skill_md in skills/*/SKILL.md; do
  dir="$(dirname "$skill_md")"
  name="$(basename "$dir")"

  description="$(sed -n 's/^description: *//p' "$skill_md" | head -1 | sed -e 's/^"//' -e 's/"$//')"

  # Cursor: thin rule that pulls in the canonical file via @-reference.
  cat > ".cursor/rules/${name}.mdc" <<EOF
---
description: ${description}
alwaysApply: false
---

See @skills/${name}/SKILL.md for the full instructions.
EOF
done

echo "Wrote adapters for $(ls skills | wc -l | tr -d ' ') skill(s):"
echo "  .cursor/rules/*.mdc"
