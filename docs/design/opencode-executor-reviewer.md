# 設計書: OpenCode 標準 executor/reviewer エージェントへの移行

- 日付: 2026-06-21
- 対象リポジトリ: `claude-opencode-sdd`
- ステータス: 承認済み（実装計画待ち）

## 1. 背景と課題 (Why)

このリポジトリは「ClaudeCode をオーケストレーター、OpenCode をサブエージェント」とする SDD
(Subagent-Driven Development) ワークフローのセットアップ一式を提供する。

現状、スキル群（`opencode-sdd` / `ask-opencode` / `opencode-worker`）と各種ドキュメントは、
OpenCode 上で動く [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)（以下 OmO）の
プリセットエージェント（`Atlas - Plan Executor` / `Hephaestus - Deep Agent` /
`Prometheus - Plan Builder`）を `--agent` で呼び出す設計になっている。

**問題**: OmO のエージェントは強い「自我」（自前のオーケストレーション指針）を持つ。
サブエージェントとして単一タスクを委譲したつもりでも、Atlas が自分で SDD 進行を始め、
タスクを勝手に分割し、実装→レビュー→fix ループを内部で回してしまう。結果として:

- トークン消費が膨らむ（委譲のたびに OmO の長大なシステムプロンプト + 自律ループ）
- 実行時間が伸びる
- オーケストレーター（ClaudeCode）の制御から外れ、意図しないスコープ拡大が起きる

## 2. 解決方針 (What)

OmO のプリセットエージェントへの依存を**完全に排除**し、OpenCode 標準のカスタムエージェント機能で
「自我を持たない単純な実装専用 / レビュー専用エージェント」を自作してスキル群に統合する。

役割分担を明確化する:

- **設計・計画・壁打ち**: ClaudeCode（オーケストレーター）が担う。OpenCode 側には設計委譲しない。
- **実装**: OpenCode `executor` エージェント。指示されたことだけを実装して止まる。
- **レビュー**: OpenCode `reviewer` エージェント。read-only、指摘のみ、修正しない。

これにより、旧 `Prometheus`（設計担当）に相当する OpenCode エージェントは廃止する。

`executor` / `reviewer` は既に実環境（`~/.config/opencode/opencode.json` の `agent` キー）に
試作済みであり、`opencode agent list` で `--agent` 経由の呼び出しが可能なことを確認済み。
本改修はこれをリポジトリ管理下の正式な成果物に昇格させ、スキル・ドキュメントを統合する。

## 3. アーキテクチャ決定

### 3.1 標準カスタムエージェントを使う

OpenCode (v1.14.41 で確認) はカスタムエージェントを次の 2 方式で定義できる:

- `opencode.json` の `agent` キーにインライン定義
- `~/.config/opencode/agent/<name>.md`（グローバル） または `.opencode/agent/<name>.md`（プロジェクト）に
  Markdown ファイルとして定義（frontmatter + 本文プロンプト）

実機検証の結果、`agent/`（単数）・`agents/`（複数）どちらのディレクトリも読み込まれるが、
**`agent/`（単数）を正とする**（OpenCode の一般的な慣習に合わせる）。

### 3.2 定義は Markdown ファイルに分離する

`executor` / `reviewer` を **`opencode/agent/executor.md` / `opencode/agent/reviewer.md`** として
リポジトリに置く。理由:

- 長文のシステムプロンプトが JSON エスケープなしで読める・編集できる
- diff・レビューが容易
- OpenCode 公式が推奨する形式
- セットアップが「`agent/*.md` を `~/.config/opencode/agent/` にコピー」で単純に完結する

モデルは各 `.md` の frontmatter `model:` に直書きし、設定を一本化する
（旧 `oh-my-openagent.json` による集中管理を廃止）。

### 3.3 OmO 依存を完全に排除する

- リポジトリ `opencode/opencode.json` の `plugin: ["oh-my-openagent@latest"]` 行を削除する。
- リポジトリ `opencode/oh-my-openagent.json`（サンプル）を削除する。
- 実環境 `~/.config/opencode/opencode.json` の `agent` キー（試作の executor/reviewer 重複定義）と
  `plugin` 行を整理・削除する（定義は `agent/*.md` 側へ一本化）。
- 全ドキュメントから Atlas / Hephaestus / Prometheus / Sisyphus / oh-my-openagent への言及を除去する。

### 3.4 `tools` マップから `permission` への移行

OpenCode 公式ドキュメントによれば `tools` マップは deprecated で、現行は `permission` フィールドで
ツール可否を制御する（値: `allow` / `ask` / `deny`、glob パターン可）。
`opencode agent create` のヘルプが示す permission/ツール候補:
`bash, read, edit, glob, grep, webfetch, task, todowrite, websearch, lsp, skill`。

