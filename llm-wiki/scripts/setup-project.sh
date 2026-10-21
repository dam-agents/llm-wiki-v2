#!/bin/bash
# setup-project.sh — Set up LLM Wiki in a project directory
# Usage: setup-project.sh [wiki-path] [--with-hooks]
#   wiki-path     Path to create wiki at (default: ./wiki)
#   --with-hooks  Also configure SessionStart hook in settings
# Exit: 0 on success, 1 on error

set -euo pipefail

# shellcheck source=./_utils.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_utils.sh"

WITH_HOOKS=false
WIKI_PATH=""

for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: setup-project.sh [wiki-path] [--with-hooks]"
            echo ""
            echo "Set up LLM Wiki in your project:"
            echo "  1. Bootstraps the wiki directory with init-wiki.sh"
            echo "  2. Creates or updates CLAUDE.md with wiki instructions"
            echo "  3. Creates .raw/ directory for source documents"
            echo ""
            echo "Options:"
            echo "  wiki-path      Path for the wiki (default: ./wiki)"
            echo "  --with-hooks   Configure SessionStart hook in .claude/settings.local.json"
            echo "  --help, -h     Show this help"
            exit 0 ;;
        --with-hooks) WITH_HOOKS=true ;;
        *)
            if [ -z "$WIKI_PATH" ]; then
                WIKI_PATH="$arg"
            else
                echo "Unknown option: $arg (use --help for usage)" >&2; exit 1
            fi ;;
    esac
done

# Default wiki path
WIKI_PATH="${WIKI_PATH:-./wiki}"

# Resolve skill directory
SKILL_DIR="$HOME/.claude/skills/llm-wiki"
if [ ! -d "$SKILL_DIR" ]; then
    echo "ERROR: LLM Wiki skill not installed." >&2
    echo "Run install.sh first: cd llm-wiki && ./install.sh" >&2
    exit 1
fi

echo "=== LLM Wiki Project Setup ==="
echo ""

# Step 1: Initialize wiki directory
echo "1. Initializing wiki at $WIKI_PATH..."
if [ -d "$WIKI_PATH/.llm-wiki" ]; then
    echo "   ✓ Wiki already exists at $WIKI_PATH"
else
    "$SKILL_DIR/scripts/init-wiki.sh" "$WIKI_PATH"
    echo "   ✓ Wiki initialized"
fi

# Step 2: Create .raw/ directory
if [ ! -d "./.raw" ]; then
    mkdir -p ./.raw
    echo "   ✓ Created ./.raw/ for source documents"
fi

# Step 3: Create/update CLAUDE.md
echo ""
echo "2. Setting up CLAUDE.md..."

CLAUDE_MD="./CLAUDE.md"
WIKI_MD="$SKILL_DIR/WIKI.md"

if [ -f "$CLAUDE_MD" ]; then
    # If CLAUDE.md exists, check if it already has wiki instructions
    if grep -q "LLM Wiki" "$CLAUDE_MD" 2>/dev/null; then
        echo "   ✓ CLAUDE.md already has wiki instructions"
    else
        # Prepend wiki instructions to existing CLAUDE.md
        echo "   → CLAUDE.md exists, prepending wiki instructions..."
        # Private temp beside CLAUDE.md: atomic rename, keeps its mode, and no
        # fixed name for a concurrent writer to collide with. `trap` covers a
        # failure while generating (e.g. WIKI.md unreadable under set -e).
        if ! tmp_md="$(new_temp_beside "$CLAUDE_MD")"; then
            echo "   ⚠ cannot write beside $CLAUDE_MD — leaving it unchanged"
            tmp_md=""
        else
            trap 'rm -f "$tmp_md"' EXIT
            # Check every read explicitly: errexit is off inside a conditional
            # context, so a failed cat would otherwise still publish a partial
            # CLAUDE.md. Any generation failure means no publish.
            md_ok=true
            {
                echo "<!-- LLM Wiki instructions added by setup-project.sh -->"
                echo ""
                cat "$WIKI_MD" || md_ok=false
                echo ""
                echo "---"
                echo ""
                cat "$CLAUDE_MD" || md_ok=false
            } > "$tmp_md" || md_ok=false
            if [ "$md_ok" = true ] && publish_temp "$tmp_md" "$CLAUDE_MD"; then
                echo "   ✓ Wiki instructions prepended to CLAUDE.md"
            else
                echo "   ⚠ could not update CLAUDE.md — leaving it unchanged"
            fi
            trap - EXIT
            rm -f "$tmp_md"
        fi
    fi
