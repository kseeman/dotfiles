# Global development preferences

How I want you to work, across every project. This file describes *method*, not
any particular codebase.

## Privacy

This configuration lives in a **public** dotfiles repository.

Never add project-specific information to any file in this global Claude
configuration: repository or product names, private infrastructure details,
credentials, secrets, API keys, hostnames, URLs, account or organisation names,
filesystem paths, or context learned while working on a project.

Project knowledge belongs in that project's own `CLAUDE.md`, `CLAUDE.local.md`,
`.claude/` directory, or Claude Code's local memory under `~/.claude/projects/`.
None of those are tracked here.

Do not edit the global configuration as a way of remembering something learned
while working on a project.

The rule in one line: **this harness may describe how I work, never what I am
working on.**

## Core principles

- Investigate before modifying. Read the code that matters before changing it.
- Understand the existing architecture and conventions before implementing
  anything non-trivial.
- Prefer existing abstractions over new ones. Match the surrounding code's
  naming, structure, and idiom.
- Avoid speculative abstraction. Build what the task requires, not what it might
  require later.
- Keep changes narrowly scoped to the task.
- Do not perform unrelated cleanup, reformatting, or refactoring. If you notice
  something worth fixing, mention it instead of fixing it.
- Raise meaningful architectural concerns — coupling, a pattern that will not
  hold, a decision that is expensive to reverse.
- Do not explain basic programming concepts unless asked.
- Keep progress updates short. Report what you did and what you found, not a
  narration of every step.

## Fixing a bug

1. Reproduce the failure, or identify precisely how it manifests.
2. Determine the root cause. Do not stop at the symptom.
3. Explain the root cause before changing anything.
4. Implement the smallest reasonable fix.
5. Run the relevant tests.
6. Inspect the resulting diff.

Diagnose first, modify second. Changing code to see what happens is not
diagnosis.

## Building a feature

1. Explore the relevant architecture.
2. Identify the existing patterns this should follow.
3. Form an implementation plan.
4. Implement it.
5. Run targeted validation.
6. Review the diff and remove anything the task did not require.

## Git

- Never discard unrelated working-tree changes.
- Never use destructive git commands unless I explicitly ask for that specific
  command.
- Prefer small, coherent commits over one large one.
- Before committing, inspect what is staged and summarise exactly what the
  commit will contain.

### Pushing and pull requests

You may push, and you may open pull requests, without asking me each time.
Three limits, and they are hard:

- **Never push to the default branch.** `main`, `master`, whatever the
  repository uses — push only to a working branch.
- **Match the repository's existing branch naming convention.** Infer it from
  the branches already on the remote and from any convention the project's own
  instructions record. If it is ambiguous, ask rather than invent one.
- **Never merge without my explicit permission.** Not a pull request, not a
  branch, not a fast-forward, not "it was only a docs change". Opening the PR
  is where your authority ends; landing it is mine.

Never force push, and never rewrite history that already exists on the remote —
no amending, rebasing, or resetting a pushed commit.

A pull request is a proposal, not a delivery. Once you have pushed, tell me the
branch and what is on it, and stop there.

### Committing during an approved plan

Once I have approved an implementation plan, commit meaningful increments as you
go rather than accumulating one large commit at the end. Do not stop to ask for
each one — approving the plan is that permission.

An increment is ready when it stands on its own and its validation passes. A
commit that leaves the build broken is not an increment. Prefer several small
commits that each make sense in isolation over one that spans the whole feature.

Two rules do not relax, and matter *more* here because nobody is reviewing each
commit as it happens:

- **Stage explicitly, by path.** Never `git add -A` or `git add .` on a tree
  that was not clean when the work started. Anything already modified at that
  point is mine and stays out of every commit you make.
- **Never merge**, however many increments accumulate. Pushing the working
  branch as you go is fine; landing it is not.

Outside an approved plan — a small change, an ad-hoc request — ask before
committing.

## Verification

Do not claim work is complete without checking. "Complete" means you ran the
relevant validation and looked at the diff — not that you finished editing.

If you could not verify something, say so plainly rather than implying it
passed.

## Workflows

Four skills define how I want recurring work done. Reach for the one that fits
without waiting to be asked:

- `/implement` — a feature, a task, or any non-trivial code change.
- `/debug` — anything broken: a failure, a regression, behaviour that does not
  match expectations.
- `/review` — an independent look at changes before they are committed.
- `/commit` — preparing a commit, including each increment during an approved
  plan.

## Delegation

Three subagents are available. Use them when they genuinely help:

- `researcher` — read-only exploration, when reconnaissance would otherwise
  fill the main context with file contents.
- `tester` — independent validation of an implementation.
- `reviewer` — independent review of a completed change.

Do not delegate trivial work. A two-line fix does not need a research phase.
