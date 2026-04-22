# Data Flow Documentation

Index of documented data flows and template for new investigations. Traced flows live in [flows/](flows/) and serve two purposes:
1. **Avoid re-discovery** - complex multi-service paths already traced end-to-end, giving a leg-up when analysing similar flows
2. **Documentation example** - reference for how to capture new flow assessments

## Documented Flows

| Flow | Description |
|------|-------------|
| [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md) | Dual-source pattern: CosmosDB + Synapse merge for regulator submissions view |
| [flows/previous-payment-info-flow.md](flows/previous-payment-info-flow.md) | Payment lookup: frontend → payment facade → payment service → SQL |
| [flows/synapse-etl-pipeline-submissions-summaries.md](flows/synapse-etl-pipeline-submissions-summaries.md) | Full ETL: CosmosDB → rpd → apps → materialized table → query with delta overlay |


## Data Flow Template

When documenting a new flow, use this structure (logseq-style indented bullets):

```markdown
- # {Feature Name} Data Flow Architecture
- ## Overview
	- Brief description of what this flow does
	- Which user roles are involved
	- Key data stores touched
- ## Complete Data Flow
	- ### Frontend Layer
		- **{service-name}** (WA xxx - description)
			- Route: `/path/to/page`
			- Controller: [{ControllerName}.cs:line](permalink)
			- Method: `ActionMethod(params)`
			- Calls: `_service.Method()`
				- Implementation: [{ServiceClass}.cs:line](permalink)
				- HTTP endpoint: `{BaseUrl}/api/path`
	- ### Facade Layer
		- **{facade-name}** (WA xxx - description)
			- Route: `api/path`
			- Controller: [{ControllerName}.cs:line](permalink)
			- **Step 1**: Description
				- Calls: `_backendService.Method()`
				- [File.cs:line](permalink)
			- **Step 2**: Description
				- ...
	- ### Backend Layer
		- **{backend-name}** (WA/FA xxx - description)
			- Route: `api/path`
			- Controller: [{ControllerName}.cs:line](permalink)
			- Handler/Service: [{HandlerName}.cs:line](permalink)
			- **Database**: {type}
				- Context: [{DbContext}.cs:line](permalink)
				- Table/Container: `name`
- ## Why This Architecture?
	- ### Problem Statement
		- What user need drives this design
	- ### Solution
		- How the architecture addresses it
		- Trade-offs made
- ## API Endpoints Summary
	- ### Layer → Layer
		- ```
		  HTTP_METHOD /path
		  Request: { ... }
		  Response: { ... }
		  ```
- ## Key Source Files
	- Grouped by layer with GitHub permalinks
- ## C4 Architecture Mapping
	- References to C4 diagram elements
	- Line numbers in model files
```

## Permalink Format

**GitHub:**
```
https://github.com/DEFRA/{repo}/blob/{sha}/path/to/file.cs#L{start}-L{end}
```

**Azure DevOps:**
```
https://dev.azure.com/{org}/{project}/_git/{repo}?path={path}&version=GC{sha}&line={start}&lineEnd={end}&lineStartColumn=1&lineEndColumn=1&lineStyle=plain&_a=contents
```

**Getting SHAs:**
```sh
gitopolis exec -t epr-producer -- git rev-parse origin/main
```

## Quality Checklist

Before marking a flow as complete:

- [ ] Every code reference has a permalink with line numbers
- [ ] All layers documented (frontend → facade → backend → database)
- [ ] API contracts shown (endpoints, request/response shapes)
- [ ] Configuration file references included
- [ ] C4 diagram cross-referenced
- [ ] "Why" explained, not just "what"
- [ ] Gotchas/traps noted if discovered
- [ ] No Gaps in the flow, every trivial function call, config and data store should have a bullet and hyperlink

## Related Documentation

- [exploration-guide.md](exploration-guide.md) - How to investigate flows
- [gotchas.md](gotchas.md) - Common pitfalls
- [architecture.md](architecture.md) - System overview
- [glossary.md](glossary.md) - Terminology
- [epr-assessment/specs/](https://github.com/DEFRA/epr-assessment/tree/main/specs) - Detailed service specs
