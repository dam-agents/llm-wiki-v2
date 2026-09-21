# Onboarding

The platform opens this agent's first session on this file. It is the
`/wiki-onboard` interview — the same one the toolkit keeps as a command for a
re-run — with the platform's onboarding checklist around it. The complete
procedure, with every path and file it writes, is
`llm-wiki/workflows/onboard.md` in this checkout, installed at
`~/.llm-wiki-agent/llm-wiki/workflows/onboard.md`. Follow it; this file says
what to ask the user, and what counts as finished.

`bash bootstrap.sh` has already run, so the tooling is in `~/.llm-wiki-agent`
and wired into your harness. Nothing here installs anything.

## 0. The checklist

What to report as the onboarding checklist, before you ask the user anything:

| id | label |
| --- | --- |
| `name` | Name the wiki |
| `purpose` | Say what knowledge it will hold |
| `sources` | Hand over the first documents |
| `backup` | Decide whether the wiki gets a git remote |
| `schedule` | Decide on a maintenance cadence |

A decision to skip is an answer, so `backup` and `schedule` are done on a "no"
too.

## 1. Guard

If `./wiki/.llm-wiki/onboarded` exists, onboarding is already done: say so, show
the `/wiki` dashboard, and stop.

## 2. Interview

Greet the user, explain this is a one-time setup that takes under a minute, and
ask in one message, conversationally rather than as a form:

1. **Wiki name** — what should this knowledge base be called?
2. **Purpose / topics** — what knowledge will live here? One or two sentences;
   it steers ingestion and tagging.

Nothing technical — no page types, review checkpoints or directory layout. The
wiki is English-only, so do not ask about language.

## 3. Initialize and configure

Create `./.raw`, run `init-wiki.sh ./wiki` from the skill directory, and write
the answers into `./wiki/.llm-wiki/config.md` — `wiki_name`, `language: en`, a
`## Purpose` line, and `require_review: false` in agent mode. Silently.

## 4. Wiki git remote (optional)

Initialize `./wiki` as its own git repository and commit, then ask whether the
wiki should be backed up to a remote. On a URL, wire it up and push, reporting
a failure plainly and moving on; on a no, skip without follow-up questions. The
wiki repository is never pushed to the agent's own definition repository.

## 5. Maintenance cadence (optional)

Ask for a cadence — daily, weekly, or skip. If they pick one, create it with
the platform's `create_schedule` tool; a schedule created now is held until
onboarding is complete, which is the point. Fall back to the harness's own
scheduler, and if there is none, say so in the closing message and rely on
session start.

## 6. First sources

Ask for documents: files in `./.raw/`, paths, URLs — or the bundled
Greek-mythology demo. Ingest what arrives, silently, one summary line per
source. If they have nothing yet, say the wiki fills up whenever they hand you
documents.

## 7. Usage guide, sentinel, close

Write `./wiki/USAGE_GUIDE.md`, write the `./wiki/.llm-wiki/onboarded` sentinel,
and commit both with the config if the wiki is git-backed. Then one short
closing message: the wiki is ready, by name; a line on what it now knows if
anything was ingested; one or two concrete next actions.

## 8. Release the agent

Onboarding is finished once the sentinel is written and the user's answers are
in place — that, and nothing earlier, is when the wiki is genuinely set up. A
user who leaves partway through leaves it unfinished: the wiki keeps whatever
was configured, and any schedule from Step 5 stays held.
