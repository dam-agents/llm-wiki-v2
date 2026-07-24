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
language (`en`/`zh`/`bilingual`), and purpose/topics. Nothing technical.

### 3. Set up

- Run `~/.claude/skills/llm-wiki/scripts/init-wiki.sh ./wiki`
- Write the answers into `./wiki/.llm-wiki/config.md` (in agent mode, set
  `require_review: false`)
- Offer: git remote for the wiki, a maintenance schedule, first sources (or
  the bundled demo)
- Write the `./wiki/.llm-wiki/onboarded` sentinel

### Full workflow

Use `Skill("llm-wiki")` → `workflows/onboard.md` for the complete procedure.