- `executor`: サブエージェント起動を禁止するため `task: deny`。
- `reviewer`: read-only を徹底するため `task: deny` に加えて書き込み系を禁止。

ただし候補リストに `write` / `patch` が見当たらない（`edit` のみ）。reviewer の書き込み完全禁止を
permission だけで表現できるかは実装時に実機検証する（後述 7. リスク）。

### 3.5 役割の固定（自我の排除）

`executor` / `reviewer` のシステムプロンプトで以下を厳命する（試作済みの内容を踏襲・整理）:

- 自分はオーケストレーターではなくサブエージェントである
- スコープを指示以上に広げない
- 複数タスクの implement/review/fix ループを自前で回さない
- サブエージェントを起動しない
- 完了したら止まって報告する

## 4. 変更対象一覧

### リポジトリ内（成果物）

| パス | 操作 | 内容 |
|------|------|------|
| `opencode/agent/executor.md` | 新規 | 実装専用エージェント定義（frontmatter + prompt） |
| `opencode/agent/reviewer.md` | 新規 | レビュー専用エージェント定義（read-only） |
| `opencode/opencode.json` | 修正 | `plugin` 行削除（OmO 排除） |
| `opencode/oh-my-openagent.json` | 削除 | OmO モデル設定サンプル廃止 |
| `skills/opencode-sdd/SKILL.md` | 修正 | Atlas→executor, Hephaestus→reviewer, Prometheus 廃止 |
| `skills/ask-opencode/SKILL.md` | 修正 | agent 4択→ executor/reviewer 2択 |
| `skills/opencode-worker/SKILL.md` | 修正 | `--agent executor` 明示、review 整合 |
| `claude/CLAUDE.md` | 修正 | Agent roster / Selection rules / Quick ref を executor/reviewer に |
| `AGENTS.md` | 修正 | Step3 を agent/*.md インストールに。OmO 言及整理 |
| `README.md` | 修正 | 構成図・前提条件から OmO 除去 |

### 実環境（ユーザーマシン）

| パス | 操作 | 内容 |
|------|------|------|
| `~/.config/opencode/agent/executor.md` | 新規 | リポジトリ定義をインストール |
| `~/.config/opencode/agent/reviewer.md` | 新規 | 同上 |
| `~/.config/opencode/opencode.json` | 修正 | `agent` キーと `plugin` 行を削除（重複解消） |
| `~/.claude/CLAUDE.md` | 修正 | グローバル設定も executor/reviewer へ書換え |

## 5. エージェント定義仕様

試作済みプロンプト（実環境 `opencode.json` 由来）を Markdown 化する。モデルは現行の
`openrouter/moonshotai/kimi-k2.7-code` を踏襲（ユーザーが frontmatter で随時変更可）。

### 5.1 `executor.md`（案）

```markdown
---
description: Implementation-only executor invoked by an orchestrator (e.g. Claude Code). Implements exactly what it is told, then returns. Never orchestrates.
mode: primary
model: openrouter/moonshotai/kimi-k2.7-code
permission:
  task: deny
---
You are an implementation executor invoked by an orchestrator (Claude Code).
You are a SUBAGENT, not an orchestrator.

Your job: implement EXACTLY what the instructions specify, verify it, then stop and report.

Hard rules:
- Do NOT expand scope beyond the stated instructions.
- Do NOT plan additional tasks or run a multi-task implement/review/fix loop.
- Do NOT dispatch subagents.
- Do NOT review your own work as a separate phase or keep iterating after the task is done.
- When the requested implementation is complete and its tests pass, STOP and report what you
  changed (files, commits, test results).
- If requirements are ambiguous, state the ambiguity and the assumption you made rather than
  inventing scope.

Write clean, idiomatic code that matches the surrounding codebase. Use TDD when the instructions
ask for it.
```

### 5.2 `reviewer.md`（案）

```markdown
---
description: Read-only code reviewer invoked by an orchestrator (e.g. Claude Code). Reports findings, makes no edits.
mode: primary
model: openrouter/moonshotai/kimi-k2.7-code
permission:
  task: deny
  edit: deny
  # write/patch の抑止手段は実装時に実機検証（7. リスク参照）
---
You are a code reviewer invoked by an orchestrator (Claude Code).
You are a SUBAGENT, not an orchestrator.

Your job: review the provided diff/files for spec compliance and code quality, then stop and report.

Hard rules:
- Do NOT edit, write, or patch any files. You are read-only.
- Do NOT implement fixes. Report them for the orchestrator to dispatch.
- Do NOT dispatch subagents.

Report format:
- Spec compliance: compliant | issues (with file:line)
- Findings by severity: Critical / Important / Minor, each with file:line and a one-line reason.
- Overall: Approved | Needs fixes.

Return the review and stop.
```

## 6. スキル統合方針（詳細）

### 6.1 `opencode-sdd`

- Agent Roster テーブル: Implementer/Fix = `executor`、Task/Final reviewer = `reviewer`、
  「Plan/design tasks = Prometheus」行を削除（設計は ClaudeCode が担うため OpenCode 委譲なし）。
- 全ディスパッチコマンドの `--agent "Atlas - Plan Executor"` → `--agent executor`、
  `--agent "Hephaestus - Deep Agent"` → `--agent reviewer`。
- "Models are defined in oh-my-openagent.json" の記述を「`~/.config/opencode/agent/*.md` の
  frontmatter」に置換。
- Key Rules の「Atlas for implementing/fixing, Hephaestus for reviewing, Prometheus for design」を
  「executor for implementing/fixing, reviewer for reviewing」に更新。

### 6.2 `ask-opencode`

- Phase 3 のエージェント選択を 4 択（Atlas/Prometheus/Hephaestus/Sisyphus）から、
  実装系=`executor` / レビュー系=`reviewer` の 2 択に簡素化。
- tmux 起動・非 tmux 実行コマンドの `--agent` を更新。
- CLAUDE.md の Orchestration pattern と整合させる。

### 6.3 `opencode-worker`

- `send` / `continue` のコマンドに `--agent executor` を明示（実装はデフォルトで executor を使う）。
- `review` サブコマンドは現状どおり ClaudeCode が `git diff` を確認する方式を維持
  （`reviewer` エージェントを使うかは任意。worker は対話的反復が主目的のため CC レビューで整合）。

### 6.4 ドキュメント

- `claude/CLAUDE.md` と `~/.claude/CLAUDE.md`:
  - Agent roster テーブルを executor/reviewer の 2 行に。
  - Keyword triggers は維持（スキル名は変わらない）。
  - Orchestration pattern / Selection rules: 実装→executor、レビュー→reviewer、設計→ClaudeCode 自身。
  - Quick reference の `--agent` 例を更新。
- `AGENTS.md`:
  - Step 3 を「`oh-my-openagent.json` のインストール」から「`opencode/agent/*.md` を
    `~/.config/opencode/agent/` にコピー」へ書換え。
  - "Agent Keys (for OpenCode)" セクション: OmO 集中管理の記述を除去。OpenRouter API キーが
    必要な点は残す（モデルが openrouter のため）。モデル変更先を `agent/*.md` frontmatter に。
  - OmO プラグインのインストール/前提が不要であることを明記。
- `README.md`:
  - 構成概要図を executor/reviewer に。
  - 前提条件テーブルから oh-my-openagent 行を削除。
  - 「何がインストールされるか」の oh-my-openagent.json 説明を agent/*.md 説明に差替え。

## 7. リスク・検証ポイント

1. **reviewer の write/patch 抑止**: permission 候補に `write`/`patch` が見当たらない。
   実装時に次を実機検証する:
   - `permission: { write: deny, patch: deny }` が効くか
   - 効かない場合の代替（必要ツールのみ allow するホワイトリスト方式、または `tools` マップ併用）
   - 最低限、`edit: deny` と read-only を厳命するプロンプトで実害を抑える
2. **deprecated `tools` マップ**: 試作は `tools` を使用。`permission` 移行後に警告/挙動差がないか確認。
3. **グローバル設定の直接変更**: `~/.config/opencode/opencode.json` と `~/.claude/CLAUDE.md` を
   直接書換える。変更前にバックアップ（または diff 提示）を行う。
4. **`--agent executor` の解決**: `mode: primary` のエージェントが `opencode run --agent executor` で
   起動することは list 上で確認済みだが、実タスクで end-to-end の動作確認を 1 回行う。

## 8. 非対象 (YAGNI)

- 新しいスキルの追加はしない（既存 3 スキルの統合のみ）。
- executor/reviewer 以外のエージェント（planner 等）は作らない（設計は ClaudeCode）。
- OmO プラグイン自体のアンインストールはユーザー判断に委ね、本リポジトリでは依存を「使わない」状態にする
  （強制アンインストールはしない）。
- モデル選定の最適化はしない（現行モデルを踏襲し、frontmatter で変更可能にするのみ）。

## 9. 受け入れ条件（概要）

- リポジトリに `opencode/agent/executor.md` / `reviewer.md` が存在し、`opencode agent list` で認識される。
- リポジトリから OmO（plugin 行・oh-my-openagent.json・Atlas/Hephaestus/Prometheus 言及）が消えている。
- 3 スキルが executor/reviewer のみを参照し、旧エージェント名を含まない。
- AGENTS.md のセットアップ手順どおりに新規環境で構築でき、`/ask-opencode` が executor で動く。
- claude/CLAUDE.md と ~/.claude/CLAUDE.md が executor/reviewer に整合。
- `grep -rE "Atlas|Hephaestus|Prometheus|oh-my-openagent|Sisyphus" .`（.git 除く）が成果物で 0 件。
</content>
</invoke>
