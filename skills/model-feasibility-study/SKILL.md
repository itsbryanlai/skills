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
- **Where the work goes.** Propose one directory and confirm it before writing a
  single file — `studies/<slug>/` at the repo root is a sane default. Everything
  the study produces lives under it: docs, runners, results, figures, report.
  Scattering artifacts across the working directory is the easiest way to make a
  study unfindable a month later, and nobody ever tidies it afterwards.

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

**Parallelise the survey, never the judgment.** If you can dispatch subagents,
this phase is the place: one per candidate approach, each returning a brief with
its claims already split into fact / vendor claim / inference. Do *not* delegate
the comparison design, the reading of results or the report — those need one
coherent judgment, and split agents produce documents that quietly contradict
each other.

### 3. Source data, provenance first
Audit provenance **before** downloading, never after.
- Official project releases, institutional hosts, original authors only.
- Community re-uploads and mirrors are not acceptable even with a caveat — for client-facing work a result traceable to an unverifiable mirror is not defensible, and a caveat is not a remedy.
- If only an unverified source exists: say so and **ask** before pulling it.
- Record licence per dataset. A permissive licence (commercial use allowed) is often the difference between a usable and useless result.
- Keep a `provenance.md`: every model and dataset, its source URL, licence, and how it was obtained.
- **This audit is not delegable.** A subagent told to "get the dataset" takes the first mirror that downloads. Verify the source yourself.

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
- Independent arms can run in parallel — separate agents, separate result files, one **shared** metric module so the numbers stay comparable.
- **A loud failure is worth more than a plausible number.** Wrong-but-reasonable output is the dangerous failure mode. Sanity-check intermediate artifacts (do any inputs survive preprocessing? are score ranges sane?) before trusting any aggregate.
- Watch for algorithmic blowup between pilot and full scale. Something that takes 2s on 10k rows can be non-terminating at 5M; measure before assuming it will finish.

### 6. Read the results honestly
- **Aggregates hide the user experience.** Check whether failures cluster in a few subjects/inputs rather than spreading evenly — if they do, the mean is misleading and the design consequence (a review tier, a fallback path) is usually the most valuable finding in the study.
- Report where the winner's advantage actually lives. A ranking table often understates a gap that appears only at strict operating points.
- Demographic, subgroup, or fairness breakdowns need sample sizes almost nobody has at pilot scale. Report them for transparency, and state plainly that they support no claim in either direction.

**When a later run overturns an earlier finding, rewrite — do not append.** A
study that grows by accretion ends up with two documents making opposite
recommendations and a README explaining which one to believe. Readers open the
document, not the README. So: fold the correction into the doc that made the
claim. If the earlier run is still worth keeping — a withdrawn approach someone
will ask about — move the file to `docs/superseded/` and put the reason at the
*top of that file*. Never leave an overturned recommendation reading as
current.

### 7. Report
Write for the decision-maker, then the specialist — not the reverse.

- **Lead with the recommendation and its conditions.**
- **Cap the decision-maker doc at ~900 words**, about two screens. It is the one document that actually gets read; past that it stops being a summary. Everything else is a linked detail doc. "Short enough to read in one sitting" is not a constraint — a number is.
- **Unbundle the problem.** The requested scope is rarely one thing. Split it into parts and give each a separate verdict; "build this part, keep buying that part" is a frequent and valuable answer.
- **A limitations section is not optional**, and it goes before anyone quotes a number. State what the study is (technology evaluation, pilot) and what it is not (evidence of production performance).
- **Name the unasked question.** Studies usually surface something the brief assumed away — an unquantified cost, an unconfirmed contract scope, a missing requirement. Say it.
- List next steps in priority order, marking which are on the critical path.

**One source for every number.** Have the runner emit
`experiments/results/metrics.json` alongside its tables, and write headline
figures into the prose as `{{dotted.key}}` placeholders rather than typing them.
The build step substitutes them and **fails** on a key that does not resolve, so
a re-run can never leave a stale number sitting in a sentence.

**Embed every figure where it is discussed** — not a prose mention of a path. A
reader should never have to open a file to follow an argument. Give each one
both an alt text and a title, because they do different jobs:

```
![Accuracy against text length, one line per detector.](figures/len.png "Every
detector collapses below 30 characters; fastText collapses least.")
```

The **alt** describes the chart for someone who cannot see it — axes, series,
shape. The **title is the visible caption, and it states the finding**: "the
recommended pipeline leaves 35 of 100 fields unusable against the LLM's 97", not
"bar chart of usable rate". Writing the description twice and calling it a
caption is the common failure; a reader who can see the chart already knows what
the axes are, and wants to know what it means.

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

Everything under the one directory agreed in phase 1:

```
README.md              what this is, and which doc holds the recommendation
report.html            generated -- the thing you actually send someone
.gitignore             __pycache__/ .DS_Store *.pyc results/_*cache/
docs/    00-consolidated.md  (the decision-maker doc, <= ~900 words)
         01..0N.md           (per-topic detail)
         provenance.md       (every model + dataset + licence + URL)
         figures/            (embedded in the docs, not just referenced)
         superseded/         (only if something was overturned; banner at top)
experiments/
         src/                (runners + metrics + metric tests)
         results/            (raw outputs + metrics.json, committed if small)
```

Markdown stays the source of truth — it diffs in a pull request and an HTML file
does not. The readable artifact is generated from it:

```
python3 assets/build_report.py <study-root>
```

That writes one **self-contained** `report.html`: sidebar nav over the numbered
docs, figures inlined as base64 (no loose image files to lose), a print
stylesheet for PDF, and the `{{key}}` substitution above. One file, so it can be
emailed to whoever has to make the decision. Re-run it after any doc change; it
is cheap and it is what keeps the report from drifting from the docs.

If `assets/build_report.py` did not come with this skill, write the equivalent —
a single-file HTML render of `docs/*.md` with nav and inlined images. The
property that matters is that the readable artifact is *generated*, never
hand-maintained alongside the Markdown.
