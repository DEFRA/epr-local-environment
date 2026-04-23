# epr-regulator-service (WA 411)

Regulator frontend - ASP.NET MVC web application for regulatory oversight of producer submissions.

## Purpose

Provides UI for regulators to review, approve, and reject producer packaging data submissions and registration applications.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.RegulatorService.Frontend.Web/Program.cs` | Startup, DI |
| `src/EPR.RegulatorService.Frontend.Web/Controllers/` | MVC route handlers |
| `src/EPR.RegulatorService.Frontend.Core/Services/FacadeService.cs` | All facade HTTP calls |
| `src/EPR.RegulatorService.Frontend.Web/appsettings.json` | Facade URLs, feature flags |

## Key Routes

| Route | Controller | Purpose |
|-------|------------|---------|
| `/regulators/home` | HomeController | Dashboard |
| `/regulators/manage-packaging-data-submissions` | SubmissionsController | POM review |
| `/regulators/manage-registrations` | RegistrationsController | Registration review |
| `/regulators/manage-applications` | ApplicationsController | Application management |

## Dependencies (calls)

- **epr-regulator-service-facade** (WA 406) - All backend access goes through facade
  - Config: `FacadeApiConfig.BaseUrl` in appsettings.json

## Consumers (called by)

- End users (regulators) via browser
- Azure AD B2C for authentication

## Key Patterns

- **Never calls backend APIs directly** - always via facade
- Uses `IFacadeService` for all HTTP calls
- Session data in Redis
- Razor views for UI

## Gotchas

- Some features behind `FeatureManagement` flags
- Multiple controller folders: `Controllers/` has subfolders like `Submissions/`, `Applications/`
- `FacadeService.cs` is the single point of integration - large file

## Detailed Specs

- [epr-assessment/specs/producer/regulator/frontend/epr-regulator-service-frontend-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/regulator/frontend/epr-regulator-service-frontend-specification.md)
- [epr-assessment/specs/producer/regulator/frontend/epr-regulator-service-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/regulator/frontend/epr-regulator-service-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 320-352
