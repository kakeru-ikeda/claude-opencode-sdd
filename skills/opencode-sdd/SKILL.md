---
name: opencode-sdd
description: Subagent-Driven Development using OpenCode agents (executor/reviewer) instead of Claude Code native subagents. Same SDD workflow — implement→review→fix loop — but dispatches via `opencode run --agent`.
---

# OpenCode Subagent-Driven Development

Same workflow as `superpowers:subagent-driven-development`, but all subagents are dispatched as OpenCode processes instead of Claude Code native agents.

## Agent Roster

| Role | OpenCode Agent |
|------|---------------|
| Implementer | `executor` |
| Fix subagent | `executor` |
| Task reviewer | `reviewer` |
| Final reviewer | `reviewer` |

Models are defined in each agent's frontmatter at `~/.config/opencode/agent/*.md` — change them there without touching skill files.

## Setup

### Phase 0: Locate scripts and workspace

Find the superpowers SDD scripts (version-agnostic):
```bash
SDD_SCRIPTS=$(find ~/.claude/plugins/cache/claude-plugins-official/superpowers -name "task-brief" -path "*/scripts/*" 2>/dev/null | head -1 | xargs dirname)
echo "SDD_SCRIPTS=$SDD_SCRIPTS"
```

Create workspace:
```bash
WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$WORKSPACE/.superpowers/sdd"
SDDDIR="$WORKSPACE/.superpowers/sdd"
```

Check ledger for prior progress:
```bash
cat "$SDDDIR/progress.md" 2>/dev/null || echo "(no ledger — fresh start)"
```

Tasks listed as `complete` in the ledger are DONE — skip them. Resume at the first incomplete task.

### Phase 1: Read plan and create todos

Read the plan file once. Note:
- Global constraints (copy verbatim for reviewer prompts)
- Task count and sequence
- Dependencies between tasks

Create todos for all remaining tasks. Record the session BASE commit:
```bash
BASE_BRANCH=$(git rev-parse HEAD)
echo "Branch base: $BASE_BRANCH"
```

---

## Per-Task Loop

Repeat for each task:

### Step 1: Extract task brief

```bash
TASK_BRIEF=$("$SDD_SCRIPTS/task-brief" PLAN_FILE N "$SDDDIR/task-N-brief.md" 2>&1)
echo "$TASK_BRIEF"
# Brief path: $SDDDIR/task-N-brief.md
```

Record the commit SHA before dispatch:
```bash
TASK_BASE=$(git rev-parse HEAD)
echo "Task N base: $TASK_BASE"
```

### Step 2: Write implementer dispatch file

Write `$SDDDIR/task-N-dispatch.md` — the filled implementer prompt. Base it on this template:

```markdown
# Implementer Instructions: Task N — [task name]

You are implementing Task N: [task name].

## Task Brief

Read your task brief first: [ABSOLUTE PATH TO $SDDDIR/task-N-brief.md]
It contains the full task text from the plan. Use all values in it verbatim.

## Context

[Scene-setting: where this task fits, what the prior tasks produced, key
interfaces or decisions the brief cannot know. One short paragraph.]

## Before You Begin

If you have questions about requirements, approach, dependencies, or
anything unclear — ask them now before starting work.

## Your Job

1. Implement exactly what the task brief specifies
2. Write tests (TDD if the brief says so)
3. Verify the implementation works
4. Commit your work
5. Self-review (see below)
6. Write your full report to: [ABSOLUTE PATH TO $SDDDIR/task-N-report.md]

Working directory: [WORKSPACE ROOT]

**While you work:** If something unexpected comes up, ask. Don't guess.
Run the focused test while iterating; run the full suite once before committing.

## Self-Review Checklist

Before reporting, check:
- Completeness: everything in the brief implemented?
- Quality: clean names, maintainable code?
- Discipline: no overbuilding (YAGNI)?
- Tests: verify real behavior, not mocks? Output pristine?

Fix issues found in self-review before reporting back.

## Report Format

Write your detailed report to [ABSOLUTE PATH TO $SDDDIR/task-N-report.md]:
- What you implemented
- Tests run and results
- TDD evidence (RED/GREEN) if TDD was required
- Files changed
- Self-review findings
- Any concerns

Then output ONLY (under 15 lines — detail is in the report file):
- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Commits (short SHA + subject)
- One-line test summary
- Concerns (if any)
- Report path
```

Use **absolute paths** for all file references inside the dispatch file — OpenCode changes directories.

### Step 3: Dispatch executor as implementer

```bash
opencode run "Read .superpowers/sdd/task-N-dispatch.md and execute it completely. Your task brief and full instructions are in that file." \
  --agent executor \
  --file "$SDDDIR/task-N-dispatch.md" \
  --file "$SDDDIR/task-N-brief.md" \
  --dangerously-skip-permissions \
  2>&1 | tee "$SDDDIR/task-N-stdout.txt"
```

Read executor's stdout output to determine status. Then read the full report:
```bash
cat "$SDDDIR/task-N-report.md"
```

**Handle status:**
- `DONE` → proceed to review
- `DONE_WITH_CONCERNS` → read concerns, assess, then proceed to review
- `NEEDS_CONTEXT` → provide context, re-dispatch executor
- `BLOCKED` → assess: more context / more capable model / smaller task / escalate to user

### Step 4: Generate review package

