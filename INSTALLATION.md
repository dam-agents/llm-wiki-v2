# INSTALLATION — Become the LLM Wiki Agent

Installation turns a brand-new machine with only a coding agent — Claude
Code, OpenAI Codex, Pi, or IBM Bob — into the **LLM Wiki agent**. It is a single
deterministic command — no interaction, no decisions, no agent reasoning.

It runs **once per machine** and does **not** include onboarding (the
interactive wiki-setup interview). Onboarding is requested automatically at
the next session start, or on demand — see below.

The installer keeps tooling and workspace strictly separate: the agent
definition is installed into your **home** directory (`~/.llm-wiki-agent`),
and the working directory is never touched. Nothing you do in the workspace
can damage the agent, and updating the agent can never disturb your wiki.

## The One Command

Run from anywhere — the installer targets `$HOME`, so the current directory
does not matter:

```bash
curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash
```

If the repo is already checked out locally, the equivalent is:

```bash
./bootstrap.sh
```

That is also how the platform's kit installs it: the kit seeds this repo into
the agent's workspace at a pinned commit and runs `bash bootstrap.sh` from that
checkout, so nothing is fetched at install.

If an agent is running the install, this is the entire operator prompt:

> Run this command and report the result. Do not start onboarding:
> `curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash`

## What It Does

`bootstrap.sh` is idempotent (guarded by the `$HOME/.llm-wiki-installed`
sentinel; re-runs exit early) and, in order:

1. Installs the agent-definition repo into `~/.llm-wiki-agent` — `git clone`
   on first run, `git fetch` + `git reset --hard origin/main` thereafter. It
   **never runs `git clean`**. The working directory is not touched.
2. Runs `~/.llm-wiki-agent/llm-wiki/scripts/agent-install.sh`, which
   symlinks `llm-wiki/` → `~/.agents/skills/llm-wiki` (the agentskills.io
   location every harness reads), then wires each selected harness — see the
   table below — and writes the sentinel. An existing regular file at a
   manual's path is backed up first, never overwritten.

Which harnesses get wired is decided in this order: `LLM_WIKI_HARNESS`
(comma/space-separated list of `claude-code`, `codex`, `pi`, `bob`, or `all`),
else `PLATFORM_HARNESS` (the family the platform's harness image runs, set in
the image itself), else every harness CLI found on `PATH` (`claude`, `codex`,
`pi`, `bob`), else `claude-code`. To wire an additional harness later, re-run
with `--force`.

