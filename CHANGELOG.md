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
  (`~/.pi/agent/{AGENTS.md,prompts,skills}`), and Bob (`~/.bob/rules`,
  `~/.bob/skills`). Selection: `LLM_WIKI_HARNESS` / `--harness`, else the
  harness CLIs found on `PATH`, else `claude-code`.
- `AGENT.md` Rule 0a: on harnesses without session hooks the agent runs
  `hooks/session-start.sh` itself at session start.
- `uninstall.sh` removes the links from every harness.

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
