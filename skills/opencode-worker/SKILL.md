---
name: opencode-worker
description: Manage a persistent OpenCode server in tmux for iterative implementation sessions. Supports multi-turn design→implement→review loops.
---

# OpenCode Worker

Manage a persistent OpenCode server session for multi-turn implementation work.
Use this when you need several rounds of implement→review→refine.

## Usage

```
/oh-my-claudecode:opencode-worker start
/oh-my-claudecode:opencode-worker send "implement feature X"
/oh-my-claudecode:opencode-worker continue "now add error handling"
/oh-my-claudecode:opencode-worker review
/oh-my-claudecode:opencode-worker stop
```

## Subcommands

### `start` — Launch persistent OpenCode server

```bash
# Kill stale session if exists
tmux kill-session -t opencode-worker 2>/dev/null || true

# Start headless server on fixed port
tmux new-session -d -s opencode-worker \
  'opencode serve --port 4096 --print-logs 2>&1 | tee /tmp/opencode-worker.log'

# Wait for server to bind
sleep 3

# Confirm server is up
curl -sf http://127.0.0.1:4096/ >/dev/null 2>&1 && echo "Server UP" || echo "Server may still be starting"

# Save state
mkdir -p .omc/state
echo '{"url":"http://127.0.0.1:4096","session_id":null,"started_at":"'$(date -Iseconds)'"}' \
  > .omc/state/opencode-worker.json
cat .omc/state/opencode-worker.json
```

Report the server URL and confirm the worker is ready.

### `send "task"` — Send a task to the worker (new session)

```bash
# Read worker URL
OPENCODE_URL=$(python3 -c "import sys,json; print(json.load(open('.omc/state/opencode-worker.json'))['url'])" 2>/dev/null || echo "http://127.0.0.1:4096")

opencode run "TASK_HERE" \
  --attach "$OPENCODE_URL" \
  --dangerously-skip-permissions \
  --format default \
  2>&1 | tee /tmp/opencode-last-run.txt

# Capture session ID from last run for future continuations
LAST_SESSION=$(opencode session list 2>/dev/null | head -2 | tail -1 | awk '{print $1}')
python3 -c "
import json
d = json.load(open('.omc/state/opencode-worker.json'))
d['session_id'] = '${LAST_SESSION}'
json.dump(d, open('.omc/state/opencode-worker.json','w'))
"
```

Replace `TASK_HERE` with the actual task from `{{ARGUMENTS}}`.

After sending, call `review` automatically.

### `continue "follow-up"` — Continue the last session

```bash
# Read stored session ID
SESSION_ID=$(python3 -c "import json; print(json.load(open('.omc/state/opencode-worker.json'))['session_id'] or '')" 2>/dev/null)
OPENCODE_URL=$(python3 -c "import json; print(json.load(open('.omc/state/opencode-worker.json'))['url'])" 2>/dev/null || echo "http://127.0.0.1:4096")

if [ -n "$SESSION_ID" ]; then
  opencode run "FOLLOWUP_HERE" \
    --attach "$OPENCODE_URL" \
    --session "$SESSION_ID" \
    --continue \
    --dangerously-skip-permissions \
    2>&1 | tee /tmp/opencode-last-run.txt
else
  # Fall back to --continue without session ID (uses last session)
  opencode run "FOLLOWUP_HERE" \
    --attach "$OPENCODE_URL" \
    --continue \
    --dangerously-skip-permissions \
    2>&1 | tee /tmp/opencode-last-run.txt
fi
```

Replace `FOLLOWUP_HERE` with the follow-up from `{{ARGUMENTS}}`.

### `review` — Review OpenCode's latest work

```bash
# Show what changed
git status --short 2>/dev/null
git diff --stat 2>/dev/null
git diff 2>/dev/null | head -300
```

Analyze and report:
1. **Changes summary** — what files changed and why
2. **Design conformance** — does it match the agreed design?
3. **Issues** — bugs, missing tests, TODOs left, style problems
4. **Verdict**: `APPROVE` / `NEEDS_REVISION` / `MAJOR_REWORK`

If `NEEDS_REVISION`: suggest exact follow-up prompt for `continue`.
If `APPROVE`: summarize what's done and what's next.

### `stop` — Shutdown the worker

```bash
tmux kill-session -t opencode-worker 2>/dev/null && echo "Worker stopped"
rm -f /tmp/opencode-worker.log /tmp/opencode-last-run.txt
rm -f .omc/state/opencode-worker.json
echo "OpenCode worker cleaned up."
```

### `status` — Check worker health

```bash
# Check tmux session
tmux has-session -t opencode-worker 2>/dev/null && echo "tmux: RUNNING" || echo "tmux: STOPPED"

# Check HTTP reachability
curl -sf http://127.0.0.1:4096/ >/dev/null 2>&1 && echo "HTTP: UP" || echo "HTTP: DOWN"

# Show state
cat .omc/state/opencode-worker.json 2>/dev/null || echo "No state file"

# Show recent log
tail -20 /tmp/opencode-worker.log 2>/dev/null
```

## Full orchestration loop

The intended workflow for ClaudeCode-as-orchestrator:

```
1. 壁打ち mode   → User and ClaudeCode discuss design
2. Spec ready    → /opencode-worker start
3. Implement     → /opencode-worker send "implement X per our design"
4. Auto-review   → ClaudeCode reviews git diff
5. If issues     → /opencode-worker continue "fix: missing error handling in auth()"
6. Loop 4-5      → Until review passes
7. Done          → /opencode-worker stop
```

## Error reference

| Error | Fix |
|-------|-----|
| `Server not responding` | Check tmux: `tmux attach -t opencode-worker`; restart with `start` |
| `session_id is null` | Use `--continue` without `--session` to pick up last session |
| `Port 4096 in use` | Kill old process: `lsof -ti:4096 \| xargs kill -9` then `start` |
| `opencode: command not found` | Full path: `/home/server/.opencode/bin/opencode` |

Task: {{ARGUMENTS}}
