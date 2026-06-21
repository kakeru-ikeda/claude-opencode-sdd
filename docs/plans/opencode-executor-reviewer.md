# OpenCode executor/reviewer 移行 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** OmO の Atlas/Hephaestus/Prometheus 依存を排除し、OpenCode 標準の `executor`/`reviewer` エージェントにスキル群とドキュメントを統合する。

**Architecture:** `executor`/`reviewer` を `opencode/agent/*.md`（frontmatter + プロンプト）としてリポジトリ管理下に置き、AGENTS.md セットアップで `~/.config/opencode/agent/` にインストールする。スキル3種とドキュメントの旧エージェント名を新名へ置換し、OmO（plugin 行・oh-my-openagent.json）への参照を全削除する。設計・計画は ClaudeCode が担い、OpenCode は実装/レビューのみ。

**Tech Stack:** OpenCode v1.14.41 カスタムエージェント（Markdown 定義 / `permission` フィールド）、OpenRouter（モデルプロバイダ）、bash/grep による検証。

## Global Constraints

- エージェント名は厳密に小文字・スペースなしの `executor` / `reviewer`。CLI 指定は `--agent executor` / `--agent reviewer`。
- モデルは `openrouter/moonshotai/kimi-k2.7-code` を frontmatter `model:` に記載（ユーザーが随時変更可能）。
- リポジトリ成果物から次の語を完全除去する: `Atlas`, `Hephaestus`, `Prometheus`, `Sisyphus`, `oh-my-openagent`, `Plan Executor`, `Deep Agent`, `Plan Builder`。
- スキル名は変更しない: `opencode-sdd` / `ask-opencode` / `opencode-worker`。
- ドキュメント（.md）本文は通常の読みやすい日本語/英語で書く（genshijin 圧縮口調を適用しない）。コード・コマンド・エラー文字列は原文のまま。
- agent 定義のロードディレクトリは `agent/`（単数）を正とする。
- 実環境（`~/.config/opencode/`, `~/.claude/`）への変更は破壊的操作。変更前に必ずバックアップを取る。
- コミット方針: この環境は「ユーザーが依頼したときのみコミット」。各タスクの Commit ステップは実行時にユーザー方針に従う（依頼がなければステージのみ／コミット保留）。

---

### Task 1: agent 定義 md 作成 + リポジトリの OmO 排除

**Files:**
- Create: `opencode/agent/executor.md`
- Create: `opencode/agent/reviewer.md`
- Modify: `opencode/opencode.json`
- Delete: `opencode/oh-my-openagent.json`

**Interfaces:**
- Produces: エージェント名 `executor` / `reviewer`（後続の全スキル・ドキュメントタスクが `--agent executor` / `--agent reviewer` として参照する）。

- [ ] **Step 1: `opencode/agent/executor.md` を作成**

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

- [ ] **Step 2: `opencode/agent/reviewer.md` を作成**

`write`/`patch` の permission キーが有効かは Task 2 で実機検証する。本タスクでは `task: deny` と `edit: deny` を設定し、read-only をプロンプトで厳命する。

