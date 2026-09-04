---
description: Generate an interactive D3.js knowledge graph visualization of the wiki
---

# Generate Knowledge Graph

The user ran `/wiki-graph $ARGUMENTS`.

## Procedure

Use the skill (`Skill("llm-wiki")` on Claude Code; otherwise read `SKILL.md` in the skill directory) → `workflows/graph.md` for the full procedure:

1. Read all wiki pages and extract wikilinks
2. Build nodes (pages) and edges (links between pages)
3. Write `./wiki/.llm-wiki/graph.json`
4. Generate a self-contained interactive D3.js HTML visualization
5. Publish it as an artifact automatically and give the user the link
