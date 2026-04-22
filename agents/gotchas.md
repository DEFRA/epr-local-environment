# EPR Gotchas

Things that trip up new investigators. Verify patterns and assumptions against actual code.

## Fundamental Architecture Characteristics

### Extensive Feature Flag & Config Use

**The Problem:** Extensive use of feature flags and configuration. Behaviour depends on runtime config, not just code, which makes debugging harder.

**Where to check:** `epr-app-config-settings` repo - look at `PRD` files for current production settings.

**Consequence:** You may trace code that's disabled in production, or miss code that's enabled only in certain environments. Always verify feature flags before assuming code paths are active.

### SonarQube-Influenced Patterns

**The Problem:** Some code patterns exist to satisfy SonarQube metrics. This can result in additional abstraction layers that make code harder to trace.

**Symptoms:**
- Interfaces with single implementations
- Additional layering/indirection
- Code structure that seems to serve no clear purpose

**When investigating:** If code structure seems unexpectedly complex, it may be metric-compliance driven. Don't assume there's always a domain reason for every abstraction.

### Variable Naming & Readability Issues

**The Problem:** Variable names can be misleading or change meaning mid-function, and logic can be difficult to follow. Code may behave differently from what a surface reading suggests.

**Example:** In [`PublicRegisterController.cs`](https://github.com/DEFRA/epr-obligationchecker-frontend/blob/0179006a3a8071920b38674c00b3a0ba38f3af04/src/FrontendObligationChecker/Controllers/PublicRegisterController.cs#L110-L111), `currentYear` gets reassigned to `previousYear` mid-function, then `nextYear` is recalculated based on that. The variable names no longer reflect their values, even though the behavior is correct.

**Important:** This was a QA-driven project. Don't assume existing code doesn't meet requirements just because it's hard to read. Behaviour may be correct even when the code is confusing. Characterization tests (if they exist) prove what the code actually does.

**Approach:**
1. Don't trust variable names - trace actual values
2. Write characterization tests before changing anything
3. Verify behaviour, not just code reading

### Synapse Used for OLTP

**The Problem:** Azure Synapse is a data warehouse designed for analytics (OLAP), not transactional queries (OLTP). This system uses it for operational UI queries.

**Consequences:**
- Minutes-to-hours delay on data appearing in queries
- Complex dual-source merge logic at facades
- Race conditions between "real-time" and "analytics" data
- Additional complexity to bridge the latency gap

**Mitigation in use:** Facades fetch delta from CosmosDB and overlay onto Synapse results. See [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md).

### Data Scattered Across Stores

The same logical data exists in multiple places with different schemas:
- CosmosDB: Event-sourced, real-time
- SQL Server: Normalized, mutable
- Synapse: Denormalized, delayed

Don't assume consistency - data may be in one store but not another.

## Naming Traps

### Service Names That Mislead

| Name | What You'd Expect | What It Actually Is |
|------|-------------------|---------------------|
| `epr-common-data-api` | Common/shared data | Synapse analytics API (not "common" to all) |
| `epr-pom-api-submission-status` | POM submission status | CosmosDB event store for ALL submissions |
| `SubmissionsService` (in facade) | All submissions logic | Just the CosmosDB delta fetch |
| `CommonDataService` (in facade) | Common data | Synapse query service |
| `epr-backend-account-microservice` | One microservice | TWO services in one repo (WA 407 + FA 407) |

### Confusing Similar Names

| Name A | Name B | Difference |
|--------|--------|------------|
| `epr-common` | `epr-common-data-api` | Shared libraries vs Synapse API |
| `epr-obligationchecker-frontend` | `epr-prn-obligationcalculations-function` | Completely different - web UI vs PRN calculations |

**Special case - `epr-obligationchecker-frontend`:** Despite the name, the obligation checker functionality is **feature-flagged OFF in production**. This service currently only runs the public register webpage. The obligation checking wizard code exists but is disabled.
| `epr-pom-api-web` | `epr-pom-api-submission-status` | Producer facade vs event store |

### WA/FA Numbers to Remember

The WA/FA numbering doesn't follow logical patterns:

| Number | What It Suggests | What It Is |
|--------|------------------|------------|
| WA 407 | Some web app | Account API (backend, not UI) |
| FA 407 | Related to WA 407? | Yes - validation-data-api, same repo! |
| WA 409 | After 408? | Producer facade (not related to 408) |

## Code Patterns That Look Wrong But Aren't

### Duplicate DTOs Everywhere

You'll see nearly identical classes like:
- `PomSubmissionSummary` in facade
- `PomSubmissionSummaryResponse` in backend
- `PomSubmissionSummaryRow` in data layer

**This is intentional** - each layer has its own model to allow independent evolution. But it makes tracing data painful.

### Multiple appsettings.json with Same Keys

Different files, same structure:
- `appsettings.json` - base
- `appsettings.Development.json` - local dev
- `appsettings.Production.json` - prod overrides

Real connection strings are in Azure App Configuration, not these files.

### HttpClient Factories with Confusing Names

```csharp
services.AddHttpClient("SubmissionsApi", ...)  // → CosmosDB service
services.AddHttpClient("CommonDataApi", ...)   // → Synapse service
```

The names don't match the actual purpose.

## Architecture Surprises

### Frontends Never Call Backend APIs Directly

**Always:** Frontend → Facade → Backend(s)

Even if it seems simpler to call directly. If you see direct calls, it's either:
- A bug
- Technical debt to fix
- A special case that should be documented

### Two Services in One Repo

`epr-backend-account-microservice` contains:
- **WA 407**: Backend Account Service API
- **FA 407**: Validation Data API

They share code but deploy separately. Check the `src/` folders.

### Same Frontend, Multiple Deployments

`epr-frontend-accountmanagement-microservice` deploys as:
- **WA 405**: Producer account management
- **WA 412**: Regulator account management

Same code, different config, different URLs.

### CosmosDB is Event-Sourced

Data in CosmosDB (WA 408) is append-only events, not current state.

To find current state:
1. Query all events for a submission
2. Replay/reduce to current state

Or use Synapse which has pre-computed current state (but delayed).

## Testing Gotchas

### Mockist Testing Approach

The codebase uses mockist testing patterns. Be aware:
- Unit tests may pass while integration fails
- Mocks may not match current API behaviour
- Changes can break production without failing tests

Prefer outside-in/integration tests where possible.

### Local Dev Requires Azure Resources

Many services need real Azure resources even for local dev:
- Azure AD B2C for auth
- Service Bus for queues (or Azurite)
- Blob Storage

Mock servers exist for some facades - check for `MockServer` projects.

## Data Flow Gotchas

### Registration vs POM Validation

Different validation functions:
- **FA 404** `epr-registration-validation-function-app`: Registration files
- **FA 402** `epr-pom-func-producer-validation`: POM files
- **FA 403** `epr-pom-func-submission-check-splitter`: Splits POM by producer

Don't confuse them - they handle different file types.

### Synapse ETL is Not Real-Time

When investigating "missing data":
1. Was it written to source DB? (CosmosDB, SQL)
2. Did Synapse ETL run since then?
3. Is the facade using dual-source merge?

Synapse can be hours behind.

### Feature Flags Hide Functionality

Some features are behind flags:
```csharp
if (await _featureManager.IsEnabledAsync("ReprocessorExporter"))
```

If a feature "doesn't exist", check for feature flags before assuming the code is missing.

## Common Investigation Mistakes

### Assuming C4 is Complete

C4 diagrams are the best source but:
- May have `#TODO` markers for uncertain relationships
- May be out of date for recent changes
- Some services have `???` descriptions

**If you find errors, note them** - C4 should be corrected.

### Grepping Without Context

Searching for `Submission` returns thousands of hits. Be specific:
- Search for method names
- Search within specific services
- Use file patterns: `*/Controllers/*.cs`

### Ignoring the Facade Layer

If you can't find where something happens:
1. Check you're looking at the facade, not backend
2. Check you're looking at the correct facade (producer vs regulator)

### Trusting README Files

Many repos have minimal or outdated READMEs. Use:
1. C4 diagrams
2. `epr-assessment/specs/` documentation
3. Code inspection

In that order of reliability for understanding purpose.

## C4 Diagram Notes

### Reading C4 Relationships

```c4
serviceA .readWrite serviceB { title "description" }
serviceA .uses serviceB { title "description" }
serviceA .subscribesTo queue { }
serviceA .publishesTo queue { }
```

The `.owns` or "owns this database" comments indicate true ownership.

### Finding GitHub Links

C4 elements contain repo links:
```c4
link https://github.com/DEFRA/epr-regulator-service "github"
```

Use these to navigate to actual code.

### Tags in C4 Diagrams

- `#R16`, `#CAPRI`, `#CAPRI_II` etc. - **Release names** (newer practice). Services tagged for specific releases.
- `#DG1` - **Old delivery group tag**. Legacy tag, not actively used.

Tags may be stale - use as hints, not authoritative source.
