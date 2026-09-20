# eval-driven-prompt-tuning

**Status: Beta** — actively being tested against real tuning runs, expect the steps to be refined.

Improve an LLM pipeline's accuracy against a labelled evaluation set when you may change prompts
but not models or code: validate the scoring harness, diagnose from existing artifacts before
spending API calls, measure run-to-run variance, and handle labels that turn out to be wrong.

Verified on: Claude Code.

See [SKILL.md](SKILL.md) for the full instructions — it's tool-neutral and can be pasted into any
chat model or agent.
