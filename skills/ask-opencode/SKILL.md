---
name: ask-opencode
description: Delegate a coding task to OpenCode as a tmux sub-agent, then review the results. Use after design/壁打ち discussions to hand off implementation.
---

# Ask OpenCode

Delegate a well-scoped implementation or review task to OpenCode running in a tmux pane.
Use this after design discussions when the spec is clear enough to implement.

## Usage

```
/ask-opencode <task description>
```

Examples:
```
/ask-opencode "implement the UserService class according to the spec we just discussed"
/ask-opencode "add unit tests for the auth module, cover the 3 edge cases we identified"
/ask-opencode "refactor db.ts to use the repository pattern we designed"
```

## Workflow

### Phase 1: Write spec file

Distill the current design discussion into a concrete spec. Save to `.omc/opencode-spec.md`:

```bash
mkdir -p .omc
```

Write `.omc/opencode-spec.md` with:
- Task summary (one paragraph)
- Key design decisions from the conversation
- Files to create/modify
- Acceptance criteria (bullet list)
- Constraints (what NOT to do)

### Phase 2: Verify OpenCode is available

```bash
which opencode || echo "ERROR: opencode not found at /home/server/.opencode/bin/opencode"
```

If not in PATH, use the full path: `/home/server/.opencode/bin/opencode`

### Phase 3: Select agent and launch OpenCode in tmux

Choose agent based on task type:
- 実装・コード生成・修正 → `--agent executor` (default)
- レビュー・分析        → `--agent reviewer`

設計・計画は委譲せず ClaudeCode（オーケストレーター）が行う。

No `--model` flag — model is configured per agent in `~/.config/opencode/agent/*.md`.

Check if inside tmux:
```bash
echo "${TMUX:-not-in-tmux}"
```

**If inside tmux** — create a new window for visibility:
```bash
tmux new-window -n "opencode" "opencode run \"$(head -1 .omc/opencode-spec.md)\" --agent executor --file .omc/opencode-spec.md --dangerously-skip-permissions; echo '=== OPENCODE DONE ==='; read"
```

**If NOT inside tmux** — run directly and capture output to file:
```bash
opencode run "$(head -1 .omc/opencode-spec.md)" \
  --agent executor \
  --file .omc/opencode-spec.md \
  --dangerously-skip-permissions \
  2>&1 | tee .omc/opencode-output.txt
```

### Phase 4: Wait for completion

If inside tmux, poll for the completion marker:
```bash
# Wait up to 5 minutes
for i in $(seq 1 60); do
  tmux capture-pane -pt opencode -S -50 2>/dev/null | grep -q "OPENCODE DONE" && break
  sleep 5
done
```

If NOT inside tmux, the run command blocks until completion.

### Phase 5: Review the results

```bash
git diff --stat 2>/dev/null || echo "No git repo or no changes"
git diff 2>/dev/null | head -200
```

Analyze the diff and provide structured feedback:
1. **What was implemented** — summary of changes
2. **Quality assessment** — correctness, design adherence, edge cases
3. **Issues found** — bugs, missing pieces, style violations
4. **Next step** — approve, or use `/ask-opencode` again with corrections

### Phase 6: Save artifact

```bash
SLUG=$(echo "{{ARGUMENTS}}" | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p .omc/artifacts/ask
cp .omc/opencode-spec.md ".omc/artifacts/ask/opencode-${SLUG}-${TIMESTAMP}-spec.md"
git diff > ".omc/artifacts/ask/opencode-${SLUG}-${TIMESTAMP}-diff.patch" 2>/dev/null || true
```

## Session continuation

To continue with corrections after review:
```
/ask-opencode continue: fix the issues from the review
```

Use `opencode run --continue` to continue the last session:
```bash
opencode run "follow-up task" --continue --dangerously-skip-permissions
```

## Error reference

| Error | Fix |
|-------|-----|
| `opencode not found` | Use full path: `/home/server/.opencode/bin/opencode` |
| `tmux: no sessions` | Run in background mode (no tmux) — script falls back automatically |
| `No changes in git diff` | OpenCode may have created new files — check `git status` |
| OpenCode asks for permission | Add `--dangerously-skip-permissions` flag |

Task: {{ARGUMENTS}}
