---
name: model-feasibility-study
description: "Run an empirical feasibility study comparing candidate models, libraries or approaches against a decision someone has to make — benchmark several options on real data, measure against recognised standards, and report what the evidence does and does not support. Use when asked 'which model/framework should we use', 'can we build this in-house instead of buying X', 'is this approach good enough', 'benchmark these options', or when a stakeholder wants a build-vs-buy or vendor-replacement recommendation backed by experiment rather than opinion. Covers problem framing, hypothesis, dataset sourcing and provenance, controlled comparison, standards-grade metrics, and a written report. Not for tuning one known model (that is an eval/optimisation task) or for shipping production code."
---

# Model feasibility study

> **Status: Beta.** Still being tested against real studies — the steps are solid but expect refinements.

A study is evidence for a **decision**, not a benchmark table. Every phase
below exists to make one recommendation defensible in front of whoever has to
act on it.

## Phases

Work them in order. Each gates the next.

### 1. Frame the decision
Write down, before any code:
- **The decision** someone will make with this. If you cannot name it, stop and ask.
- **The claim to test**, falsifiably. "Open-source matching is accurate enough to replace vendor X" beats "evaluate face recognition".
- **The success bar**, in the units of the decision (cost, latency, error rate, effort). If nobody has set one, say so — an unstated bar is the most common reason a study lands and changes nothing.
- **What would falsify it.** Name this now, while you have no stake in the answer.

### 2. Research the landscape
Survey what exists: candidate approaches, what the incumbent/vendor actually
does, and the recognised standards or benchmarks in the field. Note which
standards define the metrics you should report — reporting the field's own
metrics is most of what makes a result credible to an outside reader.

Separate **verified fact** from **vendor marketing** from **your inference**,
and keep them separate in the report too. A capability claim sourced from a
vendor's own sales page is that vendor's claim, not a fact; label it as such.
When a vendor page contains an implausible claim, cite it as the reason to
read the rest sceptically.

### 3. Source data, provenance first
Audit provenance **before** downloading, never after.
- Official project releases, institutional hosts, original authors only.
- Community re-uploads and mirrors are not acceptable even with a caveat — for client-facing work a result traceable to an unverifiable mirror is not defensible, and a caveat is not a remedy.
- If only an unverified source exists: say so and **ask** before pulling it.
- Record licence per dataset. A permissive licence (commercial use allowed) is often the difference between a usable and useless result.
- Keep a `provenance.md`: every model and dataset, its source URL, licence, and how it was obtained.

If a source must be withdrawn, delete the data, the runner code, the derived
results and figures, **and** every reference in the docs — then state plainly
that the experiment was withdrawn. Never let it quietly disappear.

Prefer a small **real** dataset over a large synthetic one for the headline
result; use the large one for statistical resolution the small one cannot
reach.

### 4. Design the comparison
- **Hold everything constant except the one variable.** Share preprocessing, alignment, and input handling across all candidates so the only difference is the thing under test. This is the single biggest driver of whether the comparison means anything.
- **Define metrics before running.** Take them from the field's standard where one exists. Implement them yourself only where no library matches the standard's definition, and **unit-test them against a known-good library** on the cases that overlap.
- **Know your resolution limit.** With *n* comparisons you cannot evidence a rate rarer than roughly 3/*n* (the "rule of 3"). Compute it, state it, and never quote an operating point past it.
- Include a **baseline** and, where the pipeline has stages, an **ablation** showing what each stage costs.

### 5. Run and verify
- Long runs go in the background with logs; check on them rather than blocking.
- **A loud failure is worth more than a plausible number.** Wrong-but-reasonable output is the dangerous failure mode. Sanity-check intermediate artifacts (do any inputs survive preprocessing? are score ranges sane?) before trusting any aggregate.
- Watch for algorithmic blowup between pilot and full scale. Something that takes 2s on 10k rows can be non-terminating at 5M; measure before assuming it will finish.

### 6. Read the results honestly
- **Aggregates hide the user experience.** Check whether failures cluster in a few subjects/inputs rather than spreading evenly — if they do, the mean is misleading and the design consequence (a review tier, a fallback path) is usually the most valuable finding in the study.
- Report where the winner's advantage actually lives. A ranking table often understates a gap that appears only at strict operating points.
- Demographic, subgroup, or fairness breakdowns need sample sizes almost nobody has at pilot scale. Report them for transparency, and state plainly that they support no claim in either direction.

### 7. Report
Write for the decision-maker, then the specialist — not the reverse.

- **Lead with the recommendation and its conditions.**
- **Unbundle the problem.** The requested scope is rarely one thing. Split it into parts and give each a separate verdict; "build this part, keep buying that part" is a frequent and valuable answer.
- **A limitations section is not optional**, and it goes before anyone quotes a number. State what the study is (technology evaluation, pilot) and what it is not (evidence of production performance).
- **Name the unasked question.** Studies usually surface something the brief assumed away — an unquantified cost, an unconfirmed contract scope, a missing requirement. Say it.
- List next steps in priority order, marking which are on the critical path.

Chart for the audience:
- The field's conventional chart (DET, ROC, PR curve) belongs in the technical doc. It answers a specialist's question.
- For everyone else, answer the **business** question directly, in human-scale units: "out of 1,000 real users, how many does each option wrongly block?" A sorted bar chart of that beats any curve.
- If a reader says they do not understand a chart, replace the chart. Do not add explanation to a chart that is wrong for its audience.
- Log axes cannot show zero. Check whether your plot is silently dropping the best result.

## Traps

| Trap | Guard |
|---|---|
| Dataset loader returns floats in [0,1]; casting to uint8 zeroes everything | Print `min/max/dtype/mean` of the first sample before the pipeline |
| Preprocessing silently drops every input | Assert non-empty and log a retention rate at each stage |
| Metric code is O(n²), fine at pilot scale, hangs at full scale | Time it on synthetic data at full scale before the real run |
| Default/most-popular library ≠ best | Always benchmark; the tutorial favourite is often near-worst |
| Quoting an error rate below what the sample can resolve | Compute 3/n, state it, stop there |
| Vendor capability treated as verified | Label marketing claims as claims; read their own pages |
| "Not buildable" applied to a whole category | Split it — one component is often standardised and open |

## Deliverables

```
docs/         00-consolidated (one short doc for the decision-maker)
              01..0N          (per-topic detail)
              provenance.md   (every model + dataset + licence + URL)
              figures/
experiments/  src/            (runners + metrics + metric tests)
              results/        (raw outputs, committed if small)
```

Keep the consolidated doc short enough to read in one sitting. It is the one
that gets read.
