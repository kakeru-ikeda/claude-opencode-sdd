# Explorer Agent + Parallel Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Explorerエージェントを追加し、tmux sentinel-fileパターンで複数エージェントを並行起動できるようにし、オーケストレーターがコードを自分で読まないルールをCLAUDE.mdに明文化する。

**Architecture:** 3つの独立したファイル変更。Explorerエージェント設定ファイルの新規作成、ask-opencodeスキルへの並行dispatchセクション追加、CLAUDE.mdのエージェントロスター更新と委譲ルール追記。

**Tech Stack:** OpenCode agent config (Markdown frontmatter), bash (tmux + sentinel file polling), Claude Code skill Markdown

## Global Constraints

- Explorerはread-onlyのみ: `edit: deny`, `write: deny`, `task: deny` を frontmatter に設定
- モデルは `openrouter/google/gemini-2.0-flash-lite`（executor等と同じ指定形式）
- 並行dispatchはtmuxがある場合のみフル動作。tmux未検出時は `&` + `wait` フォールバック
- `--continue` を並行起動時に使用禁止。新規セッション or `--session <id>` 明示
- CLAUDE.mdファイルの内容は通常日本語（genshijin口調不使用）
- executor の並行実行は本planのスコープ外（git worktree設計が別途必要）

---

## File Map

| 操作 | パス | 内容 |
|------|------|------|
| 新規作成 | `~/.config/opencode/agent/explorer.md` | Explorerエージェント設定 |
| 修正 | `~/.claude/skills/ask-opencode/SKILL.md` | parallel dispatchセクション追加 |
| 修正 | `claude/CLAUDE.md` (プロジェクト内) | ロスター更新 + 委譲ルール追加 |

---

### Task 1: Create Explorer agent config

**Files:**
- Create: `~/.config/opencode/agent/explorer.md`

**Interfaces:**
- Produces: `opencode agent list` に `explorer (primary)` が表示される
- Produces: `opencode run "..." --agent explorer` が起動できる

- [ ] **Step 1: Create the agent config file**

`~/.config/opencode/agent/explorer.md` を以下の内容で作成する:

```markdown
---
description: Read-only code investigator invoked by an orchestrator (e.g. Claude Code). Searches files, explores symbols, and maps codebase structure. Reports findings only — never edits.
mode: primary
model: openrouter/google/gemini-2.0-flash-lite
permission:
  task: deny
  edit: deny
  write: deny
---
You are a code exploration specialist invoked by an orchestrator (Claude Code).
You are a SUBAGENT, not an orchestrator.

Your job: search and map the codebase as instructed, then stop and report findings.

Hard rules:
- Do NOT edit, write, or patch any files. You are strictly read-only.
- Do NOT implement anything. Report what you find.
- Do NOT dispatch subagents.
- Do NOT make design recommendations — that is the Thinker's job.

Use tools like grep, find, and file reads to answer the question precisely.

Report format:
- Question restated (to confirm scope)
- Files found / structure mapped (with exact paths)
- Key observations (what the code does, how it's organized)
- Open questions for the orchestrator (ambiguities you couldn't resolve)

Return findings and stop.
```

- [ ] **Step 2: Verify agent appears in list**

```bash
opencode agent list 2>&1 | grep explorer
```

期待出力:
```
explorer (primary)
```

- [ ] **Step 3: Smoke-test agent launch**

```bash
opencode run "list all .md files in docs/ directory" --agent explorer --dangerously-skip-permissions 2>&1 | tail -20
```

期待: エラーなく起動し、docs/内のファイル一覧が出力される。`permission denied` 等のエラーが出ないこと。

- [ ] **Step 4: Commit**

```bash
git -C ~/.config/opencode add agent/explorer.md
git -C ~/.config/opencode commit -m "feat: add explorer agent (gemini-flash-lite, read-only)"
```

※ `~/.config/opencode` がgitリポジトリでない場合はスキップ。その場合は「ファイル作成完了」とだけ報告する。

---

