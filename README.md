# claude-opencode-sdd

ClaudeCode をオーケストレーターとして、OpenCode エージェント群をサブエージェントに使う SDD (Subagent-Driven Development) ワークフローのセットアップ一式。

## 構成概要

```
ClaudeCode (orchestrator)
  ├─ 壁打ち・設計・レビュー
  ├─ /superpowers:writing-plans で設計書・実装計画を作成
  └─ /oh-my-claudecode:opencode-sdd で OpenCode エージェントに実装を委譲

OpenCode (implementer / reviewer)
  ├─ Atlas - Plan Executor    → 実装・コード生成
  ├─ Hephaestus - Deep Agent  → レビュー・分析
  └─ Prometheus - Plan Builder → 設計・計画立案
```

## 前提条件

| ツール | 確認コマンド |
|--------|-------------|
| [Claude Code](https://claude.ai/code) | `claude --version` |
| [OpenCode](https://opencode.ai) | `opencode --version` |
| [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | `opencode plugin` で確認 |
| OpenRouter API キー | `opencode providers` |

## セットアップ

```bash
git clone https://github.com/kakeru-ikeda/claude-opencode-sdd.git
cd claude-opencode-sdd
```

このディレクトリで Claude Code を開き、以下を伝えるだけ:

```
AGENTS.md に従ってセットアップして
```

エージェントが既存設定を確認しながら、上書きせずにインストールします。
詳細は [AGENTS.md](./AGENTS.md) を参照。

## 何がインストールされるか

### ユーザースキル 3種（`~/.claude/skills/`）

OMC プラグイン非依存。プラグイン更新で上書きされない。

| スキル | 用途 |
|--------|------|
| `ask-opencode` | 1回限りの実装委譲 (one-shot) |
| `opencode-worker` | 永続サーバーセッションで反復実装 |
| `opencode-sdd` | SDD フルワークフロー（実装→レビュー→fix ループ） |

### `~/.claude/CLAUDE.md`（既存なければインストール、あればマージ確認）

開発デフォルト指針:
- 開発フロー (genshijin → deepinit → writing-plans → opencode-sdd)
- OpenCode エージェントのキーワードトリガーと選択ルール

### `opencode/oh-my-openagent.json`（サンプル・参考用）

モデル設定はユーザーが自分で決めるもの。
このリポジトリのサンプルは openrouter を使用（Hephaestus=GPT-5.4、Atlas/Prometheus=Kimi K2.7 Code）。
既存ファイルがある場合、エージェントは差分を表示するだけで自動マージしない。

## 開発ワークフロー

```
1. /genshijin                         — 簡潔モードで会話コスト削減
2. /oh-my-claudecode:deepinit         — コードベース把握（必要時）
3. 不明点は質問                       — 推測で進めない
4. /superpowers:writing-plans         — 設計書 + 実装計画を docs/ に作成
5. TaskCreate                         — 実装タスクを起票
6. /oh-my-claudecode:opencode-sdd     — TDD で Atlas/Hephaestus が実装・レビュー
```

## ライセンス

MIT
