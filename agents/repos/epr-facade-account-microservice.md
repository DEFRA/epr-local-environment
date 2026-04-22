# epr-facade-account-microservice (WA 404)

Account facade - orchestrates account operations for frontends.

## Purpose

Facade for account-related operations. Sits between frontends and backend account API. Handles Companies House lookup, postcode lookup, and GovNotify emails.

## Entry Points

| File | Purpose |
|------|---------|
| `src/FacadeAccountCreation/Program.cs` | Startup |
| `src/FacadeAccountCreation/Controllers/` | API endpoints |
| `src/FacadeAccountCreation/Core/Services/` | Backend orchestration |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/accounts` | Create account |
| `GET /api/companies/{number}` | Companies House lookup |
| `GET /api/addresses/postcode/{postcode}` | Postcode lookup |
| `POST /api/notifications/email` | Send email via GovNotify |

## Dependencies (calls)

| Service | Purpose |
|---------|---------|
| epr-backend-account-microservice (WA 407) | Account CRUD |
| Boomi - Companies House | Company lookup |
| Boomi - Postcode Lookup | Address lookup |
| GovNotify | Email notifications |

## Consumers (called by)

| Consumer | Purpose |
|----------|---------|
| epr-packaging-frontend (WA 410) | Account operations |
| epr-frontend-accountcreation-microservice (WA 402) | Account creation |
| epr-frontend-accountmanagement-microservice (WA 405/412) | Account management |

## Key Patterns

- External integrations (Companies House, postcodes) via Boomi
- Email sending via GovNotify
- Simple pass-through for most account operations

## Gotchas

- **WA 404** - not related to FA 404 (registration validation function)
- Project name is `FacadeAccountCreation` not `FacadeAccountMicroservice`
- Has separate regulator deployment as WA 413

## Detailed Specs

- [epr-assessment/specs/producer/account/facade/epr-facade-account-creation-microservice-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/account/facade/epr-facade-account-creation-microservice-specification.md)
- [epr-assessment/specs/producer/account/facade/epr-facade-account-microservice-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/account/facade/epr-facade-account-microservice-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 508-531
