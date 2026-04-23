# epr-registration-validation-function-app (FA 404)

Registration validation function - validates uploaded registration CSV files.

## Purpose

Azure Function triggered by Service Bus when a registration file is uploaded. Validates the file and determines if additional uploads (brands, partnership files) are needed.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.RegistrationValidation.Functions/Functions/` | Function triggers |
| `src/EPR.RegistrationValidation.Application/` | Business logic |
| `src/EPR.RegistrationValidation.Application/Clients/` | API clients |
| `host.json` | Function configuration |

## Key Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `RegistrationDataFunction` | ServiceBusTrigger (`registrationDataQueue`) | Main validation entry |

## Flow

1. Producer uploads registration CSV via frontend
2. Blob storage write triggers Service Bus message
3. This function receives message from `registrationDataQueue`
4. Fetches file from blob storage
5. Validates CSV structure and content
6. Checks org data via validation-data-api (FA 407)
7. Determines if brands/partnership files needed
8. Writes validation event to submission-status-api (WA 408)

## Dependencies (calls)

| Service | Purpose |
|---------|---------|
| epr-pom-api-submission-status (WA 408) | Write validation events |
| validation-data-api (FA 407) | Org data for validation |
| Azure Blob Storage | Read uploaded files |

## Consumers (called by)

- **Service Bus** - `registrationDataQueue`

## Key Patterns

- Async validation triggered by queue
- Validation rules in `Application/` layer
- Results written as events to CosmosDB (via WA 408)

## Gotchas

- **FA 404** not to be confused with WA 404 (account facade)
- Works with validation-data-api (FA 407), not main account API (WA 407)
- Determines need for follow-up uploads (brands, partnership)

## Detailed Specs

- [epr-assessment/specs/producer/registration-validation/epr-registration-validation-function-app-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/registration-validation/epr-registration-validation-function-app-specification.md)
- [epr-assessment/specs/producer/registration-validation/epr-registration-validation-function-app-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/registration-validation/epr-registration-validation-function-app-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 109-129