### Task 2: Update claude/CLAUDE.md with full roster and delegation rules

**Files:**
- Modify: `claude/CLAUDE.md`

**Interfaces:**
- Consumes: Task 1で作成したexplorerエージェント（ロスターに追記するため）
- Produces: 6体全エージェントのロスター、Explorer委譲ルール、Explorer→Thinkerパイプラインルール

- [ ] **Step 1: Read current CLAUDE.md**

`claude/CLAUDE.md` を読んで現在の内容を把握する（特にAgent rosterセクション）。

- [ ] **Step 2: Replace Agent roster section**

現在の roster（executor/reviewerのみ）を以下に置き換える。
変更対象は `### Agent roster` セクションのテーブル部分:

変更前:
```markdown
| Agent | When to use |
|-------|-------------|
| `executor` | コード実装・修正。「実装して」「書いて」「作って」「直して」 |
| `reviewer` | レビュー・分析（read-only、指摘のみ）。「レビューして」「確認して」 |

設計・計画・壁打ち・調査は ClaudeCode（オーケストレーター）自身が行い、OpenCode には委譲しない。
```

変更後:
```markdown
| Agent | When to use |
|-------|-------------|
| `executor` | コード実装・修正。「実装して」「書いて」「作って」「直して」 |
| `reviewer` | コードレビュー・指摘（read-only）。「レビューして」「確認して」 |
| `thinker` | 設計壁打ち・代替視点・リスク分析（read-only）。「第二意見」「懸念点」「別のアプローチ」 |
| `test-writer` | TDD redフェーズ。失敗テスト作成のみ、実装ファイル不可。「テスト書いて」「TDD」 |
| `operator` | Git操作・シェルコマンド列。コード編集不可。「ブランチ切って」「rebase」「タグ打って」 |
| `explorer` | コード調査・構造把握・シンボル探索（read-only）。「どこにある？」「構造確認して」「〜を探して」 |

設計・計画・壁打ちは ClaudeCode（オーケストレーター）自身が行い、OpenCode には委譲しない。
```

- [ ] **Step 3: Add delegation rules section**

`### Orchestration pattern` セクションの後に以下のセクションを追加する:

```markdown
### Delegation rules

**コード調査の委譲（重要）:**
オーケストレーターは自身の Read/Bash/Grep ツールでコードを探索しない。
コード調査が必要な場合は必ず `explorer` エージェントに委譲する。

**Explorer→Thinkerパイプライン:**
コード調査結果をもとに設計指針が必要な場合は以下のフローを使う:
1. `explorer` に調査を依頼（ファイル構造・実装詳細の把握）
2. Explorerの調査結果をオーケストレーターが受け取る
3. 調査結果を文脈として付与して `thinker` に設計分析を依頼
4. Thinkerの設計指針をもとにオーケストレーターが実装計画を作成

**並行dispatch:**
read-only エージェント（explorer, thinker, reviewer）は並行起動可能。
`/ask-opencode parallel --agents "explorer,thinker"` を使う。
executor の並行実行には git worktree が必要（別途設計が必要）。
```

- [ ] **Step 4: Update Selection rules section**

`### Orchestration pattern` 内の Selection rules を以下に更新する:

変更前:
```markdown
**Selection rules:**
- 実装・コード生成・修正 → `--agent executor`
- レビュー・分析・調査 → `--agent reviewer`
- 設計・計画・壁打ち → ClaudeCode 自身（委譲しない）
```

変更後:
```markdown
**Selection rules:**
- 実装・コード生成・修正 → `--agent executor`
- コードレビュー・指摘 → `--agent reviewer`
- 設計壁打ち・別視点 → `--agent thinker`
- TDD red フェーズ → `--agent test-writer`
- Git/シェル操作 → `--agent operator`
- コード調査・構造把握 → `--agent explorer`
- 設計・計画・壁打ち → ClaudeCode 自身（委譲しない）
```

- [ ] **Step 5: Verify content**

