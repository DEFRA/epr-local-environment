# EPR Codebase Exploration Guide

Strategies for investigating bugs, features, and data flows in this multi-repo legacy system.

## Starting Points by Task Type

### "Where does X happen?"

1. **Start with C4 diagrams** - the most reliable source of service connections
   ```sh
   # Find which services are involved
   grep -r "X" extended-producer-responsibility-docs/docs/architecture/report-packaging-data/*.c4
   ```

2. **Find the frontend route** - user-facing features start here
   ```sh
   # ASP.NET MVC routes
   grep -r "X" */src/*/Controllers/*.cs
   ```

3. **Trace via appsettings.json** - find downstream service URLs
   ```sh
   # Look for BaseUrl configs pointing to other services
   grep -r "BaseUrl" */src/*/appsettings.json
   ```

4. **Follow the facade** - frontends never call backends directly

### "Why isn't Y showing up?"

**First question: Is this a Synapse delay issue?**

- If data was just created/updated → likely not in Synapse yet
- Check if the feature uses dual-source pattern (CosmosDB + Synapse merge)
- See [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md) for how delta merging works

**Check the data flow:**
1. Was the event written to CosmosDB? (WA 408)
2. Did Synapse ETL run? (epr-data-synapse pipelines)
3. Is the facade merging correctly? (check delta logic)

### "How do I add a field to the regulator view?"

Typical change path (regulator side):
1. **epr-regulator-service** - Add to view model, Razor view
2. **epr-regulator-service-facade** - Add to response DTO, map from backend
3. **epr-common-data-api** - Add to Synapse query if from analytics
4. **epr-pom-api-submission-status** - Add to CosmosDB event if real-time
5. **epr-data-synapse** - Add ETL mapping if new Synapse field

### "What calls this API endpoint?"

```sh
# Find consumers by endpoint path
grep -r "/api/path/here" */src/**/*.cs

# Check C4 for service relationships
grep -r "serviceName" extended-producer-responsibility-docs/docs/architecture/**/*.c4
```

## Service Discovery

### Finding a Service by Feature

1. **Check C4 model** for service ownership:
   ```sh
   # Find service by keyword
   grep -ri "keyword" extended-producer-responsibility-docs/docs/architecture/report-packaging-data/model.*.c4
   ```

2. **Look up WA/FA number** in [glossary.md](glossary.md) or [epr-assessment/specs/producer/epr-producer-repositories.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/epr-producer-repositories.md)

3. **Search epr-assessment** for detailed specs:
   ```sh
   ls epr-assessment/specs/producer/
   # e.g., epr-assessment/specs/producer/regulator/facade/epr-regulator-service-facade-specification.md
   ```

### Finding Database Ownership

**Rule: Each API owns its database - find the owner first.**

| Database | Owner Service | C4 Reference |
|----------|---------------|--------------|
| CosmosDB (submissions) | WA 408 epr-pom-api-submission-status | [model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) line ~17 |
| accountsDB | WA 407 epr-backend-account-microservice | [model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) line ~65 |
| feesPaymentDB | WA 425 epr-payment-service | [model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) line ~44 |

### Finding Queue Consumers

```sh
# Find Service Bus trigger functions
grep -r "ServiceBusTrigger" */src/**/*.cs

# Check C4 for queue relationships
grep -r "Queue\|subscribesTo\|publishesTo" extended-producer-responsibility-docs/docs/architecture/**/*.c4
```

## Code Patterns to Recognize

### 3-Tier Flow (Frontend → Facade → Backend)

```
epr-{domain}-service (frontend)
    ↓ calls via HttpClient
epr-{domain}-service-facade (orchestration)
    ↓ calls multiple backends
epr-{something}-api (owns data)
```

**Find the chain:**
```sh
# Frontend appsettings → facade URL
grep -r "FacadeApiBaseUrl\|ServiceFacade" epr-*/src/*/appsettings.json

# Facade appsettings → backend URLs
grep -r "ApiConfig\|BaseUrl" epr-*-facade/src/*/appsettings.json
```

### Dual-Source Pattern (CosmosDB + Synapse)

When you see facade code calling both:
- `_submissionService.GetDelta...()` → CosmosDB real-time
- `_commonDataService.Get...()` → Synapse analytics

The facade merges them to show up-to-date data with rich querying.

### Event Sourcing (CosmosDB)

