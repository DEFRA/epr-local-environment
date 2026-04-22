# epr-obligationchecker-frontend (WA 401)

Public register web app - ASP.NET MVC for public-facing pages.

## Purpose

**⚠️ IMPORTANT:** Despite the name, the obligation checker functionality is **feature-flagged OFF in production**. This service currently only runs the public register webpage.

**In production:**
- Public register of producers ✅
- Public register of compliance scheme operators ✅
- Large producer list ✅

**Disabled (code exists but feature-flagged off):**
- Obligation checker wizard (do I need to register?) ❌

## Entry Points

| File | Purpose |
|------|---------|
| `src/FrontendObligationChecker/Program.cs` | Startup |
| `src/FrontendObligationChecker/Controllers/` | MVC routes |
| `src/FrontendObligationChecker/Views/` | Razor views |
| `src/FrontendObligationChecker/appsettings.json` | Config |

## Key Routes

| Route | Purpose |
|-------|---------|
| `/obligation-checker/...` | Wizard to check if registration needed |
| `/public-register` | Search approved producers |
| `/large-producers` | List of large producers |

## Data Sources

This frontend reads CSV files from blob storage - no backend API calls:

| Blob Container | Purpose |
|----------------|---------|
| `public-register-producers` | Approved producer list |
| `public-register-compliance` | Compliance scheme operators |
| `large-producers` | Large producer list |

## Dependencies (calls)

- **Azure Blob Storage** - reads CSV files directly
- No facade or backend API dependencies

## Consumers (called by)

- Public users (no authentication required for most pages)

## Key Patterns

- **Static data** - reads from pre-generated CSV files, not live database
- **GOV.UK Design System** - follows GDS patterns
- Simple MVC, minimal backend integration

## Gotchas

- **Name is misleading** - obligation checker is disabled in production, only public register runs
- **Check feature flags** - see `epr-app-config-settings` PRD files for what's actually enabled
- **No relation to `epr-prn-obligationcalculations-function`** - despite similar "obligation" name
- **Data is batch-generated** - CSVs updated periodically, not real-time
- Very simple architecture compared to other services

## Detailed Specs

- [epr-assessment/specs/producer/obligationchecker/epr-obligationchecker-frontend-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/obligationchecker/epr-obligationchecker-frontend-specification.md)
- [epr-assessment/specs/producer/obligationchecker/epr-obligationchecker-frontend-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/obligationchecker/epr-obligationchecker-frontend-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 434-458
