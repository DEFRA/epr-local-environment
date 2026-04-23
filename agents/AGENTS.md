# Defra EPR Microservices

**NOTE**: This is a large legacy system in maintenance mode. Verify patterns against actual code before assuming they are intentional. See [gotchas.md](gotchas.md) for known traps.

**IMPORTANT**: Most EPR repos should be cloned locally as siblings of this repo (see [README.md](README.md) for setup). Always check local folders first before fetching from GitHub. Links in these docs point to GitHub as a fallback, but prefer reading and searching the local clones.

## In this folder you'll find

- Agent guidance and system documentation
- `repos/` - per-service quick reference
- `flows/` - traced multi-service data flows (reference + documentation examples)

## Documentation Index

### Core Reference
- [glossary.md](glossary.md) - EPR terminology, WA/FA numbers, business terms
- [architecture.md](architecture.md) - System overview, patterns, known constraints
- [gotchas.md](gotchas.md) - Misleading names, gotchas, architectural constraints
- [about-epr.md](about-epr.md) - Business context, regulations, producer obligations
- [repos/README.md](repos/README.md) - Find a specific service

### Investigation Guides
- [exploration-guide.md](exploration-guide.md) - How to trace data flows, debug issues
- [data-flows.md](data-flows.md) - Flow index, documentation template, and quality checklist

### Traced Data Flows
Pre-traced multi-service flows. Use these to avoid re-discovering complex cross-service paths, and as examples of how to document new flow investigations.
- [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md) - Dual-source merge: CosmosDB + Synapse for regulator submissions view
- [flows/previous-payment-info-flow.md](flows/previous-payment-info-flow.md) - Payment lookup: frontend → payment facade → payment service → SQL
- [flows/synapse-etl-pipeline-submissions-summaries.md](flows/synapse-etl-pipeline-submissions-summaries.md) - Full ETL pipeline: CosmosDB → rpd schema → apps schema → materialized table → query with delta overlay

### Per-Service Reference
- [repos/README.md](repos/README.md) - Index of service summaries
- Key services:
  - [epr-regulator-service-facade](repos/epr-regulator-service-facade.md) - dual-source merge pattern
  - [epr-pom-api-submission-status](repos/epr-pom-api-submission-status.md) - CosmosDB event store
  - [epr-common-data-api](repos/epr-common-data-api.md) - Synapse analytics API

### External Documentation
- [epr-assessment/specs/](https://github.com/DEFRA/epr-assessment/tree/main/specs) - Detailed AI-generated service specifications (use as reference, may not be 100% accurate)
- [C4 diagrams](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/_index.c4) - Authoritative source for service relationships
  - **Finding repos**: Grep `model.producer-regulator.c4` for service names → get `link https://github.com/...` and `metadata.name`
  - **If C4 is wrong**: Note discrepancies - it should be corrected

## Repo Management

```sh
gitopolis list -t epr-producer # list relevant repos
gitopolis exec -t epr-producer --oneline -- git st # check current branch
gitopolis exec -t epr-producer -- git pull # bring branches up to latest
gitopolis exec -t epr-producer -- git rev-parse origin/main # find sha for permalinks
```

## Report format

When reporting on data flows, use logseq-style indented bullet outlining as per the examples in [flows/](flows/). See [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md) for the reference example.

**Requirements**:
- Use logseq-style indented bullets (tabs for hierarchy)
- Every code reference MUST have a github/devops permalink with line numbers - for line code: [`SomeFunc()`](permalink#lines)
- Use `gitopolis exec -t epr-producer -- git rev-parse origin/main` to get SHAs for permalinks
- Structure:
  - Layer by layer (Frontend → Facade → Backend → Database)
  - File path with permalink to specific lines
  - Method/function names
  - What it does / what it calls
  - Key data transformations
- NO vague repo root links - every link must point to specific code with line numbers
- NO GAPS - analysis should include hyperlinked entries for *EVERY* step in the flow across code, data & config, even seemingly trivial function calls. This is important for analysis to be validatable.
- Include configuration file references with line numbers
- Show HTTP endpoints, routes, and API contracts
- Explain WHY architectural decisions were made where relevant

## SonarQube build failure troubleshooting

No token-based access — the user must paste API URLs into their authenticated browser session and return the JSON.

### Diagnosing a failed quality gate

1. **Check quality gate status** (covers coverage, duplication, ratings — not just issues):
   ```
   https://vss-sonarqube.azure.defra.cloud/api/qualitygates/project_status?projectKey={project-key}&branch={branch-name}
   ```

2. **Find code issues** (bugs, smells, vulnerabilities on new code):
   ```
   https://vss-sonarqube.azure.defra.cloud/api/issues/search?componentKeys={project-key}&branch={branch-name}&resolved=false&sinceLeakPeriod=true&ps=500
   ```

3. **Find uncovered files** (when the gate fails on coverage):
   ```
   https://vss-sonarqube.azure.defra.cloud/api/measures/component_tree?component={project-key}&branch={branch-name}&metricKeys=new_uncovered_lines,new_lines_to_cover&strategy=leaves&qualifiers=FIL&metricSort=new_lines_to_cover&metricSortFilter=withMeasuresOnly&s=metric&asc=false&ps=50
   ```

Always start with step 1 — the issues endpoint alone will miss coverage/duplication failures.

### Known project keys
- `frontend-obligationchecker-microservice` → epr-obligationchecker-frontend
