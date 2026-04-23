# EPR Agent Guidance

AI agent guidance for working with the Defra EPR microservices system. Designed for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or similar AI coding assistants.

## Setup

Uses [gitopolis](https://github.com/timabell/gitopolis) to manage the multi-repo workspace. See [repo-list/](../repo-list/) for the config and further explanation.

```sh
# 1. Clone this repo locally
mkdir workspace && cd workspace
git clone https://github.com/DEFRA/epr-local-environment.git

# 2. Symlink gitopolis config to workspace root
ln -s epr-local-environment/repo-list/.gitopolis.toml .gitopolis.toml

# 3. Create AGENTS.md pointer at workspace root (not a symlink - relative links must resolve from agents/)
cp epr-local-environment/agents/AGENTS.md.template AGENTS.md
cp AGENTS.md CLAUDE.md # for claude users

# 4. Clone all EPR service repos into workspace
gitopolis clone -t epr-producer
```

Your workspace should now look like:

```
workspace/
├── .gitopolis.toml               → symlink to epr-local-environment/repo-list/.gitopolis.toml
├── AGENTS.md                     → has a link to epr-local-environment/agents/AGENTS.md
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

Claude will pick up AGENTS.md, follow the link to the full guidance in `epr-local-environment/agents/`, and load the architecture docs, gotchas, and traced flows. Point it at issues, bugs, or features from there.

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
