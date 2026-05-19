# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Violin practice companion app — a plugin-based music performance tool for violinists. Cross-platform: Windows + Android. Built with Flutter.

## Key Documents

- `docs/superpowers/specs/2026-05-16-violin-practice-app-design.md` — Full feature spec, tech stack, architecture, technical risks
- `docs/superpowers/plans/2026-05-16-plan-1-project-scaffold.md` — Implementation plan: project scaffold + plugin system + TunerPlugin
- `andrew_ng_agentic_ai_reference.md` — Andrew Ng's Agentic AI course reference (informed 3 targeted agentic additions)

## Architecture Summary

Plugin-based architecture with 16 tool plugins organized in 4 categories (audio, sheet music, practice, reference). Each plugin implements the `ToolPlugin` interface. Global services (AudioEngine, Database, LlmClient, TraceLogger) are injected via Riverpod.

Three targeted agentic capabilities (not a full agent layer):
- Trace Logger + Eval Engine
- Dual-model LLM reflection (Generator + Critic) for practice plan generation
- Human-in-the-loop confirmation at key decision points

## Development Commands (once Flutter is installed)

```bash
cd violin_app
flutter pub get          # Install dependencies
flutter test             # Run all tests
flutter test test/path/to/test.dart  # Run single test
flutter run -d windows   # Run on Windows
flutter build windows    # Build Windows release
```

## Git Workflow

This project uses isolated git worktrees for feature development. Use `superpowers:using-git-worktrees` skill when starting new feature work.

## Recommended Skills

### Per-Iteration (every task)
| Skill | When |
|-------|------|
| `superpowers:test-driven-development` | Writing any implementation code |
| `superpowers:verification-before-completion` | Before claiming work is done |
| `superpowers:requesting-code-review` | After completing each task |
| `superpowers:receiving-code-review` | When processing review feedback |

### Per-Plan (lifecycle)
```
superpowers:brainstorming          → Design & requirements
superpowers:writing-plans          → Write implementation plan
superpowers:executing-plans        → Execute tasks sequentially (coupled tasks)
  OR superpowers:subagent-driven   → Execute tasks in parallel (independent tasks)
superpowers:finishing-a-development-branch  → Merge / PR / cleanup
```

### On-Demand
| Skill | When |
|-------|------|
| `superpowers:systematic-debugging` | Bug or test failure |
| `simplify` | Code cleanup after review |
| `security-review` | Before release |
| `superpowers:using-git-worktrees` | Starting new feature branch |
| `claude-api` | LLM integration work (Plan 4+) |
| `coding-standards` | Style/pattern check |
| `frontend-patterns` | Widget/UI design decisions |
