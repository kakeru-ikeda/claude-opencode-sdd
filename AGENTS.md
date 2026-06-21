# AGENTS.md — Setup Guide for Claude Code

このリポジトリのセットアップを Claude Code エージェントが実行するためのガイド。
新しい端末でこのリポジトリを clone し、Claude Code 上で「AGENTS.md に従ってセットアップして」と伝えると実行される。

## What This Repo Provides

- `claude/CLAUDE.md` — 開発デフォルト指針（OpenCode 統合・エージェント選択ルール）
- `opencode/oh-my-openagent.json` — OpenCode エージェント定義のサンプル（モデルはユーザーが上書き）
- `skills/` — OMC カスタムスキル 3種

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

### Step 3: OpenCode agent config (optional / user decides)

`opencode/oh-my-openagent.json` はあくまで**参考サンプル**。
ユーザーに確認してから対応を選ぶ：

- **既存の `~/.config/opencode/oh-my-openagent.json` がない** → コピーして構わない
- **既存ファイルがある** → 差分を表示してユーザーに判断を委ねる。エージェントは勝手にマージまたは上書きしない

```bash
if [ ! -f ~/.config/opencode/oh-my-openagent.json ]; then
  mkdir -p ~/.config/opencode
  cp opencode/oh-my-openagent.json ~/.config/opencode/oh-my-openagent.json
  echo "Installed oh-my-openagent.json"
else
  echo "~/.config/opencode/oh-my-openagent.json already exists."
  echo "--- diff (repo vs installed) ---"
  diff opencode/oh-my-openagent.json ~/.config/opencode/oh-my-openagent.json || true
  echo "--- Merge manually if desired ---"
fi
```

### Step 4: Reload

セットアップ完了後、Claude Code 上で実行:
```
/reload-skills
```

## Agent Keys (for OpenCode)

このリポジトリのモデル設定 (`opencode/oh-my-openagent.json`) は openrouter を使用。
利用には OpenRouter の API キーが必要:

```bash
opencode providers  # 認証状況確認
```

モデルの変更は `~/.config/opencode/oh-my-openagent.json` をユーザーが直接編集。
スキルファイルにモデル名は記載しない設計のため、スキルは変更不要。

## Installed Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| `ask-opencode` | `/ask-opencode "task"` | 1回限りの実装委譲 |
| `opencode-worker` | `/opencode-worker start` | 永続サーバーセッション |
| `opencode-sdd` | `/opencode-sdd plan.md` | SDD フルワークフロー |