```markdown
---
description: Read-only code reviewer invoked by an orchestrator (e.g. Claude Code). Reports findings, makes no edits.
mode: primary
model: openrouter/moonshotai/kimi-k2.7-code
permission:
  task: deny
  edit: deny
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

- [ ] **Step 3: `opencode/opencode.json` から OmO plugin を削除**

変更後の全内容（`plugin` キーを削除）:

```json
{
  "$schema": "https://opencode.ai/config.json"
}
```

- [ ] **Step 4: `opencode/oh-my-openagent.json` を削除**

```bash
git rm opencode/oh-my-openagent.json 2>/dev/null || rm -f opencode/oh-my-openagent.json
```

- [ ] **Step 5: JSON 妥当性と frontmatter を検証**

Run:
```bash
python3 -m json.tool opencode/opencode.json >/dev/null && echo "opencode.json OK"
head -5 opencode/agent/executor.md
head -7 opencode/agent/reviewer.md
ls opencode/oh-my-openagent.json 2>&1
```
Expected: `opencode.json OK` が出力され、両 md の frontmatter（`---` / `description:` / `mode: primary` / `model:`）が表示され、`oh-my-openagent.json` は `No such file` になる。

- [ ] **Step 6: リポジトリ内に OmO/旧名が残っていないか（成果物のみ）確認**

Run:
```bash
grep -rnE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" opencode/ 2>/dev/null || echo "CLEAN: opencode/"
```
Expected: `CLEAN: opencode/`

- [ ] **Step 7: Commit（ユーザー方針に従う）**

```bash
git add opencode/agent/executor.md opencode/agent/reviewer.md opencode/opencode.json
git add -A opencode/
git commit -m "feat: add executor/reviewer agents, drop oh-my-openagent dependency"
```

---

### Task 2: 実環境へインストール + opencode.json 重複整理 + 認識検証

**Files:**
- Create: `~/.config/opencode/agent/executor.md`
- Create: `~/.config/opencode/agent/reviewer.md`
- Modify: `~/.config/opencode/opencode.json`（`agent` キーと `plugin` 行を削除）

**Interfaces:**
- Consumes: Task 1 の `opencode/agent/*.md`。

- [ ] **Step 1: 実環境 opencode.json をバックアップ**

Run:
```bash
cp ~/.config/opencode/opencode.json ~/.config/opencode/opencode.json.bak
echo "backed up"
```
Expected: `backed up`

- [ ] **Step 2: agent 定義をインストール**

Run:
```bash
mkdir -p ~/.config/opencode/agent
cp opencode/agent/executor.md ~/.config/opencode/agent/executor.md
cp opencode/agent/reviewer.md ~/.config/opencode/agent/reviewer.md
ls ~/.config/opencode/agent/
```
Expected: `executor.md` と `reviewer.md` が表示される。

- [ ] **Step 3: 実環境 opencode.json から `agent` キーと `plugin` 行を削除**

`~/.config/opencode/opencode.json` を編集し、`agent` キー（試作の executor/reviewer インライン定義）と `plugin` キーを削除する。残すのは `$schema` のみ:

```json
{
  "$schema": "https://opencode.ai/config.json"
}
```

- [ ] **Step 4: md 定義が認識され、JSON 重複が消えたことを検証**

Run:
```bash
python3 -m json.tool ~/.config/opencode/opencode.json >/dev/null && echo "json OK"
/home/server/.opencode/bin/opencode agent list 2>/dev/null | grep -iE "executor|reviewer"
/home/server/.opencode/bin/opencode agent list 2>/dev/null | grep -iE "Atlas|Hephaestus|Prometheus" && echo "WARN: OmO agents still present (plugin removed from repo only)" || echo "no OmO presets"
```
Expected: `json OK`、`executor (primary)` と `reviewer (primary)` が各1行で表示される（md 由来）。OmO プリセットはユーザーのグローバル plugin 設定次第で残りうる（本リポジトリの責務外）。

- [ ] **Step 5: reviewer の書き込み禁止を実機検証**

Run:
```bash
/home/server/.opencode/bin/opencode run "Create a file named __probe_write_test.txt containing the word PROBE in the current directory. If you cannot write files, say WRITE_BLOCKED and stop." \
  --agent reviewer --dangerously-skip-permissions 2>&1 | tail -20
ls __probe_write_test.txt 2>&1
```
Expected: reviewer が書き込めず（`WRITE_BLOCKED` 相当の応答、ファイル未作成 = `No such file`）。

判定:
- ファイルが作成されなかった → 現行の `edit: deny` + プロンプトで十分。`reviewer.md` は変更不要。
- ファイルが作成された → `~/.config/opencode/agent/reviewer.md` と `opencode/agent/reviewer.md` の両方の frontmatter `permission:` に書き込み系の deny を追加して再検証する。試す値の順:
  1. `write: deny` と `patch: deny` を追記
  2. 効かなければ、許可ツールのホワイトリスト化（`read`/`grep`/`glob`/`webfetch`/`lsp` のみ `allow`、他は `deny`）
  ファイルが残っていれば削除: `rm -f __probe_write_test.txt`

- [ ] **Step 6: Commit（reviewer.md を修正した場合のみ／ユーザー方針に従う）**

```bash
git add opencode/agent/reviewer.md
git commit -m "fix: enforce read-only permission on reviewer agent"
```

---

### Task 3: `opencode-sdd` スキル改修

**Files:**
- Modify: `skills/opencode-sdd/SKILL.md`

- [ ] **Step 1: frontmatter description を更新**

`description:` 内の `(Atlas/Hephaestus/Prometheus)` を `(executor/reviewer)` に置換する。変更後:

```
description: Subagent-Driven Development using OpenCode agents (executor/reviewer) instead of Claude Code native subagents. Same SDD workflow — implement→review→fix loop — but dispatches via `opencode run --agent`.
```

- [ ] **Step 2: Agent Roster テーブルを書き換え**

既存テーブル（Implementer/Fix=`Atlas - Plan Executor`、Task/Final reviewer=`Hephaestus - Deep Agent`、Plan/design=`Prometheus - Plan Builder`）を次に置換する。Prometheus 行は削除する。

```markdown
| Role | OpenCode Agent |
|------|---------------|
| Implementer | `executor` |
| Fix subagent | `executor` |
| Task reviewer | `reviewer` |
| Final reviewer | `reviewer` |
```

- [ ] **Step 3: モデル設定の参照先を更新**

`Models are defined in ~/.config/opencode/oh-my-openagent.json — change them there without touching skill files.` を次に置換:

```
Models are defined in each agent's frontmatter at `~/.config/opencode/agent/*.md` — change them there without touching skill files.
```

- [ ] **Step 4: 全ディスパッチコマンドの `--agent` を置換**

ファイル全体で次を一括置換する:
- `--agent "Atlas - Plan Executor"` → `--agent executor`
- `--agent "Hephaestus - Deep Agent"` → `--agent reviewer`

- [ ] **Step 5: Key Rules の文言を更新**

`Atlas for implementing/fixing, Hephaestus for reviewing, Prometheus for design tasks` を次に置換:

```
executor for implementing/fixing, reviewer for reviewing (design stays with the orchestrator)
```

「One Atlas at a time」を「One executor at a time」に、「after Atlas fixes」を「after the executor fixes」に置換する。本文中の他の `Atlas`/`Hephaestus` 表記（例: "Read Atlas's stdout"、"Dispatch Hephaestus" 見出し、"Atlas's report"）もすべて `executor`/`reviewer` に置換する。

- [ ] **Step 6: 旧名が残っていないか検証**

Run:
```bash
grep -nE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" skills/opencode-sdd/SKILL.md || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 7: Commit（ユーザー方針に従う）**

```bash
git add skills/opencode-sdd/SKILL.md
git commit -m "refactor: switch opencode-sdd skill to executor/reviewer agents"
```

---

### Task 4: `ask-opencode` スキル改修

**Files:**
- Modify: `skills/ask-opencode/SKILL.md`

- [ ] **Step 1: Phase 3 のエージェント選択を 2 択に簡素化**

既存の 4 択リスト:
```
- 実装・コード生成 → `--agent "Atlas - Plan Executor"`
- 設計・計画立案  → `--agent "Prometheus - Plan Builder"`
- レビュー・分析  → `--agent "Hephaestus - Deep Agent"`
- 複合・長時間    → `--agent "Sisyphus - Ultraworker"` (default)
```
を次に置換:
```
- 実装・コード生成・修正 → `--agent executor` (default)
- レビュー・分析        → `--agent reviewer`

設計・計画は委譲せず ClaudeCode（オーケストレーター）が行う。
```

- [ ] **Step 2: モデル設定の注記を更新**

`No --model flag — model is configured per agent in oh-my-openagent.json.` を次に置換:
```
No `--model` flag — model is configured per agent in `~/.config/opencode/agent/*.md`.
```

- [ ] **Step 3: 起動コマンドの `--agent` を置換**

tmux 用・非 tmux 用の両コマンドで `--agent "Atlas - Plan Executor"` → `--agent executor` に置換する。

- [ ] **Step 4: 旧名が残っていないか検証**

Run:
```bash
grep -nE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder|Ultraworker" skills/ask-opencode/SKILL.md || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 5: Commit（ユーザー方針に従う）**

```bash
git add skills/ask-opencode/SKILL.md
git commit -m "refactor: simplify ask-opencode agent choice to executor/reviewer"
```

---

### Task 5: `opencode-worker` スキル改修

**Files:**
- Modify: `skills/opencode-worker/SKILL.md`

- [ ] **Step 1: `send` コマンドに `--agent executor` を明示**

`send` サブコマンドの `opencode run "TASK_HERE" \` ブロックに `--agent executor \` を追加する。変更後:
```bash
opencode run "TASK_HERE" \
  --agent executor \
  --attach "$OPENCODE_URL" \
  --dangerously-skip-permissions \
  --format default \
  2>&1 | tee /tmp/opencode-last-run.txt
```

- [ ] **Step 2: `continue` コマンドに `--agent executor` を明示**

`continue` サブコマンドの両 `opencode run` ブロック（session ID あり／なし）に `--agent executor \` を追加する。

- [ ] **Step 3: 旧名・OmO 参照が無いか検証（worker は元から agent 指定なし）**

Run:
```bash
grep -nE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" skills/opencode-worker/SKILL.md || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 4: Commit（ユーザー方針に従う）**

```bash
git add skills/opencode-worker/SKILL.md
git commit -m "refactor: pin opencode-worker to executor agent"
```

---

### Task 6: リポジトリドキュメント改修（claude/CLAUDE.md + AGENTS.md + README.md）

**Files:**
- Modify: `claude/CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `README.md`

- [ ] **Step 1: `claude/CLAUDE.md` の Agent roster テーブルを置換**

既存テーブル（Hephaestus/Prometheus/Atlas/Sisyphus の 4 行）を次に置換:
```markdown
| Agent | When to use |
|-------|-------------|
| `executor` | コード実装・修正。「実装して」「書いて」「作って」「直して」 |
| `reviewer` | レビュー・分析（read-only、指摘のみ）。「レビューして」「確認して」 |

設計・計画・壁打ち・調査は ClaudeCode（オーケストレーター）自身が行い、OpenCode には委譲しない。
```

- [ ] **Step 2: `claude/CLAUDE.md` のモデル注記を更新**

`モデル設定は ~/.config/opencode/oh-my-openagent.json で管理。スキルファイルには記載しない。` を次に置換:
```
モデル設定は各エージェントの `~/.config/opencode/agent/*.md` frontmatter で管理。スキルファイルには記載しない。
```

- [ ] **Step 3: `claude/CLAUDE.md` の Orchestration pattern / Selection rules を更新**

Orchestration pattern の手順 4 `Invoke /ask-opencode with --agent "<agent name>" flag` を `Invoke /ask-opencode with --agent executor (実装) or --agent reviewer (レビュー)` に置換。
Selection rules ブロックを次に置換:
```
**Selection rules:**
- 実装・コード生成・修正 → `--agent executor`
- レビュー・分析・調査 → `--agent reviewer`
- 設計・計画・壁打ち → ClaudeCode 自身（委譲しない）
```

- [ ] **Step 4: `claude/CLAUDE.md` の Quick reference を更新**

One-shot / persistent session のコマンド例の `--agent "Atlas - Plan Executor"` を `--agent executor` に置換する。

- [ ] **Step 5: `AGENTS.md` の "What This Repo Provides" を更新**

`opencode/oh-my-openagent.json — OpenCode エージェント定義のサンプル（モデルはユーザーが上書き）` を次に置換:
```
- `opencode/agent/executor.md`・`opencode/agent/reviewer.md` — OpenCode 実装/レビュー専用エージェント定義
- `opencode/opencode.json` — OpenCode 設定（プラグイン依存なし）
```

- [ ] **Step 6: `AGENTS.md` の Step 3 を agent 定義インストールに書き換え**

「Step 3: OpenCode agent config (optional / user decides)」の oh-my-openagent.json コピー処理全体を、次の agent 定義インストールに置換する:

```bash
### Step 3: Install OpenCode agent definitions

`opencode/agent/*.md` を `~/.config/opencode/agent/` にコピーする。OmO プラグインは不要。

mkdir -p ~/.config/opencode/agent
for f in opencode/agent/*.md; do
  name=$(basename "$f")
  if [ -f "$HOME/.config/opencode/agent/$name" ]; then
    echo "~/.config/opencode/agent/$name already exists — showing diff:"
    diff "$f" "$HOME/.config/opencode/agent/$name" || true
  else
    cp "$f" "$HOME/.config/opencode/agent/$name"
    echo "Installed agent: $name"
  fi
done
```

- [ ] **Step 7: `AGENTS.md` の "Agent Keys" セクションを更新**

OmO / oh-my-openagent への言及を除去し、次に置換:
```
## Agent Keys (for OpenCode)

`opencode/agent/*.md` のモデルは openrouter を使用。利用には OpenRouter の API キーが必要:

opencode providers  # 認証状況確認

モデルの変更は `~/.config/opencode/agent/executor.md` / `reviewer.md` の frontmatter `model:` を直接編集する。
```

Installed Skills テーブルは変更しない（スキル名は不変）。

- [ ] **Step 8: `README.md` の構成概要図を更新**

構成図の OpenCode ブロックを次に置換:
```
OpenCode (implementer / reviewer)
  ├─ executor  → 実装・コード生成・修正（自我なし・委譲したことだけ実行）
  └─ reviewer  → レビュー・分析（read-only、指摘のみ）
```

- [ ] **Step 9: `README.md` の前提条件・インストール説明から OmO を除去**

- 前提条件テーブルから `oh-my-openagent` の行を削除する。
- 「`opencode/oh-my-openagent.json`（サンプル・参考用）」の節全体を次に置換:
```
### `opencode/agent/*.md`（エージェント定義）

`executor`（実装）と `reviewer`（レビュー）の定義。モデルは frontmatter に記載（既定: openrouter/moonshotai/kimi-k2.7-code）。
セットアップ時 `~/.config/opencode/agent/` にコピーされる。OmO プラグインへの依存はない。
```
- 開発ワークフローの箇条書きにある `Atlas/Hephaestus` 表記を `executor/reviewer` に置換する。

- [ ] **Step 10: 3 ファイルに旧名・OmO が残っていないか検証**

Run:
```bash
grep -nE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" claude/CLAUDE.md AGENTS.md README.md || echo "CLEAN"
```
Expected: `CLEAN`

- [ ] **Step 11: Commit（ユーザー方針に従う）**

```bash
git add claude/CLAUDE.md AGENTS.md README.md
git commit -m "docs: update CLAUDE.md/AGENTS.md/README to executor/reviewer"
```

---

### Task 7: グローバル `~/.claude/CLAUDE.md` 改修（破壊的）

**Files:**
- Modify: `~/.claude/CLAUDE.md`

**Interfaces:**
- Consumes: Task 6 で確定した `claude/CLAUDE.md` の表現を、実環境のグローバル設定に反映する。

- [ ] **Step 1: バックアップ**

Run:
```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
echo "backed up"
```
Expected: `backed up`

- [ ] **Step 2: Agent roster / モデル注記 / Orchestration pattern / Selection rules / Quick reference を更新**

`~/.claude/CLAUDE.md` の `## OpenCode Integration` セクションを、Task 6 の `claude/CLAUDE.md` と同じ内容（executor/reviewer、設計は CC、`agent/*.md` frontmatter モデル）に書き換える。Keyword triggers のスキル名は変更しない。

- [ ] **Step 3: 検証**

Run:
```bash
grep -nE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" ~/.claude/CLAUDE.md || echo "CLEAN"
```
Expected: `CLEAN`

注: リポジトリ外ファイルのため git コミット対象外。バックアップ `~/.claude/CLAUDE.md.bak` は動作確認後にユーザー判断で削除。

---

### Task 8: 最終検証（全体 grep + end-to-end 動作確認）

**Files:** なし（検証のみ）

- [ ] **Step 1: リポジトリ全体で旧名・OmO が 0 件であることを確認**

Run:
```bash
grep -rnE "Atlas|Hephaestus|Prometheus|Sisyphus|oh-my-openagent|Plan Executor|Deep Agent|Plan Builder" . --exclude-dir=.git --exclude-dir=.omc --exclude-dir=docs 2>/dev/null || echo "CLEAN (excluding docs/.git/.omc)"
```
Expected: `CLEAN (excluding docs/.git/.omc)`（`docs/` の設計書・本計画には経緯説明として旧名が残る。成果物=スキル/設定/ドキュメントが対象）。

- [ ] **Step 2: agent 認識の最終確認**

Run:
```bash
/home/server/.opencode/bin/opencode agent list 2>/dev/null | grep -iE "^executor|^reviewer| executor | reviewer "
```
Expected: `executor (primary)` と `reviewer (primary)`。

- [ ] **Step 3: executor の end-to-end 動作確認**

一時ディレクトリで executor が「言われたことだけ実装して止まる」ことを確認する:

Run:
```bash
TMPD=$(mktemp -d)
/home/server/.opencode/bin/opencode run "Create a file hello.txt containing exactly 'hello world' in the current directory, then stop and report. Do not do anything else." \
  --agent executor --dir "$TMPD" --dangerously-skip-permissions 2>&1 | tail -25
echo "--- result ---"
cat "$TMPD/hello.txt" 2>&1
rm -rf "$TMPD"
```
Expected: `hello.txt` が `hello world` を含み、executor がスコープ拡大せず（追加のタスク計画やサブエージェント起動なしで）報告して停止している。

- [ ] **Step 4: 完了報告**

全タスクの完了を確認し、`superpowers:finishing-a-development-branch` でブランチの統合方法を決める。

---

## Self-Review

- **Spec coverage:** 設計書 §4 の変更対象一覧と本計画の対応 — agent 定義 md(Task1)、リポジトリ OmO 排除(Task1)、実環境インストール+opencode.json 整理(Task2)、reviewer write/patch 検証(Task2 Step5 = 設計 §7.1)、opencode-sdd(Task3)、ask-opencode(Task4)、opencode-worker(Task5)、claude/CLAUDE.md+AGENTS.md+README(Task6)、グローバル CLAUDE.md(Task7)、最終 grep+end-to-end(Task8 = 設計 §7.4)。全項目にタスクが対応。
- **Placeholder scan:** 各編集に before→after の具体文字列とコマンド・期待出力を記載。"適切に" 等の曖昧語なし。
- **Type consistency:** エージェント名は全タスクで `executor` / `reviewer`（小文字・スペースなし）で一貫。CLI は `--agent executor` / `--agent reviewer` で統一。
</content>
