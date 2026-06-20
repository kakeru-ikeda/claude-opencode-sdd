# Global Claude Code Configuration

## Development Workflow (Default Guidelines)

新規開発・機能追加・バグ修正などの実装タスクを受けたとき、以下の順序で進める。

### Step 0: コミュニケーションモード

セッション開始時に `/genshijin` をロードして応答を簡潔モードに切り替える。

### Step 1: 要件の解釈

- コードベースの理解が必要な場合は `/oh-my-claudecode:deepinit` でプロジェクト構造を把握する
- ユーザーの意図が不明確な点・エージェントだけでは判断できない事項は**必ずユーザーに質問する**（推測で進めない）

### Step 2: 設計書・実装計画の作成

サブエージェントを優先的に使いながら `/superpowers:writing-plans` で以下を作成する：

- `docs/design/<feature>.md` — 設計書（Why・What・アーキテクチャ決定・制約）
- `docs/plans/<feature>.md` — 実装計画（タスク分割・受け入れ条件・Global Constraints）

### Step 3: 実装開始時にタスク起票

実装フェーズに入る前に `TaskCreate` でオーケストレーション側にタスクを起票する。
進捗は `TaskUpdate` で随時更新する。

### Step 4: TDD駆動での実装

`/oh-my-claudecode:opencode-sdd` を使い、Step 2 の計画に基づいてタスクを消化する。
実装は TDD（RED → GREEN → REFACTOR）で進める。

## OpenCode Integration

OpenCode (`/home/server/.opencode/bin/opencode`) is available as a sub-agent for implementation tasks.
ClaudeCode acts as **orchestrator** (設計・壁打ち・レビュー); OpenCode acts as **implementer** (コード実装).

### Keyword triggers

- `"ask opencode"` or `"delegate to opencode"` → invoke `/oh-my-claudecode:ask-opencode`
- `"opencode worker"` → invoke `/oh-my-claudecode:opencode-worker`
- `"opencode start"` → run `/oh-my-claudecode:opencode-worker start`
- `"opencode review"` → run `/oh-my-claudecode:opencode-worker review`
- `"opencode stop"` → run `/oh-my-claudecode:opencode-worker stop`
- `"opencode sdd"` or `"opencode-sdd"` → invoke `/oh-my-claudecode:opencode-sdd`

### Agent roster

| Agent | When to use |
|-------|-------------|
| `Hephaestus - Deep Agent` | レビュー・深い分析・デバッグ・リサーチ。「調べて」「レビューして」「なぜ動かないか」 |
| `Prometheus - Plan Builder` | 設計・アーキテクチャ・実装計画の立案。「設計して」「計画して」「どう実装すべきか」 |
| `Atlas - Plan Executor` | コード実装・計画の実行。「実装して」「書いて」「作って」 |
| `Sisyphus - Ultraworker` | 上記に当てはまらない複合タスク・長時間自律実行 |

モデル設定は `~/.config/opencode/oh-my-openagent.json` で管理。スキルファイルには記載しない。

### Orchestration pattern

When the user says things like "OpenCodeに実装させて", "OpenCodeに任せて", "let OpenCode implement this":
1. タスクの性質を判断してエージェントを選択（上表参照）
2. Summarize the design agreed on so far
3. Write spec to `.omc/opencode-spec.md`
4. Invoke `/oh-my-claudecode:ask-opencode` with `--agent "<agent name>"` flag

**Selection rules (迷ったら Atlas):**
- 実装・コード生成 → `Atlas - Plan Executor`
- 設計・計画 → `Prometheus - Plan Builder`
- レビュー・分析・調査 → `Hephaestus - Deep Agent`
- 長時間自律・複合 → `Sisyphus - Ultraworker`（デフォルト）

### Quick reference

```bash
# One-shot task
opencode run "task" --agent "Atlas - Plan Executor" --file .omc/opencode-spec.md \
  --dangerously-skip-permissions

# Persistent session (server mode)
opencode serve --port 4096          # start headless server (in tmux)
opencode run "task" --attach http://127.0.0.1:4096 --dangerously-skip-permissions
opencode run "fix X" --attach http://127.0.0.1:4096 --continue --dangerously-skip-permissions

# Session management
opencode session list
opencode run "task" --session <id> --continue
```
