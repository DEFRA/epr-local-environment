# epr-pom-api-web (WA 409)

Producer facade - orchestrates backend calls for the producer frontend (epr-packaging-frontend).

## Purpose

Gateway/facade for producer frontend. Aggregates calls to submission status API, account API, PRN API, and handles file uploads.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.POM.Api.Web/Program.cs` | Startup |
| `src/EPR.POM.Api.Web/Controllers/` | API endpoints |
| `src/EPR.POM.Api.Web/Services/` | Backend orchestration |
| `src/EPR.POM.Api.Web/appsettings.json` | Backend API URLs |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/submissions` | Create submission |
| `POST /api/submissions/{id}/upload` | Upload file |
| `GET /api/submissions/{id}` | Get submission status |
| `GET /api/prn/...` | PRN operations |

## Dependencies (calls)

| Service | Purpose | Config Key |
|---------|---------|------------|
| epr-pom-api-submission-status (WA 408) | Submission events | `SubmissionsApiConfig` |
| epr-backend-account-microservice (WA 407) | Account data | `AccountApiConfig` |
| epr-prn-common-backend (WA 418) | PRN data | `PrnApiConfig` |
| epr-common-data-api (WA 415) | Analytics queries | `CommonDataApiConfig` |
| epr-anti-virus-function-app (FA 405) | File scanning | `AntivirusApiConfig` |
| Azure Blob Storage | File storage | `StorageAccountConfig` |

## Consumers (called by)

- **epr-packaging-frontend** (WA 410) - Producer frontend

## Key Patterns

- File upload → Blob storage → Service Bus message → Async validation
- Combines data from multiple backends
- Handles file download with AV scanning

## Gotchas

- **Name is confusing** - "pom-api-web" sounds like a web app, but it's an API (facade)
- Distinct from `epr-pom-api-submission-status` despite similar name
- Handles more than just POM - also registration, PRN

## Detailed Specs

- [epr-assessment/specs/producer/pom/api/web/epr-pom-api-web-service-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/pom/api/web/epr-pom-api-web-service-specification.md)
- [epr-assessment/specs/producer/pom/api/web/epr-pom-api-web-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/pom/api/web/epr-pom-api-web-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 272-319
