---
description: Health check for the wiki — structural (quick) or semantic (full)
argument-hint: [--quick|--full]
---

# Wiki Health Check

The user ran `/wiki-lint $ARGUMENTS`. Default mode: `--quick`.

## Quick Mode (bash scripts, zero LLM cost)

Run these scripts from the skill directory's `scripts/` (`~/.agents/skills/llm-wiki/scripts/`, or `~/.claude/skills/llm-wiki/scripts/` for a copy install):

- `validate-frontmatter.sh` — Required field validation
- `find-broken-links.sh` — Dead wikilink detection
- `find-orphans.sh` — Pages with no incoming links
- `check-stale.sh` — Index freshness

Then check the usage guide (`workflows/lint.md` step Q6).

## Full Mode (LLM semantic analysis)

Use the skill (`Skill("llm-wiki")` on Claude Code; otherwise read `SKILL.md` in the skill directory) → `workflows/lint.md` for:

- Contradiction detection between pages
- Content quality assessment
- Language consistency check
- Staleness / drift detection
- Knowledge gap analysis
