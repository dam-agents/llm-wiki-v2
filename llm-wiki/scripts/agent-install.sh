#!/bin/bash
# agent-install.sh — Register this repo as the machine's LLM Wiki agent
# Usage: agent-install.sh [--force] [--verbose]
# Symlinks (rather than copies) the skill, commands, and agent manual into
# $HOME/.claude/ and registers global session hooks, so `git pull` in the
# repo updates the live agent. Idempotent: guarded by $HOME/.llm-wiki-installed.
# See INSTALLATION.md for the full bootstrap procedure.
# Exit: 0 on success, 1 on error

set -euo pipefail

FORCE=false
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: agent-install.sh [--force] [--verbose]"
            echo "Symlink-install the LLM Wiki agent (skill, commands, manual, hooks)."
            echo "  --force     Re-apply even if the install sentinel exists"
            echo "  --verbose   Print detailed progress information"
            echo "  --help, -h  Show this help message"
            exit 0 ;;
        --force)   FORCE=true ;;
        --verbose) VERBOSE=true ;;
        *)         echo "Unknown option: $arg (use --help for usage)" >&2; exit 1 ;;
    esac
done

log() { if [ "$VERBOSE" = true ]; then echo "  [verbose] $*"; fi }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"    # llm-wiki/
REPO_ROOT="$(cd "$SKILL_SRC/.." && pwd)"     # repo root (the work directory)
CLAUDE_DIR="$HOME/.claude"
SENTINEL="$HOME/.llm-wiki-installed"

# ── Guard ────────────────────────────────────────────────────────────────────

if [ -f "$SENTINEL" ] && [ "$FORCE" != true ]; then
    echo "LLM Wiki agent already installed on: $(cat "$SENTINEL")"
    echo "Use --force to re-apply."
    exit 0
fi

echo "Installing LLM Wiki agent (symlink mode)..."
echo "  Repo:   $REPO_ROOT"
echo "  Target: $CLAUDE_DIR"
echo ""

# ── 1. Skill symlink ─────────────────────────────────────────────────────────

mkdir -p "$CLAUDE_DIR/skills"
SKILL_DST="$CLAUDE_DIR/skills/llm-wiki"
if [ -e "$SKILL_DST" ] && [ ! -L "$SKILL_DST" ]; then
    log "Replacing existing copy-installed skill at $SKILL_DST"
    rm -rf "$SKILL_DST"
fi
ln -sfn "$SKILL_SRC" "$SKILL_DST"
echo "  ✓ skill: $SKILL_DST → $SKILL_SRC"

# ── 2. Command symlinks ──────────────────────────────────────────────────────

mkdir -p "$CLAUDE_DIR/commands"
COMMAND_COUNT=0
for cmd in "$SKILL_SRC/commands"/*.md; do
    if [ -f "$cmd" ]; then
        ln -sfn "$cmd" "$CLAUDE_DIR/commands/$(basename "$cmd")"
        log "command: $(basename "$cmd" .md)"
        COMMAND_COUNT=$((COMMAND_COUNT + 1))
    fi
done
echo "  ✓ commands: $COMMAND_COUNT linked into $CLAUDE_DIR/commands/"

# ── 3. Agent manual → global CLAUDE.md ───────────────────────────────────────

MANUAL_SRC="$REPO_ROOT/AGENT.md"
MANUAL_DST="$CLAUDE_DIR/CLAUDE.md"
if [ ! -f "$MANUAL_SRC" ]; then
    echo "ERROR: AGENT.md not found at $MANUAL_SRC" >&2
    exit 1
fi
if [ -f "$MANUAL_DST" ] && [ ! -L "$MANUAL_DST" ]; then
    BACKUP="$MANUAL_DST.backup-$(date -u +"%Y%m%d%H%M%S")"
    mv "$MANUAL_DST" "$BACKUP"
    echo "  ! existing global CLAUDE.md backed up to $BACKUP"
fi
ln -sfn "$MANUAL_SRC" "$MANUAL_DST"
echo "  ✓ manual: $MANUAL_DST → $MANUAL_SRC"

# ── 4. Global session hooks ──────────────────────────────────────────────────

SETTINGS="$CLAUDE_DIR/settings.json"
START_HOOK="$CLAUDE_DIR/skills/llm-wiki/hooks/session-start.sh"
STOP_HOOK="$CLAUDE_DIR/skills/llm-wiki/hooks/session-stop.sh"

if [ -f "$SETTINGS" ] && grep -q "skills/llm-wiki/hooks/session-start.sh" "$SETTINGS"; then
    echo "  ✓ hooks: already registered in $SETTINGS"
elif [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" << SETEOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$START_HOOK" }]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$STOP_HOOK" }]
      }
    ]
  }
}
SETEOF
    echo "  ✓ hooks: created $SETTINGS"
elif command -v jq >/dev/null 2>&1; then
    jq --arg start "$START_HOOK" --arg stop "$STOP_HOOK" '
        .hooks.SessionStart = ((.hooks.SessionStart // []) +
            [{"matcher": "", "hooks": [{"type": "command", "command": $start}]}]) |
        .hooks.SessionEnd = ((.hooks.SessionEnd // []) +
            [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}])
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ hooks: merged into $SETTINGS"
else
    echo "  ⚠ jq not found — add the hooks to $SETTINGS manually:"
    echo "    SessionStart → $START_HOOK"
    echo "    SessionEnd   → $STOP_HOOK"
fi

# ── 5. Permissions + sentinel ────────────────────────────────────────────────

chmod +x "$SKILL_SRC/scripts/"*.sh 2>/dev/null || true
chmod +x "$SKILL_SRC/hooks/"*.sh 2>/dev/null || true

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$SENTINEL"
echo "  ✓ sentinel: $SENTINEL"

# ── Verify ───────────────────────────────────────────────────────────────────

ALL_OK=true
[ -L "$SKILL_DST" ] || { echo "  ✗ skill symlink missing" >&2; ALL_OK=false; }
[ -L "$MANUAL_DST" ] || { echo "  ✗ manual symlink missing" >&2; ALL_OK=false; }
[ -f "$SENTINEL" ] || { echo "  ✗ sentinel missing" >&2; ALL_OK=false; }

if [ "$ALL_OK" != true ]; then
    echo ""
    echo "Installation incomplete — see errors above." >&2
    exit 1
fi

echo ""
echo "LLM Wiki agent installed."
echo ""
echo "Onboarding has NOT run — it is a separate, interactive step."
echo "The next session will request it automatically; run /wiki-onboard to"
echo "start it manually."
