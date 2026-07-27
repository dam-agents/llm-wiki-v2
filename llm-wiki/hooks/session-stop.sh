#!/bin/bash
# session-stop.sh — SessionStop hook for LLM Wiki
# Writes hot-cache template for the next session.
# Claude should fill in activity details during the session via /wiki operations.
#
# Configured as a SessionStop hook in settings.json.

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/_utils.sh"

WIKI_ROOT=$(find_wiki_root)
[ -z "$WIKI_ROOT" ] && exit 0

HOT_CACHE="$WIKI_ROOT/.llm-wiki/cache/hot-cache.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$HOT_CACHE" << HOTEOF
# Hot Cache
**Last session:** $NOW

## Recent Activity
<!-- Populated during session by /wiki operations -->

## Pages Read
<!-- Pages consulted during queries -->

## Pages Written
<!-- Pages created or updated -->

## Queries Asked
<!-- Queries asked via /wiki-query -->

## Pending
<!-- Items needing follow-up next session -->

## Notes
<!-- Free-form notes -->
HOTEOF

echo "Hot cache written to $HOT_CACHE"
