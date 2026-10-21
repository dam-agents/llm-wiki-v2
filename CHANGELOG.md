# Changelog

All notable changes to LLM Wiki will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Agent-mode install (`bootstrap.sh` / `scripts/agent-install.sh`) now wires
  every installed harness, not only Claude Code: the skill lands in
  `~/.agents/skills/llm-wiki` (agentskills.io, read by all harnesses) and the
  manual + slash commands are linked into Claude Code (`~/.claude`), Codex
  (`$CODEX_HOME/AGENTS.md`, `$CODEX_HOME/prompts` as `/prompts:wiki-…`), Pi
  (`~/.pi/agent/{AGENTS.md,prompts,skills}`), and Bob (`~/.bob/rules`;
  the skill goes to `~/.claude/skills`, Bob's global skills directory, and
  `~/.bob/skills`). Selection: `LLM_WIKI_HARNESS` / `--harness`, else the
  harness CLIs found on `PATH`, else `claude-code`.
- `AGENT.md` Rule 0a: on harnesses without session hooks the agent runs
  `hooks/session-start.sh` itself at session start.
- `uninstall.sh` removes the links from every harness.

### Fixed

- Install no longer races a harness image that syncs `~/.claude/settings.json`.
  The hooks were merged through the fixed name `settings.json.tmp`, which the
  image also used, so the merge died with
  `mv: cannot stat '.../settings.json.tmp'`. Every write to a shared file now
  goes through a private `mktemp` file in the destination's own directory,
  published by an atomic rename that keeps the existing file mode and follows
  a symlink to its target instead of replacing the link. Writing through a
  dangling settings symlink is preserved, so a managed settings target is no
  longer lost. `setup-project.sh` had the same fixed-`.tmp` pattern for
  `CLAUDE.md`, for merged `.claude/settings.local.json`, and an in-place write
  for a newly created one; all three now use the private-temp publish, and a
  generation failure cleans the temp up and leaves the original untouched.
- A hooks failure no longer aborts the install. It warns, prints the
  `agent-install.sh --force` re-run, and keeps exit 0 so the skill, manual, and
  command links survive. This is a behaviour change for the reported collision
  (previously exit 1 via `set -e`); invalid JSON already exited 0 before.
- The `CLAUDE.md` prepend checks every read, so an unreadable `WIKI.md` no
  longer publishes a partial file and reports success (errexit is off in the
  conditional context it used to rely on). A newly created project settings
  file is re-checked for the hook before success is announced. A failure to
  read or apply an existing file's mode now refuses publication instead of
  replacing the file with different permissions, and a cyclic settings symlink
  is refused with a warning rather than followed forever.

### Changed

- Skill, command, and workflow docs refer to the skill directory
  (`~/.agents/skills/llm-wiki`) instead of hardcoding `~/.claude/skills`, and
  `Skill("llm-wiki")` is described as the Claude Code way to load the skill.

- The wiki is now English-only: removed bilingual (en/zh) support, CJK
  language detection, and cross-language query matching. The `language`
  frontmatter field remains but is always `en`; non-English sources are
  translated into English during ingest.

## [0.1.0] — 2026-05-03

### Added

- Initial release of LLM Wiki skill for Claude Code
- Two-phase source ingestion (`/wiki-ingest`) with SHA-256 idempotency
- Index-first knowledge retrieval (`/wiki-query`) for O(1) lookup
- Health check system (`/wiki-lint`) with quick (bash) and full (LLM) modes
- Answer-to-synthesis persistence (`/wiki-save`) for compounding knowledge
- D3.js knowledge graph visualization (`/wiki-graph`)
- Review queue processing (`/wiki-review`) for contradiction/quality management
- Wiki dashboard (`/wiki`)
- Bilingual support (en/zh/bilingual) with CJK auto-detection
- Session lifecycle hooks (start/stop) with hot-cache for context continuity
- Page templates for concept, article, person, and synthesis types
- Project setup script (`setup-project.sh`) with optional hooks configuration
- Wiki initialization script (`init-wiki.sh`)
- Global installation script (`install.sh`)
- Quickstart script (`quickstart.sh`) with demo content
- Uninstall script (`uninstall.sh`)
- Demo source files (Greek mythology)
- CI pipeline (ShellCheck + markdownlint + integration tests)
- Local CI runner (`scripts/ci-local.sh`)
- Community files (CoC, Contributing, Security, Support, PR/Issue templates)

### Fixed

- CI failures in initial workflow configuration
- Portability issues for non-Linux environments
