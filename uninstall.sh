#!/bin/bash
# uninstall.sh — Uninstall the LLM Wiki skill / agent from every harness
# Usage: uninstall.sh [--force]
# Removes the skill links, wiki slash commands, and agent-manual links that
# agent-install.sh (or install.sh) created for Claude Code, Codex, Pi, and Bob
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

Uninstall the LLM Wiki skill / agent from every harness it was wired into.

Removes:
  • ~/.agents/skills/llm-wiki, ~/.claude/skills/llm-wiki,
    ~/.pi/agent/skills/llm-wiki, ~/.bob/skills/llm-wiki   (skill dirs or symlinks)
  • wiki-*.md slash commands in ~/.claude/commands, $CODEX_HOME/prompts,
    ~/.pi/agent/prompts
  • ~/.claude/CLAUDE.md, $CODEX_HOME/AGENTS.md, ~/.pi/agent/AGENTS.md,
    ~/.bob/rules/llm-wiki.md      (only where they are symlinks to AGENT.md)
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

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILL_DIRS=(
    "$HOME/.agents/skills/llm-wiki"
    "$HOME/.claude/skills/llm-wiki"
    "$HOME/.pi/agent/skills/llm-wiki"
    "$HOME/.bob/skills/llm-wiki"
)
COMMANDS_DIRS=(
    "$HOME/.claude/commands"
    "$CODEX_DIR/prompts"
    "$HOME/.pi/agent/prompts"
)
MANUAL_LINKS=(
    "$HOME/.claude/CLAUDE.md"
    "$CODEX_DIR/AGENTS.md"
    "$HOME/.pi/agent/AGENTS.md"
    "$HOME/.bob/rules/llm-wiki.md"
)
AGENT_SENTINEL="$HOME/.llm-wiki-installed"
AGENT_SRC="${LLM_WIKI_AGENT_HOME:-$HOME/.llm-wiki-agent}"

# Agent-mode manual links: only touch a path if it is our symlink to AGENT.md
OUR_MANUALS=()
for link in "${MANUAL_LINKS[@]}"; do
    if [ -L "$link" ]; then
        case "$(readlink "$link")" in
            */AGENT.md) OUR_MANUALS+=("$link") ;;
        esac
    fi
done

# Skill paths that exist and are not merely an alias of another listed path
# (on the platform images ~/.claude/skills is a symlink to ~/.agents/skills).
present_skill_dirs() {
    local seen="" d
    for d in "${SKILL_DIRS[@]}"; do
        if [ -d "$d" ] || [ -L "$d" ]; then
            local real
            real="$(cd "$(dirname "$d")" 2>/dev/null && pwd -P)/$(basename "$d")"
            case "$seen" in *"|$real|"*) continue ;; esac
            seen="$seen|$real|"
            echo "$d"
        fi
    done
}

present_command_files() {
    local d f
    for d in "${COMMANDS_DIRS[@]}"; do
        for f in "$d"/wiki-*.md; do
            [ -e "$f" ] || [ -L "$f" ] || continue
            echo "$f"
        done
    done
}

# ── Pre-flight check ────────────────────────────────────────────────────────

FOUND_ANYTHING=false

PRESENT_SKILLS="$(present_skill_dirs)"
PRESENT_COMMANDS="$(present_command_files)"

if [ -n "$PRESENT_SKILLS" ] || [ -n "$PRESENT_COMMANDS" ]; then
    FOUND_ANYTHING=true
fi

if [ "${#OUR_MANUALS[@]}" -gt 0 ] || [ -f "$AGENT_SENTINEL" ] || [ -d "$AGENT_SRC" ]; then
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

if [ -n "$PRESENT_SKILLS" ]; then
    echo "  Skill directories / symlinks:"
    while IFS= read -r d; do
        echo "    ${YELLOW}$d${NC}"
    done <<< "$PRESENT_SKILLS"
fi

if [ -n "$PRESENT_COMMANDS" ]; then
    echo "  Slash commands:"
    while IFS= read -r f; do
        echo "    ${YELLOW}$f${NC}"
    done <<< "$PRESENT_COMMANDS"
fi

if [ "${#OUR_MANUALS[@]}" -gt 0 ]; then
    echo "  Agent manual symlinks:"
    for link in "${OUR_MANUALS[@]}"; do
        echo "    ${YELLOW}$link${NC}"
    done
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

# 1. Remove skill directories (or agent-mode symlinks — target repo untouched)
if [ -n "$PRESENT_SKILLS" ]; then
    while IFS= read -r d; do
        rm -rf "$d"
        success "Removed $d"
        REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
    done <<< "$PRESENT_SKILLS"
else
    warn "Skill directory not found (already removed?)"
fi

# 2. Remove wiki command files from every harness command directory
if [ -n "$PRESENT_COMMANDS" ]; then
    while IFS= read -r f; do
        rm -f "$f"
        success "Removed $f"
        REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
    done <<< "$PRESENT_COMMANDS"
else
    warn "No wiki command files found (already removed?)"
fi

# 3. Remove agent-mode artifacts (manual symlinks + source + install sentinel)
for link in "${OUR_MANUALS[@]}"; do
    rm -f "$link"
    success "Removed agent manual symlink $link"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
done

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
