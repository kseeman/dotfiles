---
name: implement
description: Use when the user asks to implement a feature, add functionality, build something new, wire up an integration, or make any non-trivial code change. Runs research → plan → implement → targeted validation → diff review → summary, committing meaningful increments once the plan is approved. Scales down for trivial changes.
argument-hint: [what to implement]
---

# Implement

Standard implementation workflow: **research → plan → implement → validate →
review diff → summarise**.

Scale the ceremony to the change. A one-line fix does not need a research phase
or a subagent; skip straight to the work. The steps below are for anything with
real surface area.

## 1. Research

Understand the code before changing it. Find the relevant files, the existing
patterns this should follow, and the places that will need to change.

If this would mean reading a substantial amount of code — several files, an
unfamiliar subsystem, tracing a flow across layers — delegate to the
`researcher` subagent instead of reading it all into this context. Give it a
specific question, not "look at the codebase".

If the task touches two or three files you already understand, just read them.

## 2. Plan

State the approach before writing code:

- Which files change, and what each change does.
- Which existing abstraction or pattern it follows.
- Anything ambiguous in the request, with the assumption you are making.

Keep it short. If the plan reveals the request is ambiguous in a way that
changes the work, ask now rather than after implementing.

## 3. Implement

- Follow the conventions already in the file. Match its naming, structure, error
  handling, and comment density.
- Prefer extending an existing abstraction over introducing a new one.
- Do not add speculative flexibility.
- Stay in scope. If you spot an unrelated problem, note it for the summary —
  do not fix it.

Before touching anything, record what was already modified in the working tree.
Those paths are not yours; they must stay out of every commit you make below.

For a plan with several steps, work in increments rather than editing everything
and validating once at the end. Each increment is: implement one coherent piece,
validate it (step 4), commit it (step 7). That way a failure is localised to the
step that caused it, and the history reads as a sequence of decisions rather
than one undifferentiated drop.

## 4. Validate

Run targeted validation — the tests covering what you changed, plus a build,
type-check, or lint where the project has one.

Delegate to the `tester` subagent when the validation is non-obvious (you would
have to go find the project's commands) or when the output is long enough to be
worth keeping out of this context. Otherwise run it directly.

Do not skip this and describe the change as done.

## 5. Review the diff

```
git diff
```

Read it. Specifically check for:

- Debug statements, commented-out code, stray files.
- Changes the task did not require.
- Formatting churn in untouched regions.
- Anything you would flag in someone else's PR.

For a substantial or risky change, delegate to the `reviewer` subagent for an
independent pass.

## 6. Summarise

- What changed, by file.
- Anything notable: a decision you made, an assumption, a tradeoff.
- What you validated, and the result.
- Anything you deliberately left alone, including unrelated problems you found.
- The commits you made, if any.

## 7. Commit

**If I approved the plan**, commit each increment as it lands — after its
validation passes, not all at once at the end. Do not ask before each one;
approving the plan was that permission. Use `/commit`, which handles staging,
message style, and keeping unrelated changes out.

An increment is ready when it stands on its own and leaves the build working.
If a piece is too small to make sense alone, fold it into the next one.

**If there was no approved plan** — a small change, an ad-hoc request — do not
commit. Say the work is ready and let me decide.

**Pushing follows `CLAUDE.md`** ("Pushing and pull requests"), or the project's
own instructions where they differ. With an approved plan, pushing the working
branch as you go, and opening a PR at the end, needs no separate ask. Never the
default branch, and **never merge** — opening the PR is where the work stops.
Without an approved plan nothing is committed, so nothing is pushed.
