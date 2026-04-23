# epr-backend-account-microservice (WA 407 + FA 407)

Account API and validation data API - **two services in one repo**.

## Purpose

**WA 407 - Backend Account Service API**: User and organisation account management, enrolment workflows.

**FA 407 - Validation Data API**: Provides organisation data for validation functions. Separate deployment.

## Repo Structure

```
src/
├── BackendAccountService.Api/          # WA 407
├── BackendAccountService.Core/         # Shared business logic
├── BackendAccountService.Data/         # Database access
└── BackendAccountService.ValidationData.Api/  # FA 407 (separate deploy)
```

## WA 407 - Account Service API

### Entry Points

| File | Purpose |
|------|---------|
| `src/BackendAccountService.Api/Program.cs` | Startup |
| `src/BackendAccountService.Api/Controllers/` | API endpoints |

### Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/accounts/{id}` | Get user account |
| `POST /api/organisations` | Create organisation |
| `POST /api/enrolments` | Create enrolment |
| `PUT /api/enrolments/{id}/approve` | Approve enrolment |

### Database

**SQL Server** - `accountsDB`
- Users, Organisations, Enrolments
- Person-Organisation relationships
- Roles and permissions

## FA 407 - Validation Data API

### Entry Points

| File | Purpose |
|------|---------|
| `src/BackendAccountService.ValidationData.Api/Program.cs` | Startup |
| `src/BackendAccountService.ValidationData.Api/Controllers/` | API endpoints |

### Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/organisations/{reference}` | Get org for validation |

### Purpose

Read-only access to account data for validation functions (FA 404, FA 402, etc.) to validate organisation references in uploaded files.

## Dependencies (calls)

- **accountsDB** (SQL Server) - owns this database

## Consumers (called by)

**WA 407:**
| Consumer | Purpose |
|----------|---------|
| epr-facade-account-microservice (WA 404) | Account operations |
| epr-regulator-service-facade (WA 406) | User/org queries |

**FA 407:**
| Consumer | Purpose |
|----------|---------|
| epr-registration-validation-function-app (FA 404) | Org validation |
| epr-pom-func-producer-validation (FA 402) | Org validation |

## Gotchas

- **Two services, one repo** - don't confuse them
- FA 407 is read-only, WA 407 is read-write
- Both share `Core` and `Data` projects
- Separate deployment pipelines

## Detailed Specs

- [epr-assessment/specs/producer/account/backend/epr-backend-account-microservice-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/account/backend/epr-backend-account-microservice-specification.md)
- [epr-assessment/specs/producer/account/backend/epr-backend-account-microservice-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/account/backend/epr-backend-account-microservice-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 49-85 (both services)
