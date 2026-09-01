---
name: debug
description: Use when something is broken — a bug, a failing or flaky test, an error or crash, a regression, or behaviour that does not match what was expected. Diagnoses before modifying: evidence, reproduction, trace, hypothesis, root cause, smallest fix, validation, regression check.
argument-hint: [describe the bug]
---

# Debug

**Diagnose first, modify second.** Changing code to see what happens is not
debugging. Every edit before the root cause is understood makes the problem
harder to see.

## 1. Gather evidence

Collect the actual symptoms before theorising:

- The exact error message and stack trace, verbatim.
- What was expected versus what happened.
- When it started, and what changed around then (`git log`, recent diffs).
- Whether it is consistent or intermittent, and under what conditions.

Ask for anything missing rather than guessing at it.

## 2. Reproduce

Find the smallest reliable reproduction — a failing test, a command, a specific
input. This is the single highest-value step: it makes the bug observable and
gives you a way to know when it is actually fixed.

If it cannot be reproduced, say so and proceed on evidence alone, explicitly.

## 3. Trace

Follow the actual execution path from entry point to failure. Read the code on
that path. Use the `researcher` subagent if the path crosses unfamiliar
territory and tracing it would mean pulling many files into context.

## 4. Hypothesise

Form specific hypotheses that explain **all** the evidence, not just the most
visible symptom. Prefer the ones that explain why it fails now and did not
before.

State them before testing them.

## 5. Test the hypotheses

Test each one deliberately — a log line, a breakpoint, a targeted assertion, an
inspection of the state at the relevant point.

Do not modify logic to see if the symptom moves. That is guessing, and it
corrupts the evidence.

## 6. Identify the root cause

Explain it before fixing it: what is actually wrong, why it produces this
symptom, and why it manifests under these conditions. If you cannot explain the
"why now", you probably have a symptom rather than a cause.

## 7. Fix

Implement the smallest reasonable fix that addresses the cause. Resist widening
into cleanup of surrounding code.

## 8. Validate

Confirm the original reproduction now passes. If a test did not exist for this,
consider adding one — a bug that reached you once can return.

## 9. Check for regressions

Run the tests around the changed code. Check other callers of anything whose
behaviour you altered. Delegate to `tester` if the surface is wide.

## 10. Summarise

- **Root cause** — what was actually wrong.
- **Fix** — what changed and why that addresses the cause.
- **Validation** — what you ran, and the result.
- **Notes** — related fragility you noticed but did not change.
