---
description: One-time onboarding interview — create and configure the wiki
---

# Onboard the Wiki

The user ran `/wiki-onboard` (or the session-start hook requested onboarding
because `./wiki/.llm-wiki/onboarded` is missing).

## Procedure

### 1. Guard

If `./wiki/.llm-wiki/onboarded` exists, onboarding is done — show the
`/wiki` dashboard instead.

### 2. Interview

Greet the user and ask (conversationally, not as a form): wiki name,
and purpose/topics. Nothing technical.

### 3. Set up

- Run `scripts/init-wiki.sh ./wiki` from the skill directory (`~/.agents/skills/llm-wiki/`, or `~/.claude/skills/llm-wiki/` for a copy install)
- Write the answers into `./wiki/.llm-wiki/config.md` (in agent mode, set
  `require_review: false`)
- Offer: git remote for the wiki, a maintenance schedule, first sources (or
  the bundled demo)
- Write `./wiki/USAGE_GUIDE.md` (skill workflow `workflows/ingest.md` Step 14b)
- Write the `./wiki/.llm-wiki/onboarded` sentinel

### Full workflow

Use the skill (`Skill("llm-wiki")` on Claude Code; otherwise read `SKILL.md` in the skill directory) → `workflows/onboard.md` for the complete procedure.
