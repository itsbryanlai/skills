# model-feasibility-study

**Status: Stable** — run against enough real studies that the phases are proven, though they can still be refined.

Run an empirical feasibility study comparing candidate models, libraries, or approaches against a
decision someone has to make: problem framing, dataset provenance, controlled comparison,
standards-grade metrics, and a decision-maker-first report.

Verified on: Claude Code.

See [SKILL.md](SKILL.md) for the full instructions — it's tool-neutral and can be pasted into any
chat model or agent.

## assets/

`SKILL.md` is self-contained prose; `assets/` holds the one piece that is easier to ship than to
describe.

| File | What it does |
|---|---|
| [assets/build_report.py](assets/build_report.py) | Renders a study's `docs/*.md` into a single self-contained `report.html` — sidebar nav, figures inlined as base64, print stylesheet, `{{metric.key}}` substitution from `experiments/results/metrics.json`. Python 3, no dependencies. |

```
python3 assets/build_report.py <study-root>      # writes <study-root>/report.html
```

Markdown stays the source of truth so the study diffs in a pull request; the HTML is generated and
regenerated, never hand-maintained. The build **fails** on a `{{key}}` that `metrics.json` doesn't
define, which is what stops a hand-typed headline number from drifting after a re-run, and it warns
when the decision-maker doc runs past ~900 words or a figure has no caption.

Adapters that inline `SKILL.md` into a single prompt file (Copilot, Windsurf) don't carry this
script. `SKILL.md` tells the agent to write the equivalent if it isn't there — what matters is that
the readable artifact is generated, not that it comes from this exact file.
