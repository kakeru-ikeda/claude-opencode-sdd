#!/usr/bin/env bash
# Install claude-opencode-sdd configuration
# ClaudeCode (orchestrator) + OpenCode agents (implementer/reviewer) via SDD workflow
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== claude-opencode-sdd setup ==="

# --- 1. CLAUDE.md ---
echo "[1/3] Installing ~/.claude/CLAUDE.md ..."
mkdir -p ~/.claude

if [ -f ~/.claude/CLAUDE.md ]; then
  echo "  Existing CLAUDE.md found. Backing up to ~/.claude/CLAUDE.md.bak"
  cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
fi

cp "$REPO_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md
echo "  Done."

# --- 2. OpenCode config ---
echo "[2/3] Installing OpenCode config to ~/.config/opencode/ ..."
mkdir -p ~/.config/opencode

# opencode.json: merge plugin list if file already exists
if [ -f ~/.config/opencode/opencode.json ]; then
  echo "  Existing opencode.json found — overwriting."
fi
cp "$REPO_DIR/opencode/opencode.json" ~/.config/opencode/opencode.json

cp "$REPO_DIR/opencode/oh-my-openagent.json" ~/.config/opencode/oh-my-openagent.json
echo "  Done."

# --- 3. OMC skills ---
echo "[3/3] Installing OMC skills ..."

OMC_BASE=~/.claude/plugins/cache/omc/oh-my-claudecode
if [ ! -d "$OMC_BASE" ]; then
  echo "  ERROR: oh-my-claudecode plugin not found at $OMC_BASE"
  echo "  Install it first: open Claude Code → /plugin install oh-my-claudecode"
  exit 1
fi

OMC_VERSION=$(ls "$OMC_BASE" | sort -V | tail -1)
OMC_SKILLS="$OMC_BASE/$OMC_VERSION/skills"
echo "  Target: $OMC_SKILLS (version $OMC_VERSION)"

for skill_dir in "$REPO_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$OMC_SKILLS/$skill_name"
  cp "$skill_dir/SKILL.md" "$OMC_SKILLS/$skill_name/SKILL.md"
  echo "  Installed skill: $skill_name"
done

echo ""
echo "=== Setup complete ==="
echo "Restart Claude Code, then run:"
echo "  /reload-plugins   — load updated OMC skills"
echo "  /reload-skills    — verify skills are available"
echo ""
echo "Installed skills:"
echo "  /oh-my-claudecode:ask-opencode    — one-shot OpenCode delegation"
echo "  /oh-my-claudecode:opencode-worker — persistent OpenCode server session"
echo "  /oh-my-claudecode:opencode-sdd    — SDD workflow with OpenCode agents"
