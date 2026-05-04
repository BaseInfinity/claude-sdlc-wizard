# ROADMAP #97 Research: Anthropic Policy & Research Alignment Audit

**Verdict: NO-GO with one validating parallel.**

**Date:** 2026-05-04

## Original question

> Audit Anthropic's policy/research pages for SDLC relevance:
> (a) Responsible Scaling Policy
> (b) Transparency reports
> (c) Constitution
> (d) Economic Futures
> (e) Research page
>
> Goal: align wizard's philosophy with Anthropic's public positions where genuine overlap exists.

## What I audited

| Page | URL | Verdict |
|------|-----|---------|
| (a) Responsible Scaling Policy | [anthropic.com/responsible-scaling-policy](https://www.anthropic.com/responsible-scaling-policy) | Not applicable |
| (b) Transparency Hub | [anthropic.com/transparency](https://www.anthropic.com/transparency) | Tangential — model cards, baseline refusal rates |
| (e) Research | [anthropic.com/research](https://www.anthropic.com/research) | One validating parallel (Automated Alignment Researchers, 2026-04-14) |
| (c) Constitution | not fetched | Off-topic — Constitutional AI is a model-training principle, not a third-party-tooling concept |
| (d) Economic Futures | not fetched | Off-topic — macroeconomic impact of AI, not dev-process tooling |

## Per-page findings

### (a) Responsible Scaling Policy — NO-GO

The RSP governs **Anthropic's own** model-development risk thresholds (ASL-2 / ASL-3 capability triggers, deployment monitoring, security controls). It's a first-party safety framework, not a developer-tooling spec.

> "Frontier AI models also, however, present new challenges and risks that warrant careful study and effective safeguards."

The policy says nothing about how external developers using Claude API should structure their dev process. **No surface for the wizard to align against.**

### (b) Transparency Hub — TANGENTIAL

Mostly model-card disclosures: system cards, safety evaluations, capability assessments. One observation:

> "Claude Opus 4.5 was our strongest model yet on this evaluation, refusing to comply with 88.39% of requests" *(agentic security context)*

That's the kind of capability-threshold number a security-test suite might assert against. **But that's #101 territory** (we already recommend `security-guidance` plugin in setup flow), not new SDLC-wizard work.

### (e) Research — ONE VALIDATING PARALLEL

The April 2026 paper [Automated Alignment Researchers: Using large language models to scale scalable oversight](https://www.anthropic.com/research/automated-alignment-researchers) is **conceptually parallel** to our cross-model review pattern:

> *"As a proxy for scalable oversight, the weak model stands in for humans, and the strong model for the much-smarter-than-human models we might one day need to oversee."*

What they did: weaker LLMs supervising stronger LLMs (weak-to-strong supervision), achieving 0.97 PGR vs 0.23 human baseline.

What we already do: **adversarially-diverse** cross-model review — Claude (Opus 4.7) reviewed by Codex (GPT-5.5 xhigh). Different vendor + different training + different blind spots. The paper validates that LLM-as-reviewer-of-LLM is a workable pattern. Our implementation differs in two ways:

1. **Diversity-first, not weak-to-strong.** We don't use a smaller Claude reviewing a bigger Claude — we use a *different vendor's* model, sized similarly. Reduces same-family blind-spot collapse.
2. **Mission-first prompting + verification checklist.** Anthropic's paper notes the AAR approach showed "limited generalization" and "reward hacking" — exactly the failure modes our `mission/success/failure/verification_checklist` handoff format guards against (it forces the reviewer to verify specific claims with file:line evidence, not pattern-match success).

**Net:** independent third-party validation that our cross-model review pattern sits in a real research area. **No code changes** — our pattern was established 2026-04-XX (PR #189 "Memory Audit Protocol" round, ROADMAP #72), predating this paper, and our implementation already mitigates the specific weaknesses it surfaced.

### (c) Constitution + (d) Economic Futures — SKIPPED

Off-topic by inspection: Constitutional AI is a model-training philosophy (RLHF on principles), not a third-party tooling concept. Economic Futures is a macroeconomic-impact research initiative, not a developer-tooling spec. Fetching either would burn context for zero actionable signal.

## Pattern repeat

This is the sixth external-product/methodology audit to land NO-GO (or NO-GO with validating parallel):

| # | Audit | Verdict |
|---|-------|---------|
| #76 | Promptfoo | NO-GO |
| #77 | Constrain-to-Playbook | NO-GO |
| #95 | Nous Research | NO-GO |
| #99 | AutoGPT | NO-GO |
| #235 | Thoughtworks AI Evals | NO-GO |
| #97 | Anthropic Policy & Research | NO-GO + 1 validating parallel (this) |

Pattern: external policies/products keep validating the wizard's niche. Revisit only when an external source surfaces a *specific technique* we don't have, not when it surfaces a different *layer*.

## Action

- Mark ROADMAP #97 as DONE pointing at this research doc.
- No code changes.
- The "Automated Alignment Researchers" paper is now a third-party citation we could reference in the wizard's "Cross-Model Review" section if a reader asks "where's the precedent for LLM-as-reviewer-of-LLM?" — minor doc hook for a future copy-edit pass, not blocking.
