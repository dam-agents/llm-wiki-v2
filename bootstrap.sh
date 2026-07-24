#!/bin/bash
# bootstrap.sh — One-command install of the LLM Wiki agent
#
# On a brand-new machine, from anywhere:
#   curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash
# From a local checkout: ./bootstrap.sh
#
# Installs the agent tooling into $HOME/.llm-wiki-agent (a git checkout) and
# symlinks it into ~/.claude. It NEVER touches the working directory or the
# wiki — those belong to onboarding, which is a separate, interactive step.
# See INSTALLATION.md.
#
# Env overrides:
#   LLM_WIKI_REPO        Git URL or local path to install from
#                        (default: dam-agents/llm-wiki-v2, or a local checkout
#                        if bootstrap.sh is run from inside one)
#   LLM_WIKI_AGENT_HOME  Install location (default: $HOME/.llm-wiki-agent)
# Exit: 0 on success or already installed, 1 on error

set -euo pipefail

AGENT_HOME="${LLM_WIKI_AGENT_HOME:-$HOME/.llm-wiki-agent}"
SENTINEL="$HOME/.llm-wiki-installed"

# Source repo: the remote by default. If bootstrap.sh is being run from inside
# a local checkout, prefer that checkout so local commits are honored.
DEFAULT_REPO="https://github.com/dam-agents/llm-wiki-v2.git"
if [ -z "${LLM_WIKI_REPO:-}" ]; then
    SELF="${BASH_SOURCE[0]:-}"
    if [ -n "$SELF" ] && [ -f "$SELF" ]; then
        SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
        if [ -f "$SELF_DIR/llm-wiki/SKILL.md" ]; then
            DEFAULT_REPO="$SELF_DIR"
        fi
    fi
fi
REPO_URL="${LLM_WIKI_REPO:-$DEFAULT_REPO}"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: bootstrap.sh"
    echo "Install the LLM Wiki agent into \$HOME/.llm-wiki-agent and wire it"
    echo "into ~/.claude. Deterministic machine setup only — onboarding (the"
    echo "interactive wiki interview) runs separately at the next session."
    echo "Idempotent: exits early if already installed."
    echo "  Env: LLM_WIKI_REPO        source repo URL or local path"
    echo "       LLM_WIKI_AGENT_HOME  install location (default ~/.llm-wiki-agent)"
    exit 0
fi

if [ -f "$SENTINEL" ] && [ -d "$AGENT_HOME/.git" ]; then
    echo "LLM Wiki agent already installed on: $(cat "$SENTINEL")"
    echo "  Source: $AGENT_HOME"
    echo "  Update: git -C \"$AGENT_HOME\" pull --ff-only && bash \"$AGENT_HOME/llm-wiki/scripts/agent-install.sh\" --force"
    exit 0
fi

echo "Bootstrapping LLM Wiki agent"
echo "  Source repo: $REPO_URL"
echo "  Install to:  $AGENT_HOME"
echo ""

# Route git auth through gh when it is installed and authenticated
if command -v gh >/dev/null 2>&1; then
    gh auth setup-git >/dev/null 2>&1 || true
fi

# ── 1. Fetch the agent-definition repo into $HOME (never touches the work dir)
# Never run `git clean` — this directory holds only tooling, but the ethos is
# the same everywhere: syncs preserve, they do not destroy.

if [ -d "$AGENT_HOME/.git" ]; then
    git -C "$AGENT_HOME" fetch origin
    git -C "$AGENT_HOME" reset --hard origin/main
else
    git clone "$REPO_URL" "$AGENT_HOME"
fi
echo ""

# ── 2. Hand over to the installer (symlinks + hooks + sentinel) ─────────────

bash "$AGENT_HOME/llm-wiki/scripts/agent-install.sh"
