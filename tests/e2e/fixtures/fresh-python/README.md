# Fresh Python Project (Greenfield)

A brand new Python project with zero SDLC setup. This fixture tests the wizard's ability to onboard a fresh Python project.

## Purpose

- Test wizard setup flow for Python
- Test detection of Python tooling (pyproject.toml)
- Test generation of hooks, skills, and docs
- Evaluate adaptation to existing patterns

## What's Here

- Minimal Python package structure
- pyproject.toml with modern Python config
- No tests yet (wizard should detect this)
- No CLAUDE.md, SDLC.md, TESTING.md

## Expected Wizard Behavior

1. Detect Python + pyproject.toml
2. Detect missing test setup
3. Offer to create SDLC files
4. Configure hooks for TDD enforcement
5. Suggest testing framework (pytest)

## Evaluation Track: Setup

How well does the wizard onboard this fresh Python project?
