# claude-opencode-sdd

ClaudeCode をオーケストレーターとして、OpenCode エージェント群をサブエージェントに使う SDD (Subagent-Driven Development) ワークフローのセットアップ一式。

## 構成概要

```
ClaudeCode (orchestrator)
  ├─ 壁打ち・設計・レビュー
  ├─ /superpowers:writing-plans で設計書・実装計画を作成
  └─ /oh-my-claudecode:opencode-sdd で OpenCode エージェントに実装を委譲

OpenCode (implementer / reviewer)
  ├─ Atlas - Plan Executor   → 実装・コード生成
  ├─ Hephaestus - Deep Agent → レビュー・分析
  └─ Prometheus - Plan Builder → 設計・計画立案
```

## 前提条件

| ツール | 確認コマンド |
|--------|-------------|
| [Claude Code](https://claude.ai/code) | `claude --version` |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) plugin | Claude Code 内で `/plugin list` |
| [OpenCode](https://opencode.ai) | `opencode --version` |
| [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | OpenCode 内で確認 |
| OpenRouter API キー | `opencode providers` で設定済みか確認 |

## セットアップ

```bash
git clone https://github.com/kakeru-ikeda/claude-opencode-sdd.git
cd claude-opencode-sdd
chmod +x setup.sh
./setup.sh
```

その後 Claude Code を再起動して:
```
/reload-plugins
/reload-skills
```

## 何がインストールされるか

### `~/.claude/CLAUDE.md`

開発デフォルト指針を記載したグローバル設定:
- 開発フロー (genshijin → deepinit → writing-plans → opencode-sdd)
- OpenCode エージェントのキーワードトリガー

### `~/.config/opencode/oh-my-openagent.json`

各エージェントに openrouter モデルを割り当て:
- Hephaestus → `openrouter/openai/gpt-5.4`
- Prometheus / Atlas → `openrouter/moonshotai/kimi-k2.7-code`
- Sisyphus → `openrouter/anthropic/claude-opus-4.8`

モデル変更はこのファイルだけ編集すれば OK。スキルファイルへの記載なし。

### OMC スキル 3種

| スキル | 用途 |
|--------|------|
| `ask-opencode` | 1回限りの実装委譲 (one-shot) |
| `opencode-worker` | 永続サーバーセッションで反復実装 |
| `opencode-sdd` | SDD フルワークフロー (実装→レビュー→fix ループ) |

## 開発ワークフロー

```
1. /genshijin          — 簡潔モードで会話コスト削減
2. /oh-my-claudecode:deepinit  — コードベース把握（必要時）
3. 不明点は質問        — 推測で進めない
4. /superpowers:writing-plans  — 設計書 + 実装計画を docs/ に作成
5. TaskCreate          — 実装タスクを起票
6. /oh-my-claudecode:opencode-sdd  — TDD で Atlas/Hephaestus が実装・レビュー
```

## エージェント呼び出し例

```bash
# 実装
opencode run "task" --agent "Atlas - Plan Executor" --dangerously-skip-permissions

# レビュー・分析
opencode run "task" --agent "Hephaestus - Deep Agent" --dangerously-skip-permissions

# 設計・計画
opencode run "task" --agent "Prometheus - Plan Builder" --dangerously-skip-permissions
```

## ライセンス

MIT
