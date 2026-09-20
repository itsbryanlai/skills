---
name: eval-driven-prompt-tuning
description: Improve an LLM pipeline's accuracy against a labelled evaluation set when you may change prompts but not models or code. Use when given a target metric, a fixed dataset, a baseline to beat, and a list of ranked defects — or whenever asked to raise extraction/classification/mapping accuracy without retraining. Covers validating the scoring harness, diagnosing from existing run artifacts before spending API calls, measuring run-to-run variance, and handling labels that turn out to be wrong.
---

# Eval-driven prompt tuning

> **Status: Beta.** Still being tested against real runs — the steps are solid but expect refinements.

For work shaped like: *here is a pipeline at X% on a labelled set, here are the ranked defects,
raise it without touching the model or the code.*

The failure mode this skill exists to prevent is **spending a day fixing a defect that was never
real**, because the baseline was measured under a configuration nobody verified.

## The order that matters

1. Validate the scoring harness against the published baseline.
2. Verify what configuration the baseline actually ran under.
3. Diagnose every defect from existing artifacts, before any new run.
4. Measure run-to-run variance.
5. Only then change anything.

Steps 1, 2 and 4 are the ones people skip, and each one silently invalidates everything after it.

---

## 1. Reproduce the baseline before touching anything

Write your own scorer, run it on the **published output artifacts**, and check it reproduces the
published number **exactly — per item and in total**. Not approximately. If your scorer says 90.6%
and the report says 90.7%, find the difference before continuing; that gap is a bug in your
understanding of the metric, and every later delta inherits it.

Things that are routinely wrong on the first attempt:

- **Which fields are scored.** Derived/computed rows are often excluded. Count the scored fields
  and check the total matches the report's denominator exactly.
- **How records align to periods/columns.** Do not trust a column's stored index or label. Detect
  the meaningful columns structurally, and check every record — a minority of documents carry an
  extra leading column and silently shift.
- **Null vs zero.** A produced `0` may count as "no value" in the reference convention.
- **Tolerance.** If the report counts ±1 differences as errors, your scorer must too. A tolerance
  you invented inflates the score.

Only when per-item numbers match is the harness trustworthy.

## 2. Verify the baseline's configuration, not just its numbers

**A baseline is a number plus the configuration that produced it. You were given the number.**

Check, explicitly:

- Does the working tree match the deployed branch? Checkouts left on experiment branches are
  normal and invisible.
- Does the runtime config (model, parameters, prompt templates) match production?
- Does any prompt content live **outside** the repo — in a database table, a CSV, a config
  service? If so, does the local copy match production's copy?
- Was the baseline produced on production, or on a developer machine that may have carried local
  edits?

If you cannot verify production's state, say so and name the single query or check that would
settle it. Do not infer it from a file in the repo that *looks* authoritative — a preserved
"ORIGINAL" backup and the live edited file can differ on exactly the field in dispute.

Then **run your own control**: the untouched production configuration, scored by your validated
harness. That control, not the published number, is what your changes get compared against.

## 3. Diagnose from existing artifacts — spend zero API calls

If you have the model's previous output and the labels, every defect can usually be root-caused
before running anything.

**Recover the label's derivation, not just its value.** The label says an item should be 101,532;
it does not say why. Search the source records for the combination that produces it — subset-sum
over candidate lines works well for aggregation tasks. Do this across every item in the set:

- A rule confirmed on **all** items is safe to encode.
- A rule seen on **one** item is an anecdote. Record it; do not encode it.

Over-generalising from a single example is the most expensive mistake available here. If a defect
you were handed traces back to a prior session doing exactly that, say so — the fix is a revert,
not a new rule.

**Check the arithmetic of each error.** A shortfall that exactly equals one source line names its
own cause. Differences of 1–2 units usually mean summed components where a printed total was
wanted (independent rounding), not a mapping error.

## 4. Find every surface that carries instructions

Guidance is rarely in one file. Typically:

- the prompt template
- few-shot exemplars (**including their explanatory notes** — these are instructions and are
  frequently the strongest signal)
- per-item descriptions injected into the prompt from data
- rules embedded in the schema or field documentation

**These contradict each other more often than not.** Enumerate all of them for the item you are
fixing before writing anything, and check whether the thing you are about to "fix" is already
stated correctly somewhere and being overridden elsewhere. Note which surfaces are in scope for
you to change — if the decisive one is out of scope, say so and escalate rather than writing a
rule that will lose the fight.

