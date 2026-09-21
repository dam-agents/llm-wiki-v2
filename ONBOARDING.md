# Onboarding

The platform opens this agent's first session on this file. It is the
`/wiki-onboard` interview — the same one the toolkit keeps as a command for a
re-run — with the platform's onboarding checklist around it. The complete
procedure, with every path and file it writes, is
`llm-wiki/workflows/onboard.md` in this checkout, installed at
`~/.llm-wiki-agent/llm-wiki/workflows/onboard.md`. Follow it; this file says
what to ask the user and when to report progress back to the platform.

`bash bootstrap.sh` has already run, so the tooling is in `~/.llm-wiki-agent`
and wired into your harness. Nothing here installs anything.

## 0. Set the checklist first

Before you ask the user anything, call `set_onboarding_checklist` so they can
follow along in the platform:

| id | label |
| --- | --- |
| `name` | Name the wiki |
| `purpose` | Say what knowledge it will hold |
| `sources` | Hand over the first documents |
| `backup` | Decide whether the wiki gets a git remote |
| `schedule` | Decide on a maintenance cadence |

Tick each with `complete_onboarding_step` as the user answers — a decision to
skip is an answer, so `backup` and `schedule` tick on a "no" too. Call
`set_onboarding_checklist` again if the conversation changes what you need; the
steps you keep stay ticked. Your own work — running `init-wiki.sh`, writing the
config, ingesting, writing the usage guide — is never a step.

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
wiki is English-only, so do not ask about language. Tick `name` and `purpose`.

## 3. Initialize and configure

Create `./.raw`, run `init-wiki.sh ./wiki` from the skill directory, and write
the answers into `./wiki/.llm-wiki/config.md` — `wiki_name`, `language: en`, a
`## Purpose` line, and `require_review: false` in agent mode. Silently; this is
your work, not a step.

## 4. Wiki git remote (optional)

Initialize `./wiki` as its own git repository and commit, then ask whether the
wiki should be backed up to a remote. On a URL, wire it up and push, reporting
a failure plainly and moving on; on a no, skip without follow-up questions. The
wiki repository is never pushed to the agent's own definition repository.
Either way, tick `backup`.

## 5. Maintenance cadence (optional)

Ask for a cadence — daily, weekly, or skip. If they pick one, create it with
the platform's `create_schedule` tool; a schedule you create now is held until
you mark onboarding complete, which is the point. Fall back to the harness's
own scheduler, and if there is none, say so in the closing message and rely on
session start. Tick `schedule`.

## 6. First sources

Ask for documents: files in `./.raw/`, paths, URLs — or the bundled
Greek-mythology demo. Ingest what arrives, silently, one summary line per
source. If they have nothing yet, say the wiki fills up whenever they hand you
documents. Tick `sources`.

## 7. Usage guide, sentinel, close

Write `./wiki/USAGE_GUIDE.md`, write the `./wiki/.llm-wiki/onboarded` sentinel,
and commit both with the config if the wiki is git-backed. Then one short
closing message: the wiki is ready, by name; a line on what it now knows if
anything was ingested; one or two concrete next actions.

## 8. Release the agent

Call `mark_onboarding_complete` once the sentinel is written and the user's
answers are in place. Not before — any schedule you created in Step 5 stays
held until you do. If the user leaves partway through, leave it uncalled: the
wiki keeps whatever was set up, and the platform keeps showing the setup as
unfinished.
