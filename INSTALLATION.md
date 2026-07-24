# INSTALLATION — Become the LLM Wiki Agent

Installation turns a brand-new machine with only a coding agent (Claude Code
or another standard harness) into the **LLM Wiki agent**. It is a single
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

If an agent is running the install, this is the entire operator prompt:

> Run this command and report the result. Do not start onboarding:
> `curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash`

## What It Does

`bootstrap.sh` is idempotent (guarded by the `$HOME/.llm-wiki-installed`
sentinel; re-runs exit early) and, in order:

1. Installs the agent-definition repo into `~/.llm-wiki-agent` — `git clone`
   on first run, `git fetch` + `git reset --hard origin/main` thereafter. It
   **never runs `git clean`**. The working directory is not touched.
2. Runs `~/.llm-wiki-agent/llm-wiki/scripts/agent-install.sh`, which — for
   Claude Code — symlinks `llm-wiki/` → `~/.claude/skills/llm-wiki`, the
   slash commands → `~/.claude/commands/`, and `AGENT.md` →
   `~/.claude/CLAUDE.md` (an existing regular file is backed up first);
   registers the global `SessionStart`/`SessionEnd` hooks in
   `~/.claude/settings.json`; and writes the sentinel.

Because everything in `~/.claude` is a symlink into `~/.llm-wiki-agent`,
updating the agent later is just:

```bash
git -C ~/.llm-wiki-agent pull --ff-only
```

Override the source repo with `LLM_WIKI_REPO=<git-url-or-path>` (bootstrapping
from a fork or mirror) and the install location with `LLM_WIKI_AGENT_HOME`.

## Paths

| Path | Purpose |
|------|---------|
| `$HOME/.llm-wiki-agent/` | The agent definition — tooling, skill, docs (a git checkout) |
| `$HOME/.claude/` | Symlinks into `~/.llm-wiki-agent` + hooks (managed by the installer) |
| `$HOME/.llm-wiki-installed` | Install sentinel — guards against re-running |
| Work directory (canonically `/home/agent/work`) | Where sessions start; holds only operational data |
| `<work>/wiki/` | The wiki content (created by onboarding, its own git repo) |
| `<work>/.raw/` | Source-document intake |

Start your working sessions in the work directory — the session hooks resolve
`./wiki` and `./.raw` relative to the current directory.

## Verify

```bash
readlink "$HOME/.claude/skills/llm-wiki"      # → ~/.llm-wiki-agent/llm-wiki
readlink "$HOME/.claude/CLAUDE.md"            # → ~/.llm-wiki-agent/AGENT.md
ls "$HOME/.claude/commands"/wiki-*.md          # 7 command files
grep -c llm-wiki "$HOME/.claude/settings.json" # ≥ 2 (both hooks)
cat "$HOME/.llm-wiki-installed"                # install timestamp
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

Onboarding asks for the wiki's name, language, and purpose, then initializes
`<work>/wiki/`, optionally sets up a git remote and a maintenance schedule,
offers a first ingestion, and writes the sentinel. If the wiki was restored
from a remote (the sentinel already exists inside it), onboarding is skipped
automatically — install is per-machine, onboarding is per-wiki.

## Other Harnesses

The skill is plain markdown + bash; `bootstrap.sh` step 1 is
harness-neutral, and only `agent-install.sh`'s wiring targets Claude Code.
To install for another harness:

| Claude Code mechanism | Generic equivalent |
|-----------------------|--------------------|
| `~/.claude/CLAUDE.md` (global instructions) | Link `~/.llm-wiki-agent/AGENT.md` as the harness's global/system instructions file (e.g. `AGENTS.md`) |
| `~/.claude/commands/*.md` (slash commands) | Optional — the workflow files in `~/.llm-wiki-agent/llm-wiki/workflows/` are the real procedures |
| `SessionStart` hook | Any session-start mechanism that runs `~/.llm-wiki-agent/llm-wiki/hooks/session-start.sh` and injects its stdout as context; if none exists, `AGENT.md` Rule 0 still gates onboarding |
| `SessionEnd` hook | Run `~/.llm-wiki-agent/llm-wiki/hooks/session-stop.sh` at session end (hot-cache); optional |

Minimum viable install on any harness: make the agent read
`~/.llm-wiki-agent/AGENT.md` at session start. Everything else is an
optimization.
