---
name: ralph-loop
description: >-
  Autonomous self-healing test and verification loop. Executes tests, linters, or
  compiler checks, automatically analyzes tracebacks/failures, applies surgical fixes,
  and iterates relentlessly until all tests pass with zero errors.
---

# Ralph Loop — Self-Healing Autonomous TDD Protocol

The Ralph Loop is an iterative feedback pattern inspired by continuous autonomous pair-programming. It eliminates manual back-and-forth by keeping the agent in an execution-test-fix cycle until code is completely green.

---

## The Loop Mechanics

```
    ┌──────────────────────────────────────────┐
    ▼                                          │
[Execute Verification]                         │
    │                                          │
    ▼                                          │
Did command exit with Code 0?                  │
    ├──► YES: Loop terminates (Success)       │
    │                                          │
    └──► NO: Parse Traceback & Failure Log     │
              │                                │
              ▼                                │
         [Surgical Fix] ───────────────────────┘
```

## Step-by-Step Execution Protocol

1. **Trigger Target Verification**:
   - For Mobile (Flutter):
     ```bash
     flutter analyze
     ```
   - For Backend (Python):
     ```bash
     python -m unittest discover -s backend/tests -p "test_*.py"
     ```
   - Or run the composite script:
     ```powershell
     powershell -ExecutionPolicy Bypass -File ./scripts/ralph_loop.ps1
     ```

2. **Analyze Failure**:
   - Isolate the failing test, line number, and error type (e.g., `TypeError`, `Unresolved reference`, `AssertionError`, `404 Not Found`).
   - Read the exact lines using `view_file`.

3. **Apply Minimal Surgical Edit**:
   - Make the smallest possible fix that addresses the root cause without altering unrelated functionality.
   - Never mock away valid assertions or remove tests to force a pass.

4. **Iterate**:
   - Immediately re-run the verification command.
   - Do NOT stop to ask the user if you should continue fixing — continue until all tests are green (up to 5 continuous iterations).

5. **Exit Condition**:
   - When the test runner exits with code 0 and 0 errors, document the resolved issues and declare completion.