```bash
grep -n "explorer\|thinker\|test-writer\|operator\|Delegation\|パイプライン\|並行" claude/CLAUDE.md
```

期待: 上記キーワードがすべてヒットすること。

- [ ] **Step 6: Commit**

```bash
git add claude/CLAUDE.md
git commit -m "docs: update agent roster to 6 agents, add Explorer→Thinker pipeline rules"
```

---

### Task 3: Extend ask-opencode skill with parallel dispatch

**Files:**
- Modify: `~/.claude/skills/ask-opencode/SKILL.md`

**Interfaces:**
- Consumes: Task 1のexplorer agentが利用可能であること
- Produces: `/ask-opencode parallel --agents "A,B"` 呼び出し形式で複数エージェントを並行起動できる

- [ ] **Step 1: Read current SKILL.md**

`~/.claude/skills/ask-opencode/SKILL.md` を読んで現在の構造を把握する。

- [ ] **Step 2: Add parallel dispatch section**

既存の `## Session continuation` セクションの直前に以下のセクションを挿入する:

```markdown
## Parallel dispatch (複数エージェント並行起動)

複数のread-onlyエージェント（explorer, thinker, reviewer）を同時起動する場合に使う。

### Usage

```
/ask-opencode parallel --agents "explorer,thinker"
```

### Parallel Phase 1: Write per-agent spec files

各エージェントのタスクを個別specファイルに書く:

```bash
mkdir -p .omc
# .omc/opencode-spec-explorer.md と .omc/opencode-spec-thinker.md を作成
```

### Parallel Phase 2: Check tmux

```bash
echo "${TMUX:-not-in-tmux}"
```

**If inside tmux** → sentinel-file pattern (推奨、タイムアウトなし)  
**If NOT inside tmux** → `&` + `wait` fallback（10分制限あり、警告を出す）

### Parallel Phase 3a: tmux sentinel-file pattern (tmux環境)

```bash
# sentinel filesをクリア
rm -f .omc/done-explorer .omc/done-thinker

# エージェントをバックグラウンドtmux windowで起動
tmux new-window -d -n "oc-explorer" \
  "opencode run \"$(head -1 .omc/opencode-spec-explorer.md)\" \
  --agent explorer \
  --file .omc/opencode-spec-explorer.md \
  --dangerously-skip-permissions \
  > .omc/out-explorer.txt 2>&1; \
  echo 'EXIT:'$? >> .omc/out-explorer.txt; \
  touch .omc/done-explorer"

tmux new-window -d -n "oc-thinker" \
  "opencode run \"$(head -1 .omc/opencode-spec-thinker.md)\" \
  --agent thinker \
  --file .omc/opencode-spec-thinker.md \
  --dangerously-skip-permissions \
  > .omc/out-thinker.txt 2>&1; \
  echo 'EXIT:'$? >> .omc/out-thinker.txt; \
  touch .omc/done-thinker"
```

### Parallel Phase 4a: Wait for all agents (tmux)

```bash
# 最大30分待機（5秒間隔ポーリング）
TIMEOUT=360  # 360 * 5s = 30min
COUNT=0
until [ -f .omc/done-explorer ] && [ -f .omc/done-thinker ]; do
  COUNT=$((COUNT + 1))
  if [ $COUNT -ge $TIMEOUT ]; then
    echo "TIMEOUT: killing remaining agents"
    tmux kill-window -t oc-explorer 2>/dev/null || true
    tmux kill-window -t oc-thinker  2>/dev/null || true
    break
  fi
  sleep 5
done
echo "ALL_DONE"
```

### Parallel Phase 3b: & + wait fallback (tmux外)

**警告: このフォールバックはBashツールの10分タイムアウト制限がある。長時間タスクには使用しないこと。**

```bash
rm -f .omc/out-explorer.txt .omc/out-thinker.txt

opencode run "$(head -1 .omc/opencode-spec-explorer.md)" \
  --agent explorer \
  --file .omc/opencode-spec-explorer.md \
  --dangerously-skip-permissions \
  > .omc/out-explorer.txt 2>&1 &
