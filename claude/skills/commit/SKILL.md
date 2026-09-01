---
name: commit
description: Use when it is time to commit — the user asks, or an approved implementation plan has reached a meaningful increment. Inspects status and the full diff, stages only what belongs to the change, proposes a message matching the repo's style, and confirms unless working inside an approved plan. Never pushes.
argument-hint: [optional intent, or "commit now" to skip confirmation]
---

# Commit

Prepare a commit.

**Never push.** That is the line this skill holds. Committing is delegable;
pushing is not.

## 1. Inspect the state

```
git status
```

Note untracked files as well as modified ones.

## 2. Inspect the complete diff

```
git diff
git diff --staged
```

Read all of it. Do not summarise a diff you have not read — the point of this
step is to catch what should not be committed.

## 3. Identify unrelated changes

Separate what belongs to the logical change from what merely happens to be in
the working tree:

- Debug statements, scratch files, commented-out code.
- Edits from a different task.
- Incidental formatting churn.
- Anything sensitive: credentials, tokens, `.env` files, private hostnames,
  keys. Flag these loudly and never stage them.

This step matters most when committing increments during a plan, because nobody
is reading each commit as it happens. Establish what was already modified when
the work began, and keep those paths out of every commit. Stage files explicitly
by path — never `git add -A` or `git add .` on a tree that started dirty.

## 4. Determine the commit contents

Decide what forms one coherent commit. Prefer small, focused commits — if the
tree holds two unrelated changes, propose two commits rather than one mixed
one, and say so.

Never include an unrelated change just because it is sitting there.

## 5. Propose a message

Match the repository's existing style — check `git log --oneline -20` first.
Absent a house style: a concise imperative subject line, and a body only when
the *why* is not obvious from the diff.

Describe what the change does, not the process of making it.

## 6. Summarise before acting

Present, before running anything:

- The exact files to be staged.
- The proposed commit message.
- Anything deliberately excluded, and why.

## 7. Confirm — or don't

**Default: ask before committing.** Present step 6, then wait.

**Exception — an approved implementation plan.** Once I have approved a plan and
you are working through it, commit each meaningful increment without stopping to
ask. Approving the plan settled that question; asking again for every increment
defeats the point. Still report what each commit contained as you go.

**Exception — an explicit instruction.** `/commit commit now`, or the same in
plain words.

Outside those two cases, ask.

## Never push

Do not push, and do not offer to. This holds no matter how many increments have
accumulated, how obviously ready the branch looks, or whether I approved a plan
— an approved plan authorises commits, never a push.

If pushing seems like the natural next step, say so in one line and stop.
