# Fresh Next.js Project (Greenfield)

A brand new Next.js app with zero SDLC setup. This fixture tests the wizard's ability to onboard a fresh project.

## Purpose

- Test wizard setup flow
- Test detection of framework (Next.js + TypeScript)
- Test generation of hooks, skills, and docs
- Evaluate adaptation to existing patterns

## What's Here

- Minimal Next.js 14 app (App Router)
- TypeScript configuration
- ESLint configuration
- No tests yet (wizard should detect this)
- No CLAUDE.md, SDLC.md, TESTING.md

## Expected Wizard Behavior

1. Detect TypeScript + Next.js
2. Detect missing test setup
3. Offer to create SDLC files
4. Configure hooks for TDD enforcement
5. Suggest testing framework (Jest or Vitest)

## Evaluation Track: Setup

How well does the wizard onboard this fresh project?
