# epr-regulator-service-facade (WA 406)

Regulator orchestration facade - aggregates calls to multiple backend APIs for the regulator frontend.

## Purpose

Orchestrates data from CosmosDB (real-time) and Synapse (analytics), merges them, and provides unified API for regulator frontend. Handles dual-source merge pattern.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.RegulatorService.Facade.API/Program.cs` | Startup, DI |
| `src/EPR.RegulatorService.Facade.API/Controllers/` | API endpoints |
| `src/EPR.RegulatorService.Facade.Core/Services/` | Business logic, backend orchestration |
| `src/EPR.RegulatorService.Facade.API/appsettings.json` | Backend API URLs |

## Key Endpoints

| Endpoint | Controller | Purpose |
|----------|------------|---------|
| `GET /api/pom/get-submissions` | SubmissionsController | Dual-source POM submissions |
| `POST /api/pom/regulator-decision` | SubmissionsController | Record decision |
| `GET /api/registrations/get-submissions` | RegistrationsController | Registration submissions |
| `POST /api/regulators/accounts/govNotification` | ApplicationController | Send notifications |

## Dependencies (calls)

| Service | Purpose | Config Key |
|---------|---------|------------|
| epr-pom-api-submission-status (WA 408) | CosmosDB events | `SubmissionsApiConfig` |
| epr-common-data-api (WA 415) | Synapse queries | `CommonDataApiConfig` |
| epr-backend-account-microservice (WA 407) | User/org data | `AccountsApiConfig` |
| epr-payment-service (WA 425) | Fee data | `PaymentServiceApiConfig` |
| GovNotify | Email notifications | `MessagingConfig` |

## Consumers (called by)

- **epr-regulator-service** (WA 411) - Regulator frontend

## Key Patterns

### Dual-Source Merge

The signature pattern of this facade. For submissions:
1. Get `LastSyncTime` from common-data-api
2. Get delta from submission-status-api (CosmosDB) since last sync
3. Get paginated data from common-data-api (Synapse)
4. Merge delta onto Synapse results
5. Return combined, up-to-date data

See [flows/manage-packaging-data-submissions-architecture.md](../flows/manage-packaging-data-submissions-architecture.md) for details.

## Gotchas

- **`SubmissionsService`** - talks to CosmosDB (WA 408), not "all submissions"
- **`CommonDataService`** - talks to Synapse (WA 415), despite generic name
- Services in `Core/Services/` are named by backend, not by domain
- Heavy use of AutoMapper for DTO transformations

## Detailed Specs

- [epr-assessment/specs/producer/regulator/facade/epr-regulator-service-facade-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/regulator/facade/epr-regulator-service-facade-specification.md)
- [epr-assessment/specs/producer/regulator/facade/epr-regulator-service-facade-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/regulator/facade/epr-regulator-service-facade-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 369-408
