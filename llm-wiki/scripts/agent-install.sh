#!/bin/bash
# agent-install.sh — Register this repo as the machine's LLM Wiki agent
# Usage: agent-install.sh [--force] [--verbose] [--harness <list>]
# Symlinks (rather than copies) the skill, commands, and agent manual into the
# places each installed harness reads them from, so `git pull` in the repo
# updates the live agent. Idempotent: guarded by $HOME/.llm-wiki-installed.
# See INSTALLATION.md for the full bootstrap procedure and the per-harness map.
#
# Harness selection (first match wins):
#   --harness <list>       comma/space-separated: claude-code codex pi bob all
#   LLM_WIKI_HARNESS=<list>  same, as an environment variable
#   PLATFORM_HARNESS=<family>  the family the platform's harness image runs (set in the image)
#   autodetect             every harness CLI found on PATH (claude, codex, pi, bob);
#                          falls back to claude-code when none is found
# Exit: 0 on success, 1 on error

set -euo pipefail

KNOWN_HARNESSES="claude-code codex pi bob"

FORCE=false
VERBOSE=false
HARNESS_ARG="${LLM_WIKI_HARNESS:-${PLATFORM_HARNESS:-}}"
while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            echo "Usage: agent-install.sh [--force] [--verbose] [--harness <list>]"
            echo "Symlink-install the LLM Wiki agent (skill, commands, manual, hooks)"
            echo "for every selected harness."
            echo "  --harness <list>  Harnesses to wire: claude-code, codex, pi, bob, all"
            echo "                    (comma/space-separated; default: LLM_WIKI_HARNESS,"
            echo "                    else PLATFORM_HARNESS, else every harness CLI found"
            echo "                    on PATH, else claude-code)"
            echo "  --force           Re-apply even if the install sentinel exists"
            echo "  --verbose         Print detailed progress information"
            echo "  --help, -h        Show this help message"
            exit 0 ;;
        --force)   FORCE=true ;;
        --verbose) VERBOSE=true ;;
        --harness)
            [ $# -ge 2 ] || { echo "--harness needs a value" >&2; exit 1; }
            HARNESS_ARG="$2"; shift ;;
        --harness=*) HARNESS_ARG="${1#--harness=}" ;;
        *)         echo "Unknown option: $1 (use --help for usage)" >&2; exit 1 ;;
    esac
    shift
done

log() { if [ "$VERBOSE" = true ]; then echo "  [verbose] $*"; fi }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$(cd "$SCRIPT_DIR/.." && pwd)"    # llm-wiki/
REPO_ROOT="$(cd "$SKILL_SRC/.." && pwd)"     # repo root (the agent definition)
MANUAL_SRC="$REPO_ROOT/AGENT.md"
SENTINEL="$HOME/.llm-wiki-installed"
SHARED_SKILLS_DIR="$HOME/.agents/skills"     # agentskills.io — read by every harness

# ── Harness selection ────────────────────────────────────────────────────────

detect_harnesses() {
    local found=""
    command -v claude >/dev/null 2>&1 && found="$found claude-code"
    command -v codex  >/dev/null 2>&1 && found="$found codex"
    command -v pi     >/dev/null 2>&1 && found="$found pi"
    command -v bob    >/dev/null 2>&1 && found="$found bob"
    echo "${found# }"
}

HARNESSES="${HARNESS_ARG//,/ }"
if [ "$HARNESSES" = "all" ]; then
    HARNESSES="$KNOWN_HARNESSES"
elif [ -z "$HARNESSES" ]; then
    HARNESSES="$(detect_harnesses)"
    if [ -z "$HARNESSES" ]; then
        HARNESSES="claude-code"
        log "no harness CLI found on PATH — defaulting to claude-code"
    else
        log "detected harnesses: $HARNESSES"
    fi
fi
for h in $HARNESSES; do
    case " $KNOWN_HARNESSES " in
        *" $h "*) ;;
        *) echo "ERROR: unknown harness \"$h\" (known: $KNOWN_HARNESSES, all)" >&2; exit 1 ;;
    esac
done

# ── Guard ────────────────────────────────────────────────────────────────────

if [ -f "$SENTINEL" ] && [ "$FORCE" != true ]; then
    echo "LLM Wiki agent already installed on: $(cat "$SENTINEL")"
    echo "Use --force to re-apply (e.g. to wire an additional harness)."
    exit 0
fi

if [ ! -f "$MANUAL_SRC" ]; then
    echo "ERROR: AGENT.md not found at $MANUAL_SRC" >&2
    exit 1
fi

echo "Installing LLM Wiki agent (symlink mode)..."
echo "  Repo:      $REPO_ROOT"
echo "  Harnesses: $HARNESSES"
echo ""

# ── Helpers ──────────────────────────────────────────────────────────────────

# Replace a copy-installed skill directory with the symlink.
link_skill_into() {
    local dir="$1" dst="$1/llm-wiki"
    mkdir -p "$dir"
    if [ -d "$dir" ] && [ "$(cd "$dir" && pwd -P)" = "$(cd "$SHARED_SKILLS_DIR" && pwd -P)" ]; then
        log "skill dir $dir already resolves to $SHARED_SKILLS_DIR"
        return
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        log "Replacing existing copy-installed skill at $dst"
        rm -rf "$dst"
    fi
    ln -sfn "$SKILL_SRC" "$dst"
    echo "  ✓ skill: $dst → $SKILL_SRC"
}

# An existing regular file at the manual's path is backed up, never overwritten.
link_manual_to() {
    local dst="$1"
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
        local backup
        backup="$dst.backup-$(date -u +"%Y%m%d%H%M%S")"
        mv "$dst" "$backup"
        echo "  ! existing $(basename "$dst") backed up to $backup"
    fi
    ln -sfn "$MANUAL_SRC" "$dst"
    echo "  ✓ manual: $dst → $MANUAL_SRC"
}

