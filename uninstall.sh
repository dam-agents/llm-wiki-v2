#!/bin/bash
# uninstall.sh — Uninstall LLM Wiki skill from Claude Code
# Usage: uninstall.sh [--force]
# Removes the skill directory and wiki slash commands
# Exit: 0 on success, 1 on error

set -euo pipefail

# ── Colour helpers ──────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}!${NC} %s\n" "$*"; }
error()   { printf "${RED}✗${NC} %s\n" "$*" >&2; }

# ── Argument parsing ────────────────────────────────────────────────────────

FORCE=false

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat <<'USAGE'
Usage: uninstall.sh [--force]

Uninstall the LLM Wiki skill from Claude Code.

Removes:
  • ~/.claude/skills/llm-wiki/     (skill directory or symlink)
  • ~/.claude/commands/wiki-*.md   (slash commands or symlinks)
  • ~/.claude/CLAUDE.md            (only if it is a symlink to AGENT.md)
  • ~/.llm-wiki-agent/             (agent definition — tooling only, agent mode)
  • ~/.llm-wiki-installed          (agent install sentinel)

Your wiki content (in the working directory) is never touched.

Options:
  --force     Skip confirmation prompt
  --help, -h  Show this help message
USAGE
            exit 0 ;;
        --force) FORCE=true ;;
        *)       error "Unknown option: $arg (use --help for usage)"; exit 1 ;;
    esac
done

# ── Paths ───────────────────────────────────────────────────────────────────

SKILL_DIR="$HOME/.claude/skills/llm-wiki"
COMMANDS_DIR="$HOME/.claude/commands"
MANUAL_LINK="$HOME/.claude/CLAUDE.md"
AGENT_SENTINEL="$HOME/.llm-wiki-installed"
AGENT_SRC="${LLM_WIKI_AGENT_HOME:-$HOME/.llm-wiki-agent}"

# Agent-mode manual: only touch ~/.claude/CLAUDE.md if it is our symlink
MANUAL_IS_OURS=false
if [ -L "$MANUAL_LINK" ]; then
    case "$(readlink "$MANUAL_LINK")" in
        */AGENT.md) MANUAL_IS_OURS=true ;;
    esac
fi

# ── Pre-flight check ────────────────────────────────────────────────────────

FOUND_ANYTHING=false

if [ -d "$SKILL_DIR" ] || [ -L "$SKILL_DIR" ]; then
    FOUND_ANYTHING=true
fi

if ls "$COMMANDS_DIR"/wiki-*.md >/dev/null 2>&1; then
    FOUND_ANYTHING=true
fi

if [ "$MANUAL_IS_OURS" = true ] || [ -f "$AGENT_SENTINEL" ] || [ -d "$AGENT_SRC" ]; then
    FOUND_ANYTHING=true
fi

if [ "$FOUND_ANYTHING" = false ]; then
    echo ""
    warn "No LLM Wiki installation found. Nothing to uninstall."
    exit 0
fi

# ── What will be removed ────────────────────────────────────────────────────

echo ""
echo "${BOLD}LLM Wiki — Uninstall${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -d "$SKILL_DIR" ]; then
    echo "  Skill directory:"
    echo "    ${YELLOW}$SKILL_DIR${NC}"
fi

if ls "$COMMANDS_DIR"/wiki-*.md >/dev/null 2>&1; then
    echo "  Slash commands:"
    for f in "$COMMANDS_DIR"/wiki-*.md; do
        if [ -f "$f" ]; then
            echo "    ${YELLOW}$f${NC}"
        fi
    done
fi

if [ "$MANUAL_IS_OURS" = true ]; then
    echo "  Agent manual symlink:"
    echo "    ${YELLOW}$MANUAL_LINK${NC}"
fi

if [ -d "$AGENT_SRC" ]; then
    echo "  Agent definition (tooling only):"
    echo "    ${YELLOW}$AGENT_SRC${NC}"
fi

if [ -f "$AGENT_SENTINEL" ]; then
    echo "  Agent install sentinel:"
    echo "    ${YELLOW}$AGENT_SENTINEL${NC}"
fi

echo ""

# ── Confirmation ────────────────────────────────────────────────────────────

if [ "$FORCE" != true ]; then
    read -r -p "Remove the above? [y/N] " CONFIRM
    case "$CONFIRM" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

# ── Removal ─────────────────────────────────────────────────────────────────

echo ""

REMOVED_ITEMS=0

# 1. Remove skill directory (or agent-mode symlink — target repo untouched)
if [ -d "$SKILL_DIR" ] || [ -L "$SKILL_DIR" ]; then
    rm -rf "$SKILL_DIR"
    success "Removed skill directory"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
else
    warn "Skill directory not found (already removed?)"
fi

# 2. Remove wiki command files
if ls "$COMMANDS_DIR"/wiki-*.md >/dev/null 2>&1; then
    for f in "$COMMANDS_DIR"/wiki-*.md; do
        if [ -f "$f" ]; then
            rm -f "$f"
            success "Removed $(basename "$f")"
            REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
        fi
    done
else
    warn "No wiki command files found (already removed?)"
fi

# 3. Remove agent-mode artifacts (manual symlink + source + install sentinel)
if [ "$MANUAL_IS_OURS" = true ]; then
    rm -f "$MANUAL_LINK"
    success "Removed agent manual symlink"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ -d "$AGENT_SRC" ]; then
    rm -rf "$AGENT_SRC"
    success "Removed agent definition ($AGENT_SRC)"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ -f "$AGENT_SENTINEL" ]; then
    rm -f "$AGENT_SENTINEL"
    success "Removed agent install sentinel"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ -f "$HOME/.claude/settings.json" ] && grep -q "skills/llm-wiki/hooks" "$HOME/.claude/settings.json" 2>/dev/null; then
    warn "$HOME/.claude/settings.json still references llm-wiki hooks — remove the SessionStart/SessionEnd entries manually."
fi

# ── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "${BOLD}Uninstall complete${NC}"
printf "  ${GREEN}%d item(s) removed${NC}\n" "$REMOVED_ITEMS"
echo ""
echo "The LLM Wiki skill and its slash commands have been removed."
echo "Your project wiki directories (./wiki/) are untouched."
exit 0
