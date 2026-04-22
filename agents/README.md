# EPR Agent Guidance

AI agent guidance for working with the Defra EPR microservices system. Designed for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or similar AI coding assistants.

## Setup

Uses [gitopolis](https://github.com/timabell/gitopolis) to manage the multi-repo workspace. See [repo-list/](../repo-list/) for the config and further explanation.

```sh
# 1. Clone this repo locally
mkdir workspace && cd workspace
git clone https://github.com/DEFRA/epr-local-environment.git

# 2. Symlink gitopolis config and AGENTS.md to workspace root
ln -s epr-local-environment/repo-list/.gitopolis.toml .gitopolis.toml
ln -s epr-local-environment/agents/AGENTS.md AGENTS.md
ln -s AGENTS.md CLAUDE.md # for claude users

# 3. Clone all EPR service repos into workspace
gitopolis clone -t epr-producer
```

Your workspace should now look like:

```
workspace/
├── .gitopolis.toml               → symlink to epr-local-environment/repo-list/.gitopolis.toml
├── AGENTS.md                     → symlink to epr-local-environment/agents/AGENTS.md
├── epr-local-environment/
│   └── agents/
│       ├── AGENTS.md             ← full agent guidance (start here)
│       ├── architecture.md
│       ├── exploration-guide.md
│       ├── gotchas.md
│       ├── glossary.md
│       ├── about-epr.md
│       ├── data-flows.md
│       ├── flows/                ← traced multi-service data flows
│       └── repos/                ← per-service quick reference
├── epr-regulator-service/
├── epr-regulator-service-facade/
├── epr-common-data-api/
└── ...                           (all epr-* repos)
```

## Usage

Run Claude from the parent workspace directory:

```sh
cd workspace/
claude
```

Claude will pick up the AGENTS.md symlink and follow links to the full guidance. Point it at issues, bugs, or features and it will use the architecture docs, gotchas, and traced flows to orient itself.

## What's in here

| File | Purpose |
|------|---------|
| [AGENTS.md](AGENTS.md) | Main entry point - quick start, doc index, report format, SonarQube |
| [architecture.md](architecture.md) | System overview, service map, patterns, constraints |
| [exploration-guide.md](exploration-guide.md) | How to trace data flows, debug, find code |
| [gotchas.md](gotchas.md) | Traps, misleading names, things that look wrong but aren't |
| [glossary.md](glossary.md) | EPR terminology, WA/FA numbers, business terms |
| [about-epr.md](about-epr.md) | Regulatory context, producer obligations, fee structure |
| [data-flows.md](data-flows.md) | Flow index, documentation template, quality checklist |
| [flows/](flows/) | Pre-traced multi-service data flows (reference / examples) (best viewed with [an outliner](https://github.com/timabell/vscode-markdown-outliner)) |
| [repos/](repos/) | Per-service quick reference with entry points and gotchas |
