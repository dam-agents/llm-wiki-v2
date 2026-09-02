#!/bin/bash
# session-start.sh — SessionStart hook for LLM Wiki
# Outputs wiki context and PROACTIVE WIKI RULE for Claude.
#
# Configured as a SessionStart hook in settings.json (via setup-project.sh --with-hooks).
# The output of this script becomes part of Claude's session context.

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/_utils.sh"

WIKI_ROOT=$(find_wiki_root)
AGENT_SENTINEL="$HOME/.llm-wiki-installed"

# Agent mode (agent-install.sh ran on this machine): gate on onboarding.
# Install is per-machine, onboarding is per-wiki — see workflows/onboard.md.
if [ -f "$AGENT_SENTINEL" ]; then
    if [ -z "$WIKI_ROOT" ] || [ ! -f "$WIKI_ROOT/.llm-wiki/onboarded" ]; then
        cat << 'ONBOARD'
---
## LLM Wiki — Onboarding Required

This machine is the LLM Wiki agent, but the wiki has not been created yet.

**Do this FIRST, before handling any other request:** run the onboarding
interview — `/wiki-onboard` (skill workflow `workflows/onboard.md`). Greet
the user, explain this is a one-time setup, and guide them through it.
---
ONBOARD
        exit 0
    fi
fi

[ -z "$WIKI_ROOT" ] && exit 0

HOT_CACHE="$WIKI_ROOT/.llm-wiki/cache/hot-cache.md"
INDEX="$WIKI_ROOT/.llm-wiki/index.md"
STATE_HASH_FILE="$WIKI_ROOT/.llm-wiki/cache/state-hash.txt"
REVIEW_JSON="$WIKI_ROOT/.llm-wiki/review.json"

# Compute current state hash from all wiki pages. index.md and USAGE_GUIDE.md
# are derived — hashing them would report a refresh as an external change.
CURRENT_HASH=$(find "$WIKI_ROOT" -maxdepth 1 -name "*.md" \
    ! -name "index.md" ! -name "USAGE_GUIDE.md" \
    -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1)

cat << HEADER
---
## LLM Wiki — Session Context
**Wiki root:** $WIKI_ROOT
**Skill:** Use \`Skill("llm-wiki")\` to load full wiki capabilities
---

HEADER

# === PROACTIVE WIKI RULE (most important) ===
cat << RULES
### PROACTIVE WIKI RULE — ALWAYS FOLLOW THIS

1. **Check the wiki before answering** — When the user asks any factual, conceptual, or knowledge-based question, FIRST read \`$WIKI_ROOT/.llm-wiki/index.md\` to check if the wiki has relevant information. Do NOT answer from your training data without checking the wiki.

2. **How to use the wiki**:
   - Read the index to find relevant pages (by tags, titles, summaries)
   - Read 3-5 most relevant pages
   - Synthesize answer with citations: \`[[page-slug]]\`
   - Report confidence, contradictions, and knowledge gaps

3. **When the wiki lacks knowledge**: Tell the user what's missing and suggest sources to ingest. Use \`/wiki-ingest\` to add knowledge.

RULES

# Compare with stored hash
if [ -f "$STATE_HASH_FILE" ]; then
    STORED_HASH=$(cat "$STATE_HASH_FILE")
    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "⚠️  **Wiki state has changed** since last session. Run /wiki-lint to check health."
        echo ""
    fi
fi
echo "$CURRENT_HASH" > "$STATE_HASH_FILE"

# Quick stats from index
if [ -f "$INDEX" ]; then
    PAGE_COUNT=$(grep -c '^| \[' "$INDEX" 2>/dev/null || echo "0")
    LAST_GEN=$(grep "Last generated" "$INDEX" 2>/dev/null | sed 's/.*\*\*//;s/\*\*//' || echo "unknown")
    echo "**Wiki pages:** $PAGE_COUNT | **Index:** $LAST_GEN"
    echo ""

    # Tag cloud
    TAGS=$(grep '^### ' "$INDEX" 2>/dev/null | sed 's/^### //' | sed 's/ ([0-9]* pages)//' || true)
    if [ -n "$TAGS" ]; then
        echo "### Available Topics"
        echo "$TAGS" | while read -r tag; do
            echo "- \`$tag\`"
        done
        echo ""
    fi
else
    echo "**Wiki:** Empty — ingest some sources first!"
    echo ""
fi

# Pending reviews
if [ -f "$REVIEW_JSON" ]; then
    PENDING=$(jq '.pending | length' "$REVIEW_JSON" 2>/dev/null || echo "0")

    if [ "$PENDING" -gt 0 ]; then
        echo "🔔 **$PENDING pending review(s)** — run /wiki-review to process"
        echo ""
    fi
fi

# Un-ingested sources in .raw/ (hash has no .done sentinel yet).
# A fresh .lock directory (< 60 min) means another session is ingesting the
# source right now — list it as in-progress, never as awaiting ingestion.
RAW_DIR="./.raw"
if [ -d "$RAW_DIR" ]; then
    NEW_SOURCES=""
    IN_PROGRESS=""
    for f in "$RAW_DIR"/*; do
        [ -f "$f" ] || continue
        HASH=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
        [ -z "$HASH" ] && continue
        [ -f "$WIKI_ROOT/.llm-wiki/cache/ingests/$HASH.done" ] && continue
        LOCK="$WIKI_ROOT/.llm-wiki/cache/ingests/$HASH.lock"
        if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin -60 2>/dev/null)" ]; then
            IN_PROGRESS="$IN_PROGRESS- \`$f\` (locked since $(cat "$LOCK/started" 2>/dev/null || echo unknown))
"
            continue
        fi
        NEW_SOURCES="$NEW_SOURCES- \`$f\`
"
    done
    if [ -n "$NEW_SOURCES" ]; then
        echo "### New Sources Awaiting Ingestion"
        printf '%s' "$NEW_SOURCES"
        if [ -f "$AGENT_SENTINEL" ]; then
            echo ""
            echo "Ingest these now, silently, per the silent-ingestion policy: run the ingest workflow for each (acquire the per-source lock first — workflow Step 2b) and report one summary line."
        else
            echo ""
            echo "Run /wiki-ingest <file> to add them to the wiki."
        fi
        echo ""
    fi
    if [ -n "$IN_PROGRESS" ]; then
        echo "### Sources Being Ingested by Another Session"
        printf '%s' "$IN_PROGRESS"
        echo ""
        echo "Do NOT ingest these — another session holds the lock. They will finish (sentinel appears) or the lock goes stale after 60 minutes."
        echo ""
    fi
fi

# Hot cache from previous session
if [ -f "$HOT_CACHE" ]; then
    echo "### Context from Previous Session"
    cat "$HOT_CACHE"
    echo ""
fi

# Reminder
cat << REMINDER
---
**Commands:** /wiki, /wiki-ingest, /wiki-query, /wiki-lint, /wiki-save, /wiki-graph, /wiki-review
**Skill:** Use \`Skill("llm-wiki")\` for advanced wiki operations
REMINDER