link_commands_into() {
    local dir="$1" label="$2" count=0
    mkdir -p "$dir"
    for cmd in "$SKILL_SRC/commands"/*.md; do
        if [ -f "$cmd" ]; then
            ln -sfn "$cmd" "$dir/$(basename "$cmd")"
            log "command: $(basename "$cmd" .md)"
            count=$((count + 1))
        fi
    done
    echo "  ✓ commands: $count linked into $dir/ ($label)"
}

register_claude_hooks() {
    local settings="$HOME/.claude/settings.json"
    local start_hook="$HOME/.claude/skills/llm-wiki/hooks/session-start.sh"
    local stop_hook="$HOME/.claude/skills/llm-wiki/hooks/session-stop.sh"

    if [ -f "$settings" ] && grep -q "skills/llm-wiki/hooks/session-start.sh" "$settings"; then
        echo "  ✓ hooks: already registered in $settings"
    elif [ ! -f "$settings" ]; then
        cat > "$settings" << SETEOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$start_hook" }]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$stop_hook" }]
      }
    ]
  }
}
SETEOF
        echo "  ✓ hooks: created $settings"
    elif command -v jq >/dev/null 2>&1; then
        jq --arg start "$start_hook" --arg stop "$stop_hook" '
            .hooks.SessionStart = ((.hooks.SessionStart // []) +
                [{"matcher": "", "hooks": [{"type": "command", "command": $start}]}]) |
            .hooks.SessionEnd = ((.hooks.SessionEnd // []) +
                [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}])
        ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
        echo "  ✓ hooks: merged into $settings"
    else
        echo "  ⚠ jq not found — add the hooks to $settings manually:"
        echo "    SessionStart → $start_hook"
        echo "    SessionEnd   → $stop_hook"
    fi
}

# ── 1. Shared skill (agentskills.io layout, read by every harness) ───────────

mkdir -p "$SHARED_SKILLS_DIR"
SHARED_SKILL_DST="$SHARED_SKILLS_DIR/llm-wiki"
if [ -e "$SHARED_SKILL_DST" ] && [ ! -L "$SHARED_SKILL_DST" ]; then
    log "Replacing existing copy-installed skill at $SHARED_SKILL_DST"
    rm -rf "$SHARED_SKILL_DST"
fi
ln -sfn "$SKILL_SRC" "$SHARED_SKILL_DST"
echo "  ✓ skill: $SHARED_SKILL_DST → $SKILL_SRC"

# ── 2. Per-harness wiring ────────────────────────────────────────────────────

for h in $HARNESSES; do
    echo ""
    echo "Wiring $h..."
    case "$h" in
        claude-code)
            link_skill_into "$HOME/.claude/skills"
            link_manual_to "$HOME/.claude/CLAUDE.md"
            link_commands_into "$HOME/.claude/commands" "/wiki-*"
            register_claude_hooks
            ;;
        codex)
            CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
            link_manual_to "$CODEX_DIR/AGENTS.md"
            link_commands_into "$CODEX_DIR/prompts" "/prompts:wiki-*"
            echo "  ℹ no session hooks on codex — AGENT.md Rule 0a runs the start script instead"
            ;;
        pi)
            link_skill_into "$HOME/.pi/agent/skills"
            link_manual_to "$HOME/.pi/agent/AGENTS.md"
            link_commands_into "$HOME/.pi/agent/prompts" "/wiki-*"
            echo "  ℹ no session hooks on pi — AGENT.md Rule 0a runs the start script instead"
            ;;
        bob)
            # Bob 2.0's loader names ~/.claude/skills as its global skill
            # directory; ~/.bob/skills is linked too for Bob builds that scan it.
            link_skill_into "$HOME/.claude/skills"
            link_skill_into "$HOME/.bob/skills"
            link_manual_to "$HOME/.bob/rules/llm-wiki.md"
            echo "  ℹ bob has no slash-command files — the manual maps /wiki-* to workflows"
            echo "  ℹ no session hooks on bob — AGENT.md Rule 0a runs the start script instead"
            ;;
    esac
done

# ── 3. Permissions + sentinel ────────────────────────────────────────────────

chmod +x "$SKILL_SRC/scripts/"*.sh 2>/dev/null || true
chmod +x "$SKILL_SRC/hooks/"*.sh 2>/dev/null || true

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$SENTINEL"
echo ""
echo "  ✓ sentinel: $SENTINEL"

# ── Verify ───────────────────────────────────────────────────────────────────

ALL_OK=true
[ -L "$SHARED_SKILL_DST" ] || { echo "  ✗ shared skill symlink missing" >&2; ALL_OK=false; }
[ -f "$SENTINEL" ] || { echo "  ✗ sentinel missing" >&2; ALL_OK=false; }
for h in $HARNESSES; do
    case "$h" in
        claude-code) manual="$HOME/.claude/CLAUDE.md" ;;
        codex)       manual="${CODEX_HOME:-$HOME/.codex}/AGENTS.md" ;;
        pi)          manual="$HOME/.pi/agent/AGENTS.md" ;;
        bob)         manual="$HOME/.bob/rules/llm-wiki.md" ;;
    esac
    [ -L "$manual" ] || { echo "  ✗ $h manual symlink missing ($manual)" >&2; ALL_OK=false; }
done

if [ "$ALL_OK" != true ]; then
    echo ""
    echo "Installation incomplete — see errors above." >&2
    exit 1
fi

echo ""
echo "LLM Wiki agent installed for: $HARNESSES"
echo "Onboarding runs at the next session start (or on demand with /wiki-onboard)."
echo "Update the agent: git -C \"$REPO_ROOT\" pull --ff-only"
