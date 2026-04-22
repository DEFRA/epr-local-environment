# epr-pom-api-submission-status (WA 408)

CosmosDB event store - owns submission events for both POM and registration files.

## Purpose

Event-sourced data store for all submission lifecycle events. Append-only - events are never updated, only new events added. Provides real-time data for dual-source merge pattern.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.SubmissionMicroservice.API/Program.cs` | Startup |
| `src/EPR.SubmissionMicroservice.API/Controllers/` | API endpoints |
| `src/EPR.SubmissionMicroservice.Application/Features/` | CQRS handlers |
| `src/EPR.SubmissionMicroservice.Data/` | CosmosDB access |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /v1/submissions` | Create submission |
| `POST /v1/submissions/{id}/events` | Add event to submission |
| `GET /v1/submissions/events/get-regulator-pom-decision` | Delta for dual-source merge |
| `GET /v1/submissions/{id}` | Get submission with events |

## Database

**CosmosDB** - `{env}RWDDBSCOx401`
- Container: submissions
- Partition key: organisation ID
- Document type: SubmissionEvent

### Event Types

```csharp
public enum EventType
{
    AntivirusCheck = 1,
    CheckSplitter = 2,
    ProducerValidation = 3,
    AntivirusResult = 4,
    // ...
    RegulatorPoMDecision = 7,
    RegulatorRegistrationDecision = 10,
    // ...
}
```

## Dependencies (calls)

- **CosmosDB** - owns this database

## Consumers (called by)

| Consumer | Purpose |
|----------|---------|
| epr-regulator-service-facade (WA 406) | Delta queries, write decisions |
| epr-pom-api-web (WA 409) | Producer submission events |
| epr-registration-validation-function-app (FA 404) | Write validation events |
| epr-pom-func-producer-validation (FA 402) | Write validation events |

## Key Patterns

- **Event Sourcing** - append-only, no updates
- **CQRS** - separate command/query handlers in `Features/`
- Mediator pattern via MediatR

## Gotchas

- **Name is misleading** - handles ALL submissions, not just POM
- **"Status" is derived** - current status is computed from event history
- Events have `Created` timestamp for ordering
- `LastSyncTime` queries rely on `Created` field

## Detailed Specs

- [epr-assessment/specs/producer/pom/api/submission-status/epr-pom-api-submission-status-service-specification.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/pom/api/submission-status/epr-pom-api-submission-status-service-specification.md)
- [epr-assessment/specs/producer/pom/api/submission-status/epr-pom-api-submission-status-readme.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/pom/api/submission-status/epr-pom-api-submission-status-readme.md)

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 7-21
