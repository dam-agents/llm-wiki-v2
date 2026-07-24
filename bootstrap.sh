#!/bin/bash
# bootstrap.sh — One-command install of the LLM Wiki agent
#
# On a brand-new machine, from the work directory (e.g. /home/agent/work):
#   curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash
# With the repo already checked out: ./bootstrap.sh
#
# Deterministic machine setup ONLY. Onboarding (the interactive wiki
# interview) is intentionally NOT started here — the session-start hook
# requests it in the next session. See INSTALLATION.md.
#
# Env overrides:
#   LLM_WIKI_REPO  Git URL to bootstrap from (default: dam-agents/llm-wiki-v2)
# Exit: 0 on success or already installed, 1 on error

set -euo pipefail

REPO_URL="${LLM_WIKI_REPO:-https://github.com/dam-agents/llm-wiki-v2.git}"
SENTINEL="$HOME/.llm-wiki-installed"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: bootstrap.sh"
    echo "Bootstrap the LLM Wiki agent into the current directory (the work"
    echo "directory) and install it machine-wide. Idempotent: exits early if"
    echo "\$HOME/.llm-wiki-installed exists."
    echo "  Env: LLM_WIKI_REPO overrides the source repository URL."
    exit 0
fi

if [ -f "$SENTINEL" ]; then
    echo "LLM Wiki agent already installed on: $(cat "$SENTINEL")"
    exit 0
fi

WORK_DIR="$(pwd)"
echo "Bootstrapping LLM Wiki agent into: $WORK_DIR"
echo ""

# ── 1. Sync the agent-definition repo into the work directory ───────────────
# NEVER git clean here — untracked and gitignored content (wiki/, user files
# in .raw/) must survive every sync.

if [ ! -d .git ]; then
    git init -b main
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$REPO_URL"
fi

# Route git auth through gh when it is installed and authenticated
if command -v gh >/dev/null 2>&1; then
    gh auth setup-git >/dev/null 2>&1 || true
fi

git fetch origin
git reset --hard origin/main
echo ""

# ── 2. Hand over to the repo's installer ────────────────────────────────────
# Symlinks skill/commands/manual, registers hooks, writes the sentinel.

bash "$WORK_DIR/llm-wiki/scripts/agent-install.sh"
