# Global Claude Code Configuration

## Development Workflow (Default Guidelines)

新規開発・機能追加・バグ修正などの実装タスクを受けたとき、以下の順序で進める。

### Step 0: コミュニケーションモード

セッション開始時に `/genshijin` をロードして応答を簡潔モードに切り替える。

### Step 1: 要件の解釈

- コードベースの調査が必要な場合は `explorer` エージェントに委譲する（Delegation rules 参照）
- ユーザーの意図が不明確な点・エージェントだけでは判断できない事項は**必ずユーザーに質問する**（推測で進めない）

### Step 2: 設計書・実装計画の作成

サブエージェントを優先的に使いながら `/superpowers:writing-plans` で以下を作成する：

- `docs/design/<feature>.md` — 設計書（Why・What・アーキテクチャ決定・制約）
- `docs/plans/<feature>.md` — 実装計画（タスク分割・受け入れ条件・Global Constraints）

### Step 3: 実装開始時にタスク起票

実装フェーズに入る前に `TaskCreate` でオーケストレーション側にタスクを起票する。
進捗は `TaskUpdate` で随時更新する。

### Step 4: TDD駆動での実装

`/opencode-sdd` を使い、Step 2 の計画に基づいてタスクを消化する。
実装は TDD（RED → GREEN → REFACTOR）で進める。

## OpenCode Integration

OpenCode (`/home/server/.opencode/bin/opencode`) is available as a sub-agent for implementation tasks.
ClaudeCode acts as **orchestrator** (設計・壁打ち・レビュー); OpenCode acts as **implementer** (コード実装).

### Keyword triggers

- `"ask opencode"` or `"delegate to opencode"` → invoke `/ask-opencode`
- `"opencode worker"` → invoke `/opencode-worker`
- `"opencode start"` → run `/opencode-worker start`
- `"opencode review"` → run `/opencode-worker review`
- `"opencode stop"` → run `/opencode-worker stop`
- `"opencode sdd"` or `"opencode-sdd"` → invoke `/opencode-sdd`

### Agent roster

| Agent | When to use |
|-------|-------------|
| `executor` | コード実装・修正。「実装して」「書いて」「作って」「直して」 |
| `reviewer` | コードレビュー・指摘（read-only）。「レビューして」「確認して」 |
| `thinker` | 設計壁打ち・代替視点・リスク分析（read-only）。「第二意見」「懸念点」「別のアプローチ」 |
| `test-writer` | TDD redフェーズ。失敗テスト作成のみ、実装ファイル不可。「テスト書いて」「TDD」 |
| `operator` | Git操作・シェルコマンド列。コード編集不可。「ブランチ切って」「rebase」「タグ打って」 |
| `explorer` | コード調査・構造把握・シンボル探索（read-only）。「どこにある？」「構造確認して」「〜を探して」 |

設計・計画・壁打ちは ClaudeCode（オーケストレーター）自身が行い、OpenCode には委譲しない。

モデル設定は各エージェントの `~/.config/opencode/agent/*.md` frontmatter で管理。スキルファイルには記載しない。

### Orchestration pattern

When the user says things like "OpenCodeに実装させて", "OpenCodeに任せて", "let OpenCode implement this":
1. タスクの性質を判断してエージェントを選択（上表参照）
2. Summarize the design agreed on so far
3. Write spec to `.omc/opencode-spec.md`
4. Invoke `/ask-opencode` with the appropriate `--agent`

**Selection rules:**
- 実装・コード生成・修正 → `--agent executor`
- コードレビュー・指摘 → `--agent reviewer`
- 設計壁打ち・別視点 → `--agent thinker`
- TDD red フェーズ → `--agent test-writer`
- Git/シェル操作 → `--agent operator`
- コード調査・構造把握 → `--agent explorer`
- 設計・計画・壁打ち → ClaudeCode 自身（委譲しない）

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

```bash
# One-shot task
opencode run "task" --agent executor --file .omc/opencode-spec.md \
  --dangerously-skip-permissions

# Persistent session (server mode)
opencode serve --port 4096          # start headless server (in tmux)
opencode run "task" --attach http://127.0.0.1:4096 --dangerously-skip-permissions
opencode run "fix X" --attach http://127.0.0.1:4096 --continue --dangerously-skip-permissions

# Session management
opencode session list
opencode run "task" --session <id> --continue
```