else
    cp "$WIKI_MD" "$CLAUDE_MD"
    echo "   ✓ Created CLAUDE.md with wiki instructions"
fi

# Step 4: Optionally configure hooks
if [ "$WITH_HOOKS" = true ]; then
    echo ""
    echo "3. Configuring SessionStart hook..."

    SETTINGS_FILE=".claude/settings.local.json"

    if [ -f "$SETTINGS_FILE" ]; then
        # Update existing settings with jq
        if command -v jq >/dev/null 2>&1; then
            if ! tmp_settings="$(new_temp_beside "$SETTINGS_FILE")"; then
                echo "   ⚠ cannot write beside $SETTINGS_FILE — add the hook manually:"
                echo "     \"command\": \"$SKILL_DIR/hooks/session-start.sh\""
                tmp_settings=""
            else
                trap 'rm -f "$tmp_settings"' EXIT
                if jq --arg cmd "$SKILL_DIR/hooks/session-start.sh" \
                   '.hooks.SessionStart = [{"matcher": "", "command": $cmd}]' \
                   "$SETTINGS_FILE" > "$tmp_settings" \
                   && publish_temp "$tmp_settings" "$SETTINGS_FILE" \
                   && grep -q "session-start.sh" "$SETTINGS_FILE"; then
                    echo "   ✓ SessionStart hook configured in $SETTINGS_FILE"
                else
                    echo "   ⚠ Could not update $SETTINGS_FILE — add the hook manually:"
                    echo "     \"command\": \"$SKILL_DIR/hooks/session-start.sh\""
                fi
                trap - EXIT
                rm -f "$tmp_settings"
            fi
        else
            echo "   ⚠ jq not found. Install jq or add the hook manually:"
            echo "     See: https://claude.com/claude-code for hook configuration"
        fi
    else
        # Create new settings file. Same private-temp + atomic publish as the
        # merge branch: a concurrent writer must not see a truncated file.
        if ! tmp_settings="$(new_temp_beside "$SETTINGS_FILE")"; then
            echo "   ⚠ cannot create $SETTINGS_FILE — add the hook manually:"
            echo "     \"command\": \"$SKILL_DIR/hooks/session-start.sh\""
            tmp_settings=""
        else
            trap 'rm -f "$tmp_settings"' EXIT
            if cat > "$tmp_settings" << SETEOF && publish_temp "$tmp_settings" "$SETTINGS_FILE" \
                && grep -q "session-start.sh" "$SETTINGS_FILE"
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "command": "$SKILL_DIR/hooks/session-start.sh"
      }
    ]
  }
}
SETEOF
            then
                echo "   ✓ Created $SETTINGS_FILE with SessionStart hook"
            else
                echo "   ⚠ could not create $SETTINGS_FILE — add the hook manually:"
                echo "     \"command\": \"$SKILL_DIR/hooks/session-start.sh\""
            fi
            trap - EXIT
            rm -f "$tmp_settings"
        fi
    fi
else
    echo ""
    echo "3. (Optional) Configure SessionStart hook for richer startup context:"
    echo "   Re-run with --with-hooks, or add to .claude/settings.local.json:"
    echo ""
    echo '   {'
    echo '     "hooks": {'
    echo '       "SessionStart": [{'
    echo "         \"command\": \"$SKILL_DIR/hooks/session-start.sh\""
    echo '       }]'
    echo '     }'
    echo '   }'
fi

# Step 5: Add CLAUDE.md to .gitignore if not already there
GITIGNORE="./.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "^CLAUDE.md$" "$GITIGNORE" 2>/dev/null; then
        {
            echo ""
            echo "# LLM Wiki — CLAUDE.md is generated by setup-project.sh"
            echo "CLAUDE.md"
        } >> "$GITIGNORE"
        echo "   ✓ Added CLAUDE.md to .gitignore"
    fi
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Wiki is ready at: $WIKI_PATH"
echo "Drop source documents in ./.raw/ then use:"
echo "  /wiki-ingest .raw/your-file.md"
echo ""
echo "Ask questions naturally — Claude will check the wiki first!"
