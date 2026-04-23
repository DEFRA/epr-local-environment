# epr-common-data-api (WA 415)

Synapse analytics API - provides query access to the analytics data warehouse.

## Purpose

Exposes Synapse (data warehouse) data via REST API. Used for complex queries, filtering, pagination on denormalized submission data. Has ETL delay (not real-time).

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.CommonDataService.Api/Program.cs` | Startup |
| `src/EPR.CommonDataService.Api/Controllers/` | API endpoints |
| `src/EPR.CommonDataService.Core/Services/` | Business logic |
| `src/EPR.CommonDataService.Data/Infrastructure/SynapseContext.cs` | Synapse EF Core context |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/submissions/pom/summary` | POM submissions with delta merge |
| `POST /api/submissions/registrations/summary` | Registration submissions |
| `GET /api/submission-events/get-last-sync-time` | Last ETL sync timestamp |
| `GET /api/organisations/{id}` | Organisation data |

## Database

**Azure Synapse** - Analytics data warehouse
- EF Core context: `SynapseContext`
- DbSet: `SubmissionSummaries` (`DbSet<PomSubmissionSummaryRow>`)

### Key Tables/Views

- `SubmissionSummaries` - Denormalized POM submission data
- `RegistrationSummaries` - Denormalized registration data
- `OrganisationDetails` - Organisation lookup

## Dependencies (calls)

- **Azure Synapse** - via EF Core

## Consumers (called by)

| Consumer | Purpose |
|----------|---------|
| epr-regulator-service-facade (WA 406) | Submissions queries, last sync time |
| epr-pom-api-web (WA 409) | Producer data queries |

## Key Patterns

- **Delta merge at consumer** - this API returns Synapse data; consumer (facade) merges with CosmosDB delta
- Request includes `DecisionsDelta` - recent decisions to overlay on Synapse results
- EF Core for Synapse access

## Gotchas

- **Name is misleading** - "common data" sounds generic but it's specifically Synapse analytics
- **Data is delayed** - Synapse ETL runs periodically, not real-time
- **Delta merge happens here** - `DecisionsDelta` in request body is overlaid before returning
- `GetLastSyncTime` returns when Synapse was last updated - used to fetch delta from CosmosDB

## Key Constraint

Synapse (OLAP) is used here for operational queries (OLTP):
- Minutes-to-hours delay on data
- Complex delta merge logic needed
- Performance not optimised for frequent small queries

## Detailed Specs

- [epr-assessment/specs/obligations/data/epr-common-data-api-operability-assessment.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/obligations/data/epr-common-data-api-operability-assessment.md)
- [epr-assessment/specs/obligations/data/epr-common-data-api-qa-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/obligations/data/epr-common-data-api-qa-specification.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) - referenced as `dataReporting.commonDataAPI`
