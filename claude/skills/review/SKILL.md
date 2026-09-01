---
name: review
description: Use when the user asks for a review, a second opinion on changes, a check before committing, or "does this look right" — and after finishing a substantial implementation. Reviews the working-tree diff plus surrounding code for correctness, regressions, architecture, edge cases, security, and tests, ordered by severity. Says so plainly when there is nothing to report.
---

# Review

Review the current changes as an independent reviewer, not as the author.

## 1. Establish what changed

```
git status
git diff
git diff --staged
```

If the work spans commits on a branch, also look at the range against the base
branch.

## 2. Read the surrounding code

A diff alone hides most real defects. For anything non-trivial, read:

- The full body of every function the diff touches, not just the changed lines.
- Other callers of anything whose signature or semantics changed.
- The tests covering this area.

For a large diff, delegate to the `reviewer` subagent — it does this pass
independently and returns only the findings.

## 3. Look for, in priority order

1. **Correctness** — logic errors, inverted conditions, off-by-one, unhandled
   errors, resource leaks.
2. **Regressions** — existing behaviour this breaks; other callers affected.
3. **Incorrect assumptions** — about input, ordering, nullability, or state.
4. **Architecture** — right behaviour in the wrong place; duplicated
   abstraction; a convention broken that the codebase otherwise holds.
5. **Edge cases** — empty, null, boundary, concurrency, failure paths.
6. **Security** — injection, authz, secrets committed, unsafe deserialisation,
   path traversal. Only where the category genuinely applies.
7. **Tests** — behaviour changed with nothing covering it.
8. **Unrelated changes** — anything the stated task did not require.
9. **Unnecessary complexity** — speculative generality, single-caller
   abstractions, indirection that buys nothing.

## 4. Report

Order by severity, worst first. For each finding:

- `file_path:line`
- What is wrong, in one sentence.
- The concrete failure it causes — specific inputs or state leading to a wrong
  result, not an abstract worry.

Skip style and taste. Formatting and naming preferences are noise unless they
break a convention the codebase actually holds.

**If there are no meaningful findings, say so plainly.** A clean review is a
real result. Do not manufacture findings to appear thorough — that trains me to
ignore your reviews.
