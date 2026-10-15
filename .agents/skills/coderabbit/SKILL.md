---
name: coderabbit
description: >-
  AI-powered automated code review, PR quality gate, and vulnerability scanner.
  Use to run automated pre-commit diff reviews, enforce quality guidelines,
  and address CodeRabbit suggestions or PR feedback.
---

# CodeRabbit Quality & Review Protocol

CodeRabbit provides continuous automated code review, detecting architectural regressions, edge case vulnerabilities, and styling issues across PRs.

---

## Pre-Commit Review Checklist
Before pushing code to `main` or opening a PR:
1. **Diff Audit**:
   - Inspect uncommitted changes:
     ```bash
     git diff --stat
     ```
   - Ensure no hardcoded secrets, API keys, or test credentials were introduced into tracked files.
2. **Review Against Assertive Guidelines**:
   - Ensure all asynchronous calls have proper `try / catch` error boundaries.
   - Ensure inputs (especially auth and query params) are sanitized.
   - Verify that all database indexes or queries match the schemas.
3. **Automated Review Invocation**:
   - For local CLI reviews (if `@coderabbitai/cli` is installed):
     ```bash
     npx @coderabbitai/cli review
     ```
   - On GitHub: CodeRabbit automatically evaluates the PR based on `.coderabbit.yaml`.