```bash
TASK_HEAD=$(git rev-parse HEAD)
REVIEW_PKG=$("$SDD_SCRIPTS/review-package" "$TASK_BASE" "$TASK_HEAD" 2>&1)
# Capture the written path:
REVIEW_FILE=$(echo "$REVIEW_PKG" | grep "^wrote " | sed 's/^wrote //; s/: .*//')
echo "Review package: $REVIEW_FILE"
```

### Step 5: Write reviewer dispatch file

Write `$SDDDIR/task-N-review-dispatch.md`:

```markdown
# Reviewer Instructions: Task N — [task name]

You are reviewing one task's implementation: spec compliance first, then code quality.
This is a task-scoped gate — broad whole-branch review happens separately.

## What Was Requested

Read the task brief: [ABSOLUTE PATH TO $SDDDIR/task-N-brief.md]

Global constraints that bind this task (verbatim from plan):
[PASTE GLOBAL CONSTRAINTS FROM PLAN]

## What the Implementer Claims They Built

Read the implementer's report: [ABSOLUTE PATH TO $SDDDIR/task-N-report.md]

## Diff Under Review

Read the review package: [ABSOLUTE PATH TO $REVIEW_FILE]
(Contains commit list, stat summary, and full diff with context.)

Do not re-run git commands. Do not crawl unchanged files unless you have a
specific named risk to verify — one focused check per risk. Read-only.

## Part 1: Spec Compliance

Compare diff vs. brief:
- Missing: requirements skipped or missed
- Extra: features not requested
- Misunderstood: right feature, wrong approach

Unverifiable items (live in unchanged code or span tasks) → ⚠️ item.

## Part 2: Code Quality

- Clean separation of concerns?
- Proper error handling?
- DRY without premature abstraction?
- Tests verify real behavior (not just mocks)?
- File responsibilities clear and focused?

Point at evidence: file:line for every finding.

## Output Format

### Spec Compliance
- ✅ Spec compliant | ❌ Issues found: [details with file:line]
- ⚠️ Cannot verify from diff: [what and what the controller should check]

### Strengths
[Specific praise]

### Issues
#### Critical (Must Fix)
#### Important (Should Fix)
#### Minor (Nice to Have)

### Assessment
**Task quality:** Approved | Needs fixes
**Reasoning:** [1-2 sentence technical assessment]
```

### Step 6: Dispatch reviewer as reviewer

```bash
opencode run "Read .superpowers/sdd/task-N-review-dispatch.md and execute it completely. Your review instructions and all input files are attached." \
  --agent reviewer \
  --file "$SDDDIR/task-N-review-dispatch.md" \
  --file "$SDDDIR/task-N-brief.md" \
  --file "$SDDDIR/task-N-report.md" \
  --file "$REVIEW_FILE" \
  --dangerously-skip-permissions \
  2>&1
```

Read reviewer's output directly — it returns the full review as stdout.

### Step 7: Handle review findings

**If Spec ✅ and Task quality: Approved:**
- Mark task complete in todo list
- Append to ledger:
  ```
  Task N: complete (commits TASK_BASE..TASK_HEAD, review clean)
  ```
- Move to next task

**If Critical or Important issues:**
- Write `$SDDDIR/task-N-fix-dispatch.md` with:
  - All Critical/Important findings with file:line
  - Instruction to re-run covering tests and append results to `task-N-report.md`
- Dispatch executor as fixer:
  ```bash
  opencode run "Read .superpowers/sdd/task-N-fix-dispatch.md and fix all issues." \
    --agent executor \
    --file "$SDDDIR/task-N-fix-dispatch.md" \
    --file "$SDDDIR/task-N-report.md" \
    --dangerously-skip-permissions \
    2>&1 | tee "$SDDDIR/task-N-fix-stdout.txt"
  ```
- Generate new review package, re-dispatch reviewer

**Minor findings:** Record in ledger, pass to final reviewer.

---

## After All Tasks: Final Review

```bash
MERGE_BASE=$(git merge-base main HEAD 2>/dev/null || git merge-base master HEAD 2>/dev/null || echo "$BASE_BRANCH")
FINAL_PKG=$("$SDD_SCRIPTS/review-package" "$MERGE_BASE" HEAD 2>&1)
FINAL_FILE=$(echo "$FINAL_PKG" | grep "^wrote " | sed 's/^wrote //; s/: .*//')
```

Dispatch reviewer for the broad whole-branch review:
```bash
opencode run "You are doing a broad whole-branch code review before merge. Review the full branch diff for correctness, consistency, quality, and anything the per-task reviewers could not see across tasks. The diff package is attached. Return your findings directly as output." \
  --agent reviewer \
  --file "$FINAL_FILE" \
  --dangerously-skip-permissions \
  2>&1
```

If findings → dispatch ONE executor fix subagent with the complete list. Then proceed to `superpowers:finishing-a-development-branch`.

---

## Key Rules

- **Never paste dispatch files into your context** — write them to `$SDDDIR/` and reference by path
- **Always use absolute paths** in dispatch files (OpenCode may change CWD)
- **executor for implementing/fixing, reviewer for reviewing (design stays with the orchestrator)**
- **Check the ledger first** after any compaction — don't re-dispatch completed tasks
- **One executor at a time** — no parallel implementer dispatches (git conflicts)
- **Do not skip the re-review** after executor fixes Critical/Important issues

## Ledger Format

`$SDDDIR/progress.md`:
```
# SDD Progress

Branch base: <sha>

Task 1: complete (commits abc1234..def5678, review clean)
Task 2: complete (commits def5678..ghi9012, review clean, 2 Minor noted)
Task 3: in-progress
```

Task: {{ARGUMENTS}}
