# INSTALLATION — Become the LLM Wiki Agent

This document turns a brand-new machine with only a coding agent (Claude Code
or another standard harness) into the **LLM Wiki agent**. It is written to be
executed **by the agent itself**: the operator's entire job is one message
like

> Install yourself: fetch `https://github.com/dam-agents/llm-wiki-v2` and
> follow `INSTALLATION.md`.

Installation runs **once per machine**. The interactive wiki setup
(onboarding) is a separate, per-wiki step that runs afterwards — see Step 4.

## Paths

| Path | Purpose |
|------|---------|
| Work directory (canonically `/home/agent/work`) | This repo — the agent definition. All sessions start here. |
| `<work>/wiki/` | The wiki content (created later by onboarding, gitignored here) |
| `<work>/.raw/` | Source-document intake (user files gitignored, demo files tracked) |
| `$HOME` | Agent state and secrets (`.claude/`, `.ssh/`, `.config/`) — never inside the repo |
| `$HOME/.llm-wiki-installed` | Install sentinel — guards against re-running |

## Step 0 — Guard

Check the sentinel:

```bash
[ -f "$HOME/.llm-wiki-installed" ] && echo "Already installed on: $(cat "$HOME/.llm-wiki-installed")"
```

If it exists, installation is done — skip to Step 4 (onboarding hand-off).

## Step 1 — Bootstrap the Repo into the Work Directory

From inside the (possibly empty) work directory. If a provisioner already
cloned the repo here (`.git` exists with the right origin), just sync it.

```bash
# From the work directory (your CWD at session start)
if [ ! -d .git ]; then
    git init -b main
    git remote add origin https://github.com/dam-agents/llm-wiki-v2.git
fi

# Optional: route git auth through gh if it is installed and authenticated
command -v gh >/dev/null && gh auth setup-git || true

git fetch origin
git reset --hard origin/main
```

Rules:

- **Never run `git clean`** here — untracked and gitignored content
  (`wiki/`, user files in `.raw/`) must survive every sync.
- Do not commit instance content (the wiki, user sources) to this repo; the
  `.gitignore` already excludes it.

## Step 2 — Run the Installer

```bash
bash llm-wiki/scripts/agent-install.sh
```

The script is idempotent (re-runs are no-ops; `--force` re-applies) and does,
for Claude Code:

1. Symlinks `llm-wiki/` → `~/.claude/skills/llm-wiki` (skill)
2. Symlinks `llm-wiki/commands/*.md` → `~/.claude/commands/` (slash commands)
3. Symlinks `AGENT.md` → `~/.claude/CLAUDE.md` (global operating manual;
   an existing regular file is backed up first)
4. Registers the global `SessionStart`/`SessionEnd` hooks in
   `~/.claude/settings.json` (wiki stats, onboarding gate, hot-cache)
5. Writes the `$HOME/.llm-wiki-installed` sentinel

Because everything is a symlink into this repo, updating the agent later is
just `git fetch origin && git reset --hard origin/main` — no reinstall.

## Step 3 — Verify

```bash
readlink "$HOME/.claude/skills/llm-wiki"      # → <work>/llm-wiki
readlink "$HOME/.claude/CLAUDE.md"            # → <work>/AGENT.md
ls "$HOME/.claude/commands"/wiki-*.md          # 7 command files
grep -c llm-wiki "$HOME/.claude/settings.json" # ≥ 2 (both hooks)
cat "$HOME/.llm-wiki-installed"                # install timestamp
```

If any check fails, re-run `agent-install.sh --force` and re-verify.

## Step 4 — Hand Off to Onboarding

Installation is machine setup; the wiki itself does not exist yet. Now run
the onboarding interview — as the agent, do this immediately in the same
session:

- Follow `llm-wiki/workflows/onboard.md` (the `/wiki-onboard` command).

Onboarding asks the user for the wiki's name, language, and purpose, then
initializes `./wiki/`, optionally sets up a git remote and a maintenance
schedule, offers a first ingestion, and writes the
`./wiki/.llm-wiki/onboarded` sentinel. From then on, every session starts
with wiki context injected by the hooks, and the agent operates per
`AGENT.md`.

If the wiki was restored from a remote (the `onboarded` sentinel already
exists inside it), onboarding is skipped automatically — install is
per-machine, onboarding is per-wiki.

## Other Harnesses

The skill is plain markdown + bash; only the wiring differs. To install for
a harness other than Claude Code:

| Claude Code mechanism | Generic equivalent |
|-----------------------|--------------------|
| `~/.claude/CLAUDE.md` (global instructions) | Link `AGENT.md` as the harness's global/system instructions file (e.g. `AGENTS.md`) |
| `~/.claude/commands/*.md` (slash commands) | Optional — the workflow files in `llm-wiki/workflows/` are the real procedures |
| `SessionStart` hook | Any session-start mechanism that runs `llm-wiki/hooks/session-start.sh` and injects its stdout as context; if none exists, `AGENT.md` Rule 0 still gates onboarding |
| `SessionEnd` hook | Run `llm-wiki/hooks/session-stop.sh` at session end (hot-cache); optional |

Minimum viable install on any harness: make the agent read `AGENT.md` at
session start. Everything else is an optimization.
