# Research: ROADMAP #235 — Thoughtworks "AI Evals" vs our existing pipeline

Date: 2026-05-04
Source article: [thoughtworks.com/en-us/insights/decoder/a/ai-evals](https://www.thoughtworks.com/en-us/insights/decoder/a/ai-evals)

**TL;DR — NO-GO. We already implement Thoughtworks' methodology under different naming. The article is methodology-only (no tools/frameworks named); the SDLC wizard's existing E2E pipeline (Tier 1/2 evaluator + score-history + CUSUM + token-spike) covers every layer they describe. The only gap is "bias evaluation" — explicitly out of scope (we evaluate process compliance, not LLM ethics). Continues the pattern of #76 (Promptfoo NO-GO) and #77 (constrain-to-playbook NO-GO).**

---

## 1. What does Thoughtworks define as "AI Evals"?

Per the Decoder article (2026-05-04 fetch), AI Evals are:

> Systematic quality checks that assess LLM accuracy and reliability against predefined metrics to ensure AI systems deliver intended value safely.

Six characterizing claims from the article:

1. **Core definition** — systematic quality checks measuring LLM accuracy and reliability against predefined metrics.
2. **Evaluation surface** — performance consistency, output accuracy, potential biases, errors, and alignment with business objectives before real-world deployment.
3. **Distinction from traditional testing** — accounts for the "dynamic nature of AI" — models continuously evolve, requiring ongoing monitoring rather than one-time validation.
4. **Methodology stages** — two-phase: pre-deployment validation (performance measurement during development) + post-deployment production evaluation (runtime monitoring).
5. **Primary benefits** — building trust, ensuring reliability for high-stakes applications, mitigating bias risks, providing actionable improvement insights.
6. **CI/CD integration** — positioned as essential quality gates; evals function as continuous oversight mechanisms throughout the development lifecycle.

The article does **not** name specific tools, frameworks, statistical methods, or implementation patterns. It is methodology-level prose, not a spec.

## 2. Where our existing pipeline already covers each layer

| Thoughtworks claim | Our equivalent (already shipped) | Reference |
|---|---|---|
| **Pre-deployment validation** — measure quality during development | `tests/e2e/run-tier2-evaluation.sh` + `evaluate.sh` (10-criterion rubric, 5 trials, 95% CI t-distribution) | `tests/e2e/`, ROADMAP #16 (Scoring System Review), #226 |
| **Post-deployment runtime monitoring** | `tests/e2e/score-history.jsonl` accumulating per-PR scores; `cusum.sh` drift detection | ROADMAP #80 (Effectiveness Scoreboard), #220 |
| **Quality gates in CI/CD** | `pr-review.yml` waits on `validate`; e2e-quick-check + e2e-full-evaluation were required gates pre-#212 | ROADMAP #212 (Option 1) |
| **Continuous oversight** | `hooks/token-spike-check.sh` (cost anomaly detection >2σ above rolling baseline); `model-effort-check.sh` session nudges | ROADMAP #220 (token-spike), #217 (effort floor) |
| **Performance consistency** | 95% CI on 5 trials catches stochastic variance; CUSUM catches gradual drift | `tests/e2e/run-tier2-evaluation.sh` |
| **Output accuracy** | Per-criterion deterministic checks (TDD RED/GREEN, plan_mode_tool, task_tracking) + LLM-judged criteria (self_review, clean_code) | `tests/e2e/evaluate.sh` |
| **Errors / failure modes** | `enforce_tdd_consistency` guard; `tdd_red`/`self_review` as critical-must-pass criteria | `tests/e2e/evaluate.sh` v5+ |
| **Alignment with business objectives** | The wizard *is* the alignment artifact — it enforces the maintainer's SDLC philosophy on every interaction | wizard skills + hooks |
| **"Dynamic nature of AI" / model evolution** | `weekly-update.yml` API-feature detector (#100); `daily-update` workflow (now consolidated); model-effort-check warns on default drift (#179) | ROADMAP #100, #179 |
| **Mitigating bias risks** | NOT covered — our scope is process compliance, not LLM ethics | (gap, see §5) |

Every Thoughtworks-described layer has a working analog in this repo. The naming is different; the substance is identical.

## 3. Where we go further than Thoughtworks describes

The article is high-level by design. Our pipeline implements specifics they don't mention:

- **Adversarial cross-model review** (Codex `xhigh` independent of Claude). Catches blind spots the same model can't see in itself. Documented at `CLAUDE_CODE_SDLC_WIZARD.md` "Cross-Model Review Loop" + `skills/sdlc/SKILL.md`.
- **Statistical Drift Penalty (SDP)** scoring — separates "model had a bad day" from "our SDLC broke" by cross-referencing external benchmarks. The article doesn't discuss model-vs-process attribution.
- **CUSUM drift detection** — borrowed from manufacturing quality control. Catches gradual quality decay over time.
- **Provable test design** — TDD RED enforcement; existence tests rejected in favor of behavior tests; Prove-It Gate before adopting any new component.
- **Capability-floor honesty** — small models (7-13B) failing the protocol is a capability result, not a port bug. Thoughtworks' framing implies "make it work everywhere"; we say "characterize where it breaks."

## 4. Where the gap is

**Bias / alignment evals are the only candidate gap.** Thoughtworks lists "potential biases" and "alignment with business objectives" as evaluation surfaces. We don't measure either:

- The wizard evaluates **process compliance** (did the agent plan, write tests first, self-review?) — not output content.
- A demographically-biased code generation (e.g., variable names that encode stereotypes) would pass our TDD RED + self-review checks if the procedure was followed correctly.

**Should we close this gap?** No, for two reasons:

1. **Out of scope.** The wizard is an SDLC enforcement layer, not a content moderation layer. Adding bias evaluation would dilute the focus and introduce content-policy decisions we're not equipped to make defensibly.
2. **Better solved elsewhere.** Bias / alignment checks belong to the model provider (Anthropic / OpenAI) and to domain-specific tools (e.g., legal review for legal generation, accessibility scanners for UI). Reinventing them as part of a generic SDLC wizard would produce shallow checks that miss real issues.

If a user has bias-evaluation requirements, the right answer is "use a domain-specific tool that ships alongside the wizard," not "build it into the wizard."

## 5. Pattern continues

This is the third research item to reach NO-GO on similar grounds:

| Item | Tool/Pattern | Verdict | Why |
|---|---|---|---|
| #76 | Promptfoo as E2E scoring harness | NO-GO | Zero statistical analysis (no CI calc, no CUSUM, no score history); we already implement Promptfoo's best patterns |
| #77 | Constrain-to-playbook prompt pattern | NO-GO | Our PR reviewer produces specific file:line findings; constraining to checklist would reduce recall on novel issues |
| **#235** | Thoughtworks AI Evals methodology | **NO-GO** | We already implement the methodology under different naming; only gap (bias eval) is out of scope |

The pattern: external-methodology audits keep validating that our pipeline is mature. The right time to revisit is when one of these external sources points to a *specific* technique we don't have, not a re-framing of techniques we already use.

## 6. Action

- Mark ROADMAP #235 DONE with this research doc as the artifact.
- Update CHANGELOG with a one-line note in the next release.
- No code changes. No new tests. No new tooling.
- Cross-reference this doc from any future "should we adopt eval framework X?" research item — the analytical pattern (compare methodology to our pipeline by layer; flag gaps as in-scope or out-of-scope) is reusable.

## 7. References

- Source article: https://www.thoughtworks.com/en-us/insights/decoder/a/ai-evals (fetched 2026-05-04)
- Prior precedent #76: ROADMAP "Research: Promptfoo as E2E Scoring Harness" — DONE
- Prior precedent #77: ROADMAP "Research: Constrain-to-Playbook Prompt Pattern" — DONE
- Our scoring rubric: `tests/e2e/evaluate.sh`, `skills/sdlc/SKILL.md` "SDLC Quality Checklist"
- Our drift detection: `scripts/cusum.sh`, `tests/e2e/score-history.jsonl`
- Our cost monitoring: `hooks/token-spike-check.sh`, ROADMAP #220
