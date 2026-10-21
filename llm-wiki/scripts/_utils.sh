#!/bin/bash
# _utils.sh — Shared utility functions for LLM Wiki scripts
# Source this file from other scripts to avoid duplicating common functions.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/_utils.sh"

# find_wiki_root — Locate the wiki directory
# Checks LLM_WIKI_ROOT env var first, then ./wiki as fallback.
# Returns the wiki root path, or empty string if not found.
find_wiki_root() {
    if [ -n "${LLM_WIKI_ROOT:-}" ] && [ -d "$LLM_WIKI_ROOT/.llm-wiki" ]; then
        echo "$LLM_WIKI_ROOT"
    elif [ -d "./wiki/.llm-wiki" ]; then
        echo "./wiki"
    else
        echo ""
    fi
}
# resolve_target — Where a write to $1 must land, following symlinks (dangling
# ones included). Writing through the link instead of renaming over it keeps a
# managed settings symlink alive.
resolve_target() {
    local p="$1" d l
    while [ -L "$p" ]; do
        d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || break
        l="$(readlink "$p")"
        case "$l" in
            /*) p="$l" ;;
            *)  p="$d/$l" ;;
        esac
    done
    echo "$p"
}

# file_mode — Permission bits of $1 in octal. GNU stat first: BSD stat -c fails
# outright, while GNU stat -f means filesystem status and would succeed with
# the wrong output.
file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

# new_temp_beside — mktemp a file in the directory a write to $1 will land in,
# so the final rename stays on one filesystem. A fixed temp name would collide
# with a harness image that syncs the same file under its own fixed name.
new_temp_beside() {
    local target
    target="$(resolve_target "$1")" || return 1
    mkdir -p "$(dirname "$target")" || return 1
    mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX"
}

# publish_temp — Atomically rename $1 over $2, keeping $2's permissions. A new
# file keeps mktemp's 0600. Removes $1 on failure.
publish_temp() {
    local tmp="$1" target mode
    target="$(resolve_target "$2")" || { rm -f "$tmp"; return 1; }
    if [ -f "$target" ] && mode="$(file_mode "$target")" \
        && case "$mode" in ''|*[!0-7]*) false ;; *) true ;; esac; then
        chmod "$mode" "$tmp" || true
    fi
    mv -f "$tmp" "$target" || { rm -f "$tmp"; return 1; }
}
