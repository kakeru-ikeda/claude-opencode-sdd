# AGENTS.md — Setup Guide for Claude Code

このリポジトリのセットアップを Claude Code エージェントが実行するためのガイド。
新しい端末でこのリポジトリを clone し、Claude Code 上で「AGENTS.md に従ってセットアップして」と伝えると実行される。

## What This Repo Provides

- `claude/CLAUDE.md` — 開発デフォルト指針（OpenCode 統合・エージェント選択ルール）
- `opencode/agent/executor.md`・`opencode/agent/reviewer.md` — OpenCode 実装/レビュー専用エージェント定義
- `opencode/opencode.json` — OpenCode 設定（プラグイン依存なし）
- `skills/` — カスタムスキル 3種

## Setup Instructions for the Agent

### Step 1: Install skills

スキルを `~/.claude/skills/` にコピーする（OMC 非依存・プラグイン更新に影響されない）。
既存ファイルは上書きして構わない（これらはこのリポジトリが管理するスキルファイルのため）。

```bash
for skill in skills/*/; do
  name=$(basename "$skill")
  mkdir -p "$HOME/.claude/skills/$name"
  cp "$skill/SKILL.md" "$HOME/.claude/skills/$name/SKILL.md"
  echo "Installed: $name"
done
```

### Step 2: Install or merge CLAUDE.md

`~/.claude/CLAUDE.md` が**存在しない**場合のみコピーする。
既存ファイルがある場合は、`claude/CLAUDE.md` の内容を確認し、`## Development Workflow` と `## OpenCode Integration` のセクションが含まれていなければ末尾に追記する。上書きはしない。

```bash
if [ ! -f ~/.claude/CLAUDE.md ]; then
  cp claude/CLAUDE.md ~/.claude/CLAUDE.md
  echo "Installed CLAUDE.md"
else
  echo "~/.claude/CLAUDE.md already exists — check and merge manually if needed"
  echo "Sections to add if missing:"
  echo "  - ## Development Workflow"
  echo "  - ## OpenCode Integration"
fi
```

### Step 3: Install OpenCode agent definitions

`opencode/agent/*.md`（`executor` / `reviewer`）を `~/.config/opencode/agent/` にコピーする。
OmO プラグインは不要。既存の同名ファイルがある場合は上書きせず差分を表示する。

```bash
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

### Step 4: Reload

セットアップ完了後、Claude Code 上で実行:
```
/reload-skills
```

## Agent Keys (for OpenCode)

`opencode/agent/*.md` のモデルは openrouter を使用。利用には OpenRouter の API キーが必要:

```bash
opencode providers  # 認証状況確認
```

モデルの変更は `~/.config/opencode/agent/executor.md` / `reviewer.md` の frontmatter `model:` を直接編集する。
スキルファイルにモデル名は記載しない設計のため、スキルは変更不要。

## Installed Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| `ask-opencode` | `/ask-opencode "task"` | 1回限りの実装委譲 |
| `opencode-worker` | `/opencode-worker start` | 永続サーバーセッション |
| `opencode-sdd` | `/opencode-sdd plan.md` | SDD フルワークフロー |
