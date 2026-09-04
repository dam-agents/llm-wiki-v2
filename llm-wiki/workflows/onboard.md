# /wiki-onboard — First-Run Onboarding Interview

**Purpose**: Create and configure the wiki through a short guided interview.
Runs once per wiki; the session-start hook triggers it automatically (in
agent mode) whenever `./wiki/.llm-wiki/onboarded` is missing.

**Invoked by**: `/wiki-onboard` → SKILL.md routes here, or the session-start
hook's onboarding instruction.

---

## Design Rationale

`★ Insight ─────────────────────────────────────`

- Install is per-machine, onboarding is per-wiki. The completion sentinel
  lives *inside* the wiki (`.llm-wiki/onboarded`), so a wiki restored from a
  git remote onto a fresh machine skips onboarding entirely.
- The interview collects intent (name, purpose), not mechanics.
  All technical decisions — page types, review flow, index format — are the
  agent's job, per the silent-operation policy in `AGENT.md`.
`─────────────────────────────────────────────────`

---

## Step 0: Guard

Check for the sentinel:

```bash
test -f ./wiki/.llm-wiki/onboarded
```

If it exists, onboarding is already done — say so, show the `/wiki`
dashboard instead, and stop.

## Step 1: Interview

Greet the user, explain this is a one-time setup (under a minute), and ask —
conversationally, in one message, not as a form:

1. **Wiki name** — what should this knowledge base be called?
2. **Purpose / topics** — what knowledge will live here? One or two
   sentences is enough; this steers ingestion and tagging.

The wiki is always English-only — do not ask about language.

Do not ask about anything technical (review checkpoints, page types,
directory layout). Sensible defaults are applied in Step 3.

## Step 2: Initialize the Wiki

Create the intake directory and initialize the wiki, both in the working
directory (the operational space — never in `~/.llm-wiki-agent`):

```bash
mkdir -p ./.raw
~/.agents/skills/llm-wiki/scripts/init-wiki.sh ./wiki
```

(`~/.agents/skills/llm-wiki` is the agent-mode skill directory on every
harness; a copy install lives at `~/.claude/skills/llm-wiki`. If neither
exists, resolve `scripts/` relative to this workflow file.)

## Step 3: Write Configuration

Edit `./wiki/.llm-wiki/config.md`:

- `wiki_name`: the user's answer
- `language`: `en` (always — the wiki is English-only)
- Add a `## Purpose` line under Wiki Settings with the stated purpose/topics
- **Agent mode** (i.e. `$HOME/.llm-wiki-installed` exists): set
  `require_review: false` — ingestion must not pause for approval, per the
  silent-ingestion policy. Otherwise leave `require_review: true`.

## Step 4: Wiki Git Repository (optional remote)

Make the wiki content survive machine loss:

```bash
git -C ./wiki init -b main 2>/dev/null || true
git -C ./wiki add -A && git -C ./wiki commit -m "Initialize wiki" || true
```

Then ask the user: "Do you want the wiki backed up to a git remote? If you
have a repo URL, I'll wire it up — otherwise we can skip this."

- If they give a URL: `git -C ./wiki remote add origin <url>` and push
  (`git -C ./wiki push -u origin main`). Report failures plainly and move
  on — a missing remote must not block onboarding.
- If they decline: skip, no follow-up questions.

The wiki repo is independent of the agent-definition repo (which gitignores
`wiki/`). Never push wiki content to the definition repo.

## Step 5: Maintenance Schedule (optional)

Ask for a cadence: "Want me to run periodic maintenance (health checks and
ingestion sweeps)? Daily, weekly, or skip?"

If the user picks a cadence, use whatever scheduler the harness provides, in
this order of preference:

1. A platform scheduling tool (e.g. an MCP `create_schedule` tool), if
   available in this session
2. Claude Code's built-in scheduling (the `schedule` skill / cron routines),
   if available
3. Otherwise: note in the closing message that no scheduler is available and
   maintenance will happen at session start instead

The scheduled task should: run `/wiki-lint --quick`, ingest any new files in
`./.raw/`, and process trivial review-queue items.

## Step 6: First Sources (optional)

Ask: "Do you have documents to start with? Drop files in `./.raw/`, give me
paths or URLs — or I can load the bundled Greek-mythology demo so you can
try it out."

- If sources are provided (or already sitting un-ingested in `./.raw/`):
  ingest them now, silently, per the ingest workflow — one summary line per
  source.
- If the user picks the demo: copy the bundled demo sources out of the
  agent definition into the workspace, then ingest them —
  `cp ~/.llm-wiki-agent/.raw/greek-olympians.md ~/.llm-wiki-agent/.raw/perseus-medusa.md ./.raw/`
  — ingest `.raw/greek-olympians.md` first, offer `.raw/perseus-medusa.md`
  as a follow-up.
- If they have nothing yet: fine — tell them the wiki fills up whenever they
  hand you documents.

## Step 7: Write the Usage Guide

Write `./wiki/USAGE_GUIDE.md` (procedure: `workflows/ingest.md` Step 14b),
from the name and purpose collected in Step 1 and whatever Step 6 ingested.
Part of setup — do not announce it separately.

## Step 8: Write the Sentinel

```bash
{
  echo "onboarded: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "wiki_name: <the chosen name>"
} > ./wiki/.llm-wiki/onboarded
```

If the wiki is git-backed (Step 4), commit the sentinel, the config, and the
usage guide too.

## Step 9: Close

One short closing message:

- Confirm the wiki is ready, using its name.
- If sources were ingested, one line on what the wiki now knows.
- Offer 1–2 concrete next actions grounded in current state (e.g. "ask me
  anything about X", "drop more files in `.raw/`", `/wiki-graph` if several
  pages exist) — not a full command list.
