# INSTALLATION — Become the LLM Wiki Agent

Installation turns a brand-new machine with only a coding agent (Claude Code
or another standard harness) into the **LLM Wiki agent**. It is a single
deterministic command — no interaction, no decisions, no agent reasoning.

It runs **once per machine** and does **not** include onboarding (the
interactive wiki-setup interview). Onboarding is requested automatically at
the next session start, or on demand — see below.

## The One Command

From the work directory (canonically `/home/agent/work`, the directory where
every session starts):

```bash
curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash
```

If the repo is already checked out here (pre-provisioned machine), the
equivalent is just:

```bash
./bootstrap.sh
```

If an agent is running the install, this is the entire operator prompt:

> Run this command from your current working directory and report the
> result. Do not start onboarding:
> `curl -fsSL https://raw.githubusercontent.com/dam-agents/llm-wiki-v2/main/bootstrap.sh | bash`

## What It Does

`bootstrap.sh` is idempotent (guarded by the `$HOME/.llm-wiki-installed`
sentinel; re-runs exit early) and, in order:

1. Syncs the agent-definition repo into the current directory: `git init`
   if needed, add `origin`, `git fetch` + `git reset --hard origin/main`.
   It **never runs `git clean`**, so untracked and gitignored content
   (`wiki/`, user files in `.raw/`) survives every sync.
2. Runs `llm-wiki/scripts/agent-install.sh`, which — for Claude Code —
   symlinks `llm-wiki/` → `~/.claude/skills/llm-wiki`, the slash commands →
   `~/.claude/commands/`, and `AGENT.md` → `~/.claude/CLAUDE.md` (an
   existing regular file is backed up first); registers the global
   `SessionStart`/`SessionEnd` hooks in `~/.claude/settings.json`; and
   writes the sentinel.

Because everything is a symlink into the repo, updating the agent later is
just `git fetch origin && git reset --hard origin/main` — no reinstall.

Override the source repo with `LLM_WIKI_REPO=<git-url>` when bootstrapping
from a fork or mirror.

## Paths

| Path | Purpose |
|------|---------|
| Work directory (canonically `/home/agent/work`) | This repo — the agent definition. All sessions start here. |
| `<work>/wiki/` | The wiki content (created later by onboarding, gitignored here) |
| `<work>/.raw/` | Source-document intake (user files gitignored, demo files tracked) |
| `$HOME` | Agent state and secrets (`.claude/`, `.ssh/`, `.config/`) — never inside the repo |
| `$HOME/.llm-wiki-installed` | Install sentinel — guards against re-running |

## Verify

```bash
readlink "$HOME/.claude/skills/llm-wiki"      # → <work>/llm-wiki
readlink "$HOME/.claude/CLAUDE.md"            # → <work>/AGENT.md
ls "$HOME/.claude/commands"/wiki-*.md          # 7 command files
grep -c llm-wiki "$HOME/.claude/settings.json" # ≥ 2 (both hooks)
cat "$HOME/.llm-wiki-installed"                # install timestamp
```

If any check fails, run `llm-wiki/scripts/agent-install.sh --force` and
re-verify.

## Onboarding Is a Separate Step

Installation is machine plumbing; the wiki does not exist yet, and the
installer deliberately does not create it. Onboarding is interactive — it
belongs to a conversation with the user, not to a script:

- **Automatically**: the next session's start hook detects the missing
  `./wiki/.llm-wiki/onboarded` sentinel and instructs the agent to run the
  onboarding interview before anything else.
- **On demand**: run `/wiki-onboard` (skill workflow
  `llm-wiki/workflows/onboard.md`) whenever you're ready.

Onboarding asks for the wiki's name, language, and purpose, then initializes
`./wiki/`, optionally sets up a git remote and a maintenance schedule,
offers a first ingestion, and writes the sentinel. If the wiki was restored
from a remote (the sentinel already exists inside it), onboarding is skipped
automatically — install is per-machine, onboarding is per-wiki.

## Other Harnesses

The skill is plain markdown + bash; `bootstrap.sh` step 1 is
harness-neutral, and only `agent-install.sh`'s wiring targets Claude Code.
To install for another harness:

| Claude Code mechanism | Generic equivalent |
|-----------------------|--------------------|
| `~/.claude/CLAUDE.md` (global instructions) | Link `AGENT.md` as the harness's global/system instructions file (e.g. `AGENTS.md`) |
| `~/.claude/commands/*.md` (slash commands) | Optional — the workflow files in `llm-wiki/workflows/` are the real procedures |
| `SessionStart` hook | Any session-start mechanism that runs `llm-wiki/hooks/session-start.sh` and injects its stdout as context; if none exists, `AGENT.md` Rule 0 still gates onboarding |
| `SessionEnd` hook | Run `llm-wiki/hooks/session-stop.sh` at session end (hot-cache); optional |

Minimum viable install on any harness: make the agent read `AGENT.md` at
session start. Everything else is an optimization.
