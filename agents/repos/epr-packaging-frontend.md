# epr-packaging-frontend (WA 410)

Producer frontend - ASP.NET MVC web app for producers to submit packaging data.

## Purpose

Main producer-facing UI for:
- POM (packaging materials) file upload
- Registration file upload
- Submission status viewing
- PRN management

## Entry Points

| File | Purpose |
|------|---------|
| `src/FrontendSchemeRegistration.UI/Program.cs` | Startup |
| `src/FrontendSchemeRegistration.UI/Controllers/` | MVC routes |
| `src/FrontendSchemeRegistration.Application/Services/` | Facade client calls |
| `src/FrontendSchemeRegistration.UI/appsettings.json` | Facade URLs |

## Key Routes

| Route | Purpose |
|-------|---------|
| `/report-data/home` | Dashboard |
| `/report-data/upload-pom-data` | POM file upload |
| `/report-data/upload-organisation-details` | Registration upload |
| `/report-data/submissions` | View submission status |

## Dependencies (calls)

| Service | Purpose | Config Key |
|---------|---------|------------|
| epr-pom-api-web (WA 409) | Producer facade | `PomApiConfig` |
| epr-payment-facade (WA 424) | Payment initiation | `PaymentApiConfig` |
| epr-facade-account-microservice (WA 404) | Account operations | `AccountApiConfig` |

## Consumers (called by)

- Producer users via browser
- Azure AD B2C for authentication

## Key Patterns

- **GOV.UK Design System** - follows GDS patterns
- Multiple file upload flows (POM, registration, brands, partnership)
- Session in Redis

## Mock Server

Has a mock facade for testing:
`src/FrontendSchemeRegistration.MockServer/MockApiServer.cs`

## Gotchas

- Project name is `FrontendSchemeRegistration` not `PackagingFrontend`
- Multiple upload types: POM, registration, brands, partnership files
- Complex file validation flow (async via functions)

## Detailed Specs

- [epr-assessment/specs/producer/packaging/epr-packaging-frontend-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/packaging/epr-packaging-frontend-specification.md)
- [epr-assessment/specs/producer/packaging/epr-packaging-frontend-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/packaging/epr-packaging-frontend-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 243-271
