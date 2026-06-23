# Explorer Agent + Parallel Dispatch Design

Date: 2026-06-23

## Why

現状のオーケストレーター（ClaudeCode）はコード調査を自身の Read/Bash/Grep ツールで行っている。
これはオーケストレーターの責務（設計・委譲・統合）と実装責務（調査・探索）が混在する問題を引き起こす。

目標：**オーケストレーターは自身でコードを読まない。調査・実装・操作はすべてエージェントに委譲する。**

## What

1. **Explorerエージェント追加** — コード調査専用。ファイル検索・シンボル探索・構造把握のみ
2. **並行dispatch（パターン2）** — tmux pane + sentinel file で複数エージェントを並行起動、全完了待ち
3. **CLAUDE.md更新** — エージェントロスター更新 + Explorer→Thinkerパイプラインのルール明文化
4. **ask-opencodeスキル拡張** — `parallel` モードで複数エージェントを同時起動できるようにする

## Architecture

### エージェントロスター（完全版）

| Agent | Model | 権限 | 用途 |
|-------|-------|------|------|
| executor | kimi-k2.7-code | read/write | コード実装・修正 |
| reviewer | kimi-k2.7-code | read-only | コードレビュー・指摘 |
| thinker | glm-5.2 | read-only | 設計壁打ち・代替視点・リスク分析 |
| test-writer | kimi-k2.7-code | read-only（implファイル禁止） | TDD redフェーズ、失敗テスト作成 |
| operator | gemini-2.0-flash-lite | shell/git only | Git操作・シェルコマンド列 |
| **explorer** | **gemini-2.0-flash-lite** | **read-only** | **コード調査・構造把握・シンボル探索** |

### Explorer→Thinkerパイプライン

コード調査が必要な設計タスクの標準フロー：

```
オーケストレーター
  ↓ 調査依頼
Explorer（コード構造・実装詳細を調査）
  ↓ 調査結果
オーケストレーター（結果をThinkerへ転送）
  ↓ 設計分析依頼（調査結果を文脈として付与）
Thinker（設計指針・リスク・代替案をまとめる）
  ↓ 設計指針
オーケストレーター（設計を承認・実装計画へ）
```

並行可能なケース（例: Explorer2本同時）：

```
オーケストレーター
  ↓ 並行dispatch
Explorer-A（モジュールAの構造調査）  ← tmux pane A
Explorer-B（モジュールBの構造調査）  ← tmux pane B
  ↓ 両完了後
オーケストレーター（結果統合）
```

### 並行dispatch仕組み（パターン2）

**理由:** `opencode run` はブロッキング。10分タイムアウトを超えるエージェントタスクがあるため、tmux paneに投げてsentinel fileで完了検知する。

**フロー:**

1. `.omc/done-<agent>` sentinel ファイルをクリア
2. 各エージェントを `tmux new-window -d -n "oc-<agent>"` でバックグラウンド起動
3. 各コマンド末尾に `; touch .omc/done-<agent>` を付与して完了シグナル
4. `until` ループで全sentinel file出現を待機（5秒間隔ポーリング）
5. 全完了後、`.omc/out-<agent>.txt` を読んでオーケストレーターに返す

**tmux外フォールバック:** tmux未検出時は `&` + `wait` の単一Bashコール（10分以内タスク限定）

**ファイル競合方針:**
- read-only エージェント（explorer, thinker, reviewer）→ 並行安全
- executor 並行 → git worktree + `--dir` 必須（本設計のスコープ外）

**セッション管理:**
- `--continue` は session ID 省略で「最後のセッション」を拾うため並行時は危険
- `--session <id>` を明示するか、新規セッションで起動する

## Components

### 1. `~/.config/opencode/agent/explorer.md`

新規ファイル。frontmatter:
- `model: openrouter/google/gemini-2.0-flash-lite`
- `permission: { edit: deny, write: deny, task: deny }`

システムプロンプト：コード調査専門、実装・設計判断・レビュー指摘は行わない。検索・読取・構造把握のみ報告。

### 2. `ask-opencode` スキル拡張

`parallel` モードを追加。呼び出し形式:

```
/ask-opencode parallel --agents "explorer,thinker"
```

内部で tmux pane + sentinel file パターンを実行するロジックをPhase 3に追加。
既存の単一エージェントモードとの後方互換を維持。

### 3. `claude/CLAUDE.md` 更新

- Agent rosterを6体全員に更新（thinker/test-writer/operator/explorerを追記）
- Explorer使用ルール：「コードベース調査が必要な場合はExplorerに委譲。オーケストレーター自身はRead/Bash/Grepでコードを探索しない」
- Explorer→Thinkerパイプライン：「コード調査結果をもとに設計指針が必要な場合はExplorerの結果をThinkerに渡す」
- 並行dispatch：「read-only エージェントは並行起動可。`/ask-opencode parallel` を使う」

## Data flow

```
[オーケストレーター]
    |
    | ask-opencode parallel (explorer + thinker)
    |
    ├── tmux pane: opencode run --agent explorer > .omc/out-explorer.txt; touch .omc/done-explorer
    └── tmux pane: opencode run --agent thinker  > .omc/out-thinker.txt;  touch .omc/done-thinker
    |
    | until [ -f .omc/done-explorer ] && [ -f .omc/done-thinker ]; do sleep 5; done
    |
    | read .omc/out-*.txt → 統合結果をオーケストレーターに返す
    |
[オーケストレーター] 設計承認 → 実装計画へ
```

## Error handling

- sentinel timeout（30分）: タイムアウト後に残存tmux pane をkill、エラー報告
- エージェント終了コード非0: `status.txt` で検知、どのエージェントが失敗したか特定
- tmux未検出: `&` + `wait` フォールバック（10分制限あり旨を警告）

## Testing / Acceptance criteria

- [ ] Explorer agentが起動し、read-only操作のみ実行できる（edit操作でエラーになる）
- [ ] `/ask-opencode parallel --agents "explorer,thinker"` で2エージェントが同時起動する
- [ ] 両エージェント完了後にオーケストレーターが結果を受け取れる
- [ ] CLAUDE.mdのAgent rosterが6体全員を正しく記載している
- [ ] Explorer→Thinkerパイプラインのルールがオーケストレーターの行動ガイドに含まれている

## Constraints

- executor の並行実行はスコープ外（git worktree設計が別途必要）
- `opencode serve` マルチセッション方式は採用しない（単一ポートでserial化のリスク）
- explorerはコード調査のみ。設計判断・実装提案を行わせない
- CLAUDE.md内容は通常日本語で記載（genshijin口調不使用）
