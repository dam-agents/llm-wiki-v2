# /wiki-graph — Knowledge Graph Visualization

**Purpose**: Generate an interactive D3.js force-directed graph showing the wiki's page network.

**Invoked by**: `/wiki-graph` → SKILL.md routes here

---

## Procedure

### Step 1: Extract Graph Data

List all pages and extract node/edge data:

```bash
find "$WIKI_ROOT" -maxdepth 1 -name "*.md" ! -path "*/.llm-wiki/*" ! -name "index.md"
```

Build structure:

```json
{
  "nodes": [{"id": "slug", "title": "Display Title", "type": "concept|article|person|synthesis", "language": "en|zh|bilingual", "tags": ["tag1"], "incomingLinks": N, "outgoingLinks": N}],
  "edges": [{"source": "page-a", "target": "page-b"}]
}
```

### Step 2: Compute Derived Metrics

- `incomingLinks`, `outgoingLinks`, `isOrphan`, `isHub` (outgoingLinks > 5), `centrality`

### Step 3: Write graph.json

Write to `$WIKI_ROOT/.llm-wiki/graph.json`.

### Step 4: Generate graph.html

Create a **fully self-contained** HTML file at `$WIKI_ROOT/.llm-wiki/graph.html`:

- Dark-themed D3.js v7 force-directed graph
- Color-coded nodes: concept=#5b9bd5, article=#ed7d31, person=#70ad47, synthesis=#ffc000
- Node radius: `5 + min(incomingLinks, 15)` px
- Tooltips on hover: title, type, language, link counts, tags
- Draggable nodes, zoom/pan on SVG
- Legend for type colors
- Graph data embedded as an inline JavaScript variable

⚠️ **No external fetches.** Do not `<script src="d3js.org/...">` — sandboxed
viewers block external scripts, leaving a blank canvas. Inline D3 into a
`<script>` block: `curl -s https://d3js.org/d3.v7.min.js` and paste the
contents in. All CSS/JS/data must live in the single file.

⚠️ **Declaration order (TDZ).** Any helper a force accessor calls must be
declared *above* the simulation. Put `const radius = d => ...` before the
`d3.forceSimulation(...).force("collide", d3.forceCollide().radius(d => radius(d) + 6))`
block — `const` is not hoisted, so a forward reference throws "Cannot access
'radius' before initialization" and blanks the graph.

### Step 5: Publish + Present

**Publish `graph.html` as an artifact automatically** — do not ask first, and
do not just hand over a local file path (the environment is headless; the user
cannot open it). Use the artifact-publishing MCP tool available in this
environment, then give the user the returned link.

- Declare it as **HTML explicitly**: pass an HTML type and, if the tool uploads
  via a presigned PUT, set `Content-Type: text/html`. With no content type the
  upload is mis-registered as `application/x-www-form-urlencoded` and the share
  page won't render.
- Re-publishing an updated graph should reuse the same artifact where the tool
  supports it, so the user's link stays stable.

Then present:

```
# Knowledge Graph
**Nodes:** {N} | **Edges:** {N} | **Orphans:** {N} | **Hubs:** {N}
Graph: <artifact link> | Data: wiki/.llm-wiki/graph.json
```

**Fallback** (no artifact tool available): report the file path
`wiki/.llm-wiki/graph.html`, and on a local desktop offer `xdg-open` / `open`.

---

## Edge Cases

- **Empty wiki**: "No pages to graph. Ingest sources first."
- **Single page**: Generate single-node graph; suggest adding more pages
- **>50 pages**: Offer tag filtering; warn about simulation performance
- **Stale graph.json**: Always regenerate from live data, never reuse