P1=$!

opencode run "$(head -1 .omc/opencode-spec-thinker.md)" \
  --agent thinker \
  --file .omc/opencode-spec-thinker.md \
  --dangerously-skip-permissions \
  > .omc/out-thinker.txt 2>&1 &
P2=$!

wait $P1; echo "explorer exit:$?" >> .omc/status.txt
wait $P2; echo "thinker exit:$?"  >> .omc/status.txt
echo "ALL_DONE"
```

### Parallel Phase 5: Collect and synthesize results

```bash
echo "=== EXPLORER OUTPUT ===" && cat .omc/out-explorer.txt
echo "=== THINKER OUTPUT ===" && cat .omc/out-thinker.txt
```

結果を読んでオーケストレーター（ClaudeCode）が統合分析を行う。

### Constraints for parallel dispatch

- `--continue` 禁止: 並行実行時は新規セッション（session ID 競合リスクあり）
- executorの並行実行禁止: ファイル競合が起きる。executor並行にはgit worktreeが別途必要
- read-only エージェントのみ並行可: explorer, thinker, reviewer

### Error reference (parallel)

| エラー | 対処 |
|--------|------|
| `tmux: no sessions` | フォールバック（`&` + `wait`）を使う |
| sentinel fileが出ない | `tmux list-windows` でwindowの生死を確認 |
| エージェント終了コード非0 | `cat .omc/out-<agent>.txt` で末尾の `EXIT:N` を確認 |
| 30分タイムアウト | タスクを分割して再実行 |

```

- [ ] **Step 3: Verify section was added**

```bash
grep -n "Parallel dispatch\|sentinel\|done-explorer\|ALL_DONE" ~/.claude/skills/ask-opencode/SKILL.md
```

期待: 上記キーワードが全てヒットすること。

- [ ] **Step 4: Dry-run parallel launch (tmux環境がある場合のみ)**

tmux環境がある場合のみ実行:

```bash
if [ -n "$TMUX" ]; then
  mkdir -p .omc
  echo "# test-explorer task" > .omc/opencode-spec-explorer.md
  echo "# test-thinker task"  > .omc/opencode-spec-thinker.md
  rm -f .omc/done-explorer .omc/done-thinker
  tmux new-window -d -n "oc-test-explorer" "sleep 3; touch .omc/done-explorer"
  tmux new-window -d -n "oc-test-thinker"  "sleep 3; touch .omc/done-thinker"
  until [ -f .omc/done-explorer ] && [ -f .omc/done-thinker ]; do sleep 1; done
  echo "Parallel sentinel-file pattern: OK"
  tmux kill-window -t oc-test-explorer 2>/dev/null || true
  tmux kill-window -t oc-test-thinker  2>/dev/null || true
else
  echo "Not in tmux — skipping dry-run"
fi
```

期待（tmux環境）: `Parallel sentinel-file pattern: OK` が出力される。

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude add skills/ask-opencode/SKILL.md
git -C ~/.claude commit -m "feat: add parallel dispatch section to ask-opencode skill"
```

※ `~/.claude` がgitリポジトリでない場合はスキップ。ファイル変更のみで完了とする。

---

## Self-Review

**Spec coverage:**
- ✅ Explorerエージェント追加 → Task 1
- ✅ 並行dispatch（tmux sentinel-file パターン2）→ Task 3
- ✅ CLAUDE.mdロスター更新（6体） → Task 2
- ✅ Explorer委譲ルール → Task 2 Step 3
- ✅ Explorer→Thinkerパイプライン → Task 2 Step 3
- ✅ tmux外フォールバック → Task 3 Phase 3b
- ✅ タイムアウト処理 → Task 3 Phase 4a

**Placeholder scan:** なし。全ステップに具体的なコマンド・ファイル内容を記載。

**Type consistency:** コマンド・ファイルパス・sentinel file名がTask間で一致している（`.omc/done-explorer`, `.omc/out-explorer.txt` 等）。
