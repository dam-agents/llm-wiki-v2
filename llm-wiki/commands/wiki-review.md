---
description: Walk through the review queue — contradictions, stale pages, knowledge gaps
---

# Process Review Queue

The user ran `/wiki-review $ARGUMENTS`.

## Procedure

Use the skill (`Skill("llm-wiki")` on Claude Code; otherwise read `SKILL.md` in the skill directory) → `workflows/review.md` for the full procedure:

1. Read `./wiki/.llm-wiki/review.json` for pending items
2. For each item, present the issue and relevant pages
3. Let the user decide: resolve, defer, or escalate
4. Update `review.json` accordingly
5. If changes were made, regenerate the index and refresh `./wiki/USAGE_GUIDE.md`