## 5. Measure variance before attributing any delta

Run the **same configuration** two or three times. Temperature 0 does not mean deterministic.

Establish the noise floor before interpreting any result. A single run at this kind of scale can
easily swing by several per cent. Without the noise floor you will confidently attribute an
improvement, or a regression, to a change that caused neither.

Watch for **intermittent truncated output** — the model occasionally returns a short, valid
response that omits most of its answer, with no error logged. This costs a block of fields at once
and is the usual source of large swings. It is a reliability defect worth reporting separately
from accuracy, with a cheap fix (retry when the output size is implausibly small).

Quote a **range or median across runs**, never the best run. Reporting the luckiest of three is
cherry-picking even when unintentional.

## 6. Change one mechanism at a time

**Name the mechanism, not the symptom.** A symptom fix addresses one item; a mechanism fix
addresses every item sharing the cause. If a fix targeting a defect does not move it, you have the
wrong mechanism — re-diagnose rather than adding another rule.

A useful sign you have found the real mechanism: one correction resolves several apparently
unrelated defects at once.

After each change, compare **per-item error counts** against the control, not just the headline:

- errors removed
- errors introduced
- items unchanged

**Revert anything that does not earn its place.** A change that fixes one item and breaks another
of similar severity is a net loss; so is one whose gain is inside the noise floor.

Run only the subset that exercises the change, then a clean full run at the end. Be careful
deriving the subset: include every item the changed rule *could* touch, not only those that
currently fail.

## 7. Write rules that generalise

Encode the **convention**, not the answer:

- No entity names, document names, or expected values in prompts or exemplars.
- Domain-shaped examples are fine; answer keys are not.
- If the existing prompt names a specific record, that is a defect — it is both over-fitted and
  often wrong.
- State both directions of a rule. "X belongs here" invites the model to leave the slot empty when
  X is absent; say what to do in the absent case too.
- When two similar cases are treated differently, say the asymmetry is deliberate, or the model
  will regularise it away.

## 8. When the labels are wrong

Labels are produced by people and can be stale or mistaken. When your evidence contradicts a
label:

- Say so, with the exact arithmetic, and name the affected records.
- **Do not edit the labels yourself**, and do not quietly fit the prompt to them either.
- Escalate to whoever owns them.

Expect to be overruled sometimes. When corrected labels arrive, **revert the changes they
invalidate**, re-score every earlier result against the corrected labels, and say plainly that
comparisons made across a label change are void. A baseline and a candidate scored against
different labels cannot be compared — this is easy to do by accident and produces confident
nonsense.

## 9. Trust nothing that looks plausible

Verify that a run **produced output** before scoring it. A pipeline can report success while
writing nothing, and an empty result set scores as a plausible-looking percentage rather than an
obvious zero.

Cheap guards worth running every time:

- Count produced records per item; flag any that are zero or far below the norm.
- Check a completed job actually wrote results.
- Treat a score that exactly matches an earlier known-bad run as a red flag, not a coincidence.

Also beware concurrent runners: re-invoking a batch while one is running produces duplicate work
and corrupted aggregates. Wait for the queue to drain, and deduplicate defensively.

## 10. Reporting

Track per run: what changed, which items ran, tokens/cost, wall time, and per-defect plus overall
accuracy.

In the write-up:

- Quote the control you measured, not the number you were handed, and say which is which.
- State the range across runs and the noise floor.
- Separate **what the change achieved** from **what a data/label correction achieved** — these get
  conflated and inflate the apparent value of the work.
- List defects you deliberately left, with the evidence and why (usually: single-item signal).
- If a defect in the brief turned out not to exist, say so prominently. That is a finding, not an
  embarrassment.

## Scope discipline

If the brief fixes the model, the code, or the parameters, treat a change there as out of scope —
**stop and report instead of doing it**. If asked later to test a model change, note that a newer
model may reject parameters an older one accepted, and that a pipeline often sends those
parameters from several stages, each with its own config and call site; a model swap can be a
multi-file code migration rather than a config edit. Measure before recommending: a larger model
frequently trades gains in one area for losses in another and may not be worth its cost.

Never inspect credentials. If something fails in a way that looks credential-related, report it as
a hypothesis and stop.
