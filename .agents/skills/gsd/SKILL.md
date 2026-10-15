---
name: gsd
description: >-
  Autonomous 'Get Shit Done' (GSD) execution protocol. Use when executing complex,
  multi-step features, large refactorings, or critical fixes to maintain focus,
  prevent scope drift, and drive tasks relentlessly to verified completion.
---

# GSD (Get Shit Done) Protocol

The GSD protocol is an execution framework designed for high-velocity, milestone-driven autonomous development without getting blocked or leaving half-finished code.

## Core Rules
1. **Relentless Focus**: Never pause or ask trivial questions mid-stream when a sensible, safe default exists.
2. **Zero Incomplete Code**: Every edited file must compile and satisfy types/linters before finishing.
3. **Milestone Checklist**: Break all work into explicit atomic milestones and check them off in real-time.

---

## 4-Phase GSD Workflow

### Phase 1: Discovery & Scope Freeze
- Identify all affected files, dependencies, and APIs before making changes.
- Establish the baseline state (run current tests/build to ensure environment is clean).
- Freeze scope: Explicitly declare what is in-scope and what is out-of-scope.

### Phase 2: Atomic Execution Plan
- Break down the task into discrete, ordered checklist items:
  - [ ] Milestone 1: Data models and backend contracts
  - [ ] Milestone 2: Business logic and API routes
  - [ ] Milestone 3: Frontend/UI integration and state wiring
  - [ ] Milestone 4: Verification, automated testing, and regression check

### Phase 3: Fast-Paced Execution
- Execute each milestone sequentially.
- If an unexpected error or edge case arises:
  - Do not backtrack or abandon the plan.
  - Apply surgical fixes immediately.
  - Re-verify and proceed to the next item.

### Phase 4: Automated Verification & Handover
- Execute the verification suite:
  - Backend: Run python syntax / unit tests (`python -m unittest` or `pytest`).
  - Mobile: Run `flutter analyze` to ensure 0 errors.
- Commit clean, atomic diffs with standard conventional commit messages (`feat:`, `fix:`, `refactor:`).
- Hand over a crisp, non-fluffy summary of results to the user.