Events are append-only in CosmosDB. Look for:
- `SubmissionEvent` types
- `EventType` enum values
- `Created` timestamps for ordering

## Debugging Workflows

### Trace a User Action End-to-End

1. **Find frontend controller** handling the route
2. **Find facade service call** in frontend's service layer
3. **Find facade controller** for that endpoint
4. **Find backend service calls** in facade's service layer
5. **Find database access** in backend's repository/handler

### Find Where Data is Transformed

DTOs change shape at each layer boundary:
- Frontend: `ViewModel` / `Model`
- Facade: `Request` / `Response` / `Dto`
- Backend: `Entity` / `Event` / `Row`

Search for AutoMapper profiles or manual mappings:
```sh
grep -r "CreateMap\|\.Map<" */src/**/*.cs
```

### Check Feature Flags

Some features are gated:
```sh
grep -r "FeatureManager\|IsEnabled" */src/**/*.cs
grep -r "FeatureManagement" */src/*/appsettings.json
```

## Multi-Repo Operations

### Check Status Across Repos

```sh
gitopolis exec -t epr-producer --oneline -- git status
gitopolis exec -t epr-producer --oneline -- git branch
```

### Get SHAs for Permalinks

```sh
gitopolis exec -t epr-producer -- git rev-parse origin/main
```

### Pull All Repos

```sh
gitopolis exec -t epr-producer -- git pull
```

## Key Files to Check

### Per Service Type

**Frontends (ASP.NET MVC):**
- `Program.cs` - startup, DI registration
- `Controllers/*.cs` - route handlers
- `Services/*Service.cs` - facade client calls
- `Views/**/*.cshtml` - Razor templates
- `appsettings.json` - facade URLs, feature flags

**Facades (Web API):**
- `Program.cs` - startup
- `Controllers/*.cs` - API endpoints
- `Services/*.cs` - backend orchestration
- `appsettings.json` - backend API URLs

**Backend APIs:**
- `Controllers/*.cs` - endpoints
- `Handlers/*.cs` or `Services/*.cs` - business logic
- `Data/*.cs` or `Infrastructure/*.cs` - database access
- Entity/model definitions

**Azure Functions:**
- `Functions/*.cs` - trigger handlers
- `host.json` - function config
- Look for `[ServiceBusTrigger]`, `[TimerTrigger]`, etc.

### Configuration Patterns

```sh
# Find all API endpoint configs
grep -r "BaseUrl\|Endpoint" */src/*/appsettings.json

# Find connection strings (won't have real values)
grep -r "ConnectionString" */src/*/appsettings.json
```

## Using Existing Documentation

### epr-assessment Specs

Detailed reverse-engineered specs exist for most services:
```
epr-assessment/specs/producer/{domain}/{service-name}-specification.md
epr-assessment/specs/producer/{domain}/{service-name}-operability-assessment.md
```

**Example paths:**
- `epr-assessment/specs/producer/regulator/facade/epr-regulator-service-facade-specification.md`
- `epr-assessment/specs/producer/regulator/frontend/epr-regulator-service-frontend-specification.md`
- `epr-assessment/specs/producer/pom/api/submission-status/epr-pom-api-submission-status-service-specification.md`

### [C4 Diagrams](https://github.com/DEFRA/extended-producer-responsibility-docs/tree/main/docs/architecture/report-packaging-data)

- [`_index.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/_index.c4) - Main entry point
- [`model.producer-regulator.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) - Service definitions with GitHub links
- [`view.producer-regulator.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/view.producer-regulator.c4) - Visual diagrams
- [`model.data.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.data.c4) - Data layer

**C4 contains:**
- Service names and Azure resource IDs
- GitHub repo links
- Database ownership (`owns this database`)
- Service relationships (`.uses`, `.readWrite`, `.publishesTo`)
- Tags for delivery groups (`#DG1`, `#R16`, etc.)

### Previous Analysis

Check `flows/*.md` for prior traced flows - avoids re-discovering complex multi-service paths from scratch.

## Common Pitfalls

1. **Don't trust service names** - `SubmissionsService` in facade talks to CosmosDB, not "submissions" in general
2. **Don't assume direct paths** - always check for facade layer
3. **Don't expect immediate data** - Synapse has ETL delay
4. **Check for multiple deploys** - some repos deploy multiple services (e.g., WA 407 + FA 407)
5. **Verify C4 accuracy** - if you find discrepancies, note them for correction