| Harness | Skill | Global manual (`AGENT.md`) | Slash commands | Session hooks |
|---------|-------|----------------------------|----------------|---------------|
| Claude Code | `~/.claude/skills/llm-wiki` (usually already an alias of `~/.agents/skills`) | `~/.claude/CLAUDE.md` | `~/.claude/commands/wiki-*.md` → `/wiki-…` | `SessionStart`/`SessionEnd` in `~/.claude/settings.json` |
| Codex | `~/.agents/skills` (native) | `$CODEX_HOME/AGENTS.md` (`~/.codex/AGENTS.md`) | `$CODEX_HOME/prompts/wiki-*.md` → `/prompts:wiki-…` | none — `AGENT.md` Rule 0a |
| Pi | `~/.pi/agent/skills/llm-wiki` (also reads `~/.agents/skills`) | `~/.pi/agent/AGENTS.md` | `~/.pi/agent/prompts/wiki-*.md` → `/wiki-…` | none — `AGENT.md` Rule 0a |
| Bob | `~/.claude/skills/llm-wiki` (Bob's global skills dir) and `~/.bob/skills/llm-wiki` | `~/.bob/rules/llm-wiki.md` | none — the manual maps `/wiki-…` to workflows | none — `AGENT.md` Rule 0a |

The command files are plain markdown with `description` / `argument-hint`
frontmatter and `$ARGUMENTS` placeholders, which Claude Code, Codex, and Pi
all understand unchanged. Harnesses without session hooks rely on `AGENT.md`
Rule 0a: the agent runs `hooks/session-start.sh` itself as its first action.

Because every installed path is a symlink into `~/.llm-wiki-agent`, updating
the agent later is just:

```bash
git -C ~/.llm-wiki-agent pull --ff-only
```

Override the source repo with `LLM_WIKI_REPO=<git-url-or-path>` (bootstrapping
from a fork or mirror), the install location with `LLM_WIKI_AGENT_HOME`, and
the harness selection with `LLM_WIKI_HARNESS`.

## Paths

| Path | Purpose |
|------|---------|
| `$HOME/.llm-wiki-agent/` | The agent definition — tooling, skill, docs (a git checkout) |
| `$HOME/.agents/skills/llm-wiki` | Symlink to `~/.llm-wiki-agent/llm-wiki` — the skill, for every harness |
| `$HOME/.claude/`, `$HOME/.codex/`, `$HOME/.pi/agent/`, `$HOME/.bob/` | Per-harness symlinks into `~/.llm-wiki-agent` (+ hooks on Claude Code), managed by the installer |
| `$HOME/.llm-wiki-installed` | Install sentinel — guards against re-running |
| Work directory (canonically `/home/agent/work`) | Where sessions start; holds only operational data |
| `<work>/wiki/` | The wiki content (created by onboarding, its own git repo) |
| `<work>/.raw/` | Source-document intake |

Start your working sessions in the work directory — the session hooks resolve
`./wiki` and `./.raw` relative to the current directory.

## Verify

```bash
readlink "$HOME/.agents/skills/llm-wiki"      # → ~/.llm-wiki-agent/llm-wiki (every harness)
cat "$HOME/.llm-wiki-installed"                # install timestamp
# Claude Code
readlink "$HOME/.claude/CLAUDE.md"            # → ~/.llm-wiki-agent/AGENT.md
ls "$HOME/.claude/commands"/wiki-*.md          # 7 command files
grep -c llm-wiki "$HOME/.claude/settings.json" # ≥ 2 (both hooks)
# Codex / Pi / Bob
readlink "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"; ls "${CODEX_HOME:-$HOME/.codex}/prompts"/wiki-*.md
readlink "$HOME/.pi/agent/AGENTS.md";             ls "$HOME/.pi/agent/prompts"/wiki-*.md
readlink "$HOME/.bob/rules/llm-wiki.md"
```

If any check fails, run `~/.llm-wiki-agent/llm-wiki/scripts/agent-install.sh --force`
and re-verify.

## Onboarding Is a Separate Step

Installation is machine plumbing; the wiki does not exist yet, and the
installer deliberately does not create it. Onboarding is interactive — it
belongs to a conversation with the user, not to a script:

- **Automatically**: the next session's start hook detects the missing
  `./wiki/.llm-wiki/onboarded` sentinel and instructs the agent to run the
  onboarding interview before anything else.
- **On demand**: run `/wiki-onboard` (skill workflow
  `~/.llm-wiki-agent/llm-wiki/workflows/onboard.md`) whenever you're ready.

Onboarding asks for the wiki's name and purpose, then initializes
`<work>/wiki/`, optionally sets up a git remote and a maintenance schedule,
offers a first ingestion, and writes the sentinel. If the wiki was restored
from a remote (the sentinel already exists inside it), onboarding is skipped
automatically — install is per-machine, onboarding is per-wiki.

## Other Harnesses

Claude Code, Codex, Pi, and Bob are wired automatically (table above). For a
harness the installer does not know, the skill is still plain markdown + bash
and `bootstrap.sh` step 1 is harness-neutral — wire it by hand:

| Claude Code mechanism | Generic equivalent |
|-----------------------|--------------------|
| `~/.claude/CLAUDE.md` (global instructions) | Link `~/.llm-wiki-agent/AGENT.md` as the harness's global/system instructions file (e.g. `AGENTS.md`) |
| `~/.claude/skills/llm-wiki` (skill) | `~/.agents/skills/llm-wiki` is already there — link it wherever the harness looks for skills |
| `~/.claude/commands/*.md` (slash commands) | Optional — the workflow files in `~/.llm-wiki-agent/llm-wiki/workflows/` are the real procedures |
| `SessionStart` hook | Any session-start mechanism that runs `~/.llm-wiki-agent/llm-wiki/hooks/session-start.sh` and injects its stdout as context; if none exists, `AGENT.md` Rule 0a has the agent run it itself |
| `SessionEnd` hook | Run `~/.llm-wiki-agent/llm-wiki/hooks/session-stop.sh` at session end (hot-cache); optional |

Minimum viable install on any harness: make the agent read
`~/.llm-wiki-agent/AGENT.md` at session start. Everything else is an
optimization. A new harness that should be wired automatically is one more
`case` arm in `llm-wiki/scripts/agent-install.sh` plus its paths in
`uninstall.sh`.
