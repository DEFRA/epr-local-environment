# EPR Azure Architecture

The original EPR estate, hosted on Azure. Primarily in maintenance, with some ongoing change. Most new functionality lands on CDP (see [cdp-architecture.md](cdp-architecture.md)). Synapse / PowerBI reporting expected to stay on Azure for the foreseeable future. For the cross-platform overview see [architecture.md](architecture.md).

## System Overview
UK Extended Producer Responsibility (EPR) for packaging - multi-tenant microservices system managing producer registration, packaging data reporting, regulator oversight, fee calculation, and payment processing. Effective from 1 Jan 2025 under SI 2024 No. 1332.

**NOTE**: Verify assumptions against actual code. The architecture has notable constraints, including the use of Synapse (an analytics data warehouse) for OLTP-style data access. Some patterns are the result of incremental evolution rather than up-front design.

## Your Work Focus
- **Regulator services**: [epr-regulator-service](repos/epr-regulator-service.md) → [epr-regulator-service-facade](repos/epr-regulator-service-facade.md) → backends
- **Public Register / Obligation Checker**: The web app (not the unrelated func app with similar name)
- **End-to-end data flows**: Bugs/features often stated as "user uploads X... regulator sees Y"

## Core Architecture Patterns

### 3-Tier Pattern (Producer/Regulator Services)
**Frontend → Facade → Backend APIs**
- **Frontend**: ASP.NET MVC + Razor (WA 4xx series)
- **Facade**: Orchestration layer, aggregates multiple backend calls, handles auth/session
- **Backend APIs**: Domain services, owns data stores
- **Example**: [epr-regulator-service](repos/epr-regulator-service.md) → [epr-regulator-service-facade](repos/epr-regulator-service-facade.md) → [epr-pom-api-submission-status](repos/epr-pom-api-submission-status.md) + [epr-common-data-api](repos/epr-common-data-api.md)

### Event-Driven Processing
**Queue → Function → API → Database**
- File uploads trigger Service Bus messages
- Azure Functions process async validation/transformation
- Results written to CosmosDB/SQL via APIs
- **Example**: File upload → registrationDataQueue → [epr-registration-validation-function-app](repos/epr-registration-validation-function-app.md) (FA 404) → [epr-pom-api-submission-status](repos/epr-pom-api-submission-status.md) (WA 408) → CosmosDB

### Dual-Source Data Pattern
**Real-time (CosmosDB) + Analytical (Synapse) merged at facade**
- **Constraint**: Synapse has ETL delay but rich query capability; users need immediate feedback
- **Trade-off**: Synapse is a data warehouse designed for analytics, not OLTP. Using it for operational queries introduces latency, stale data risks, and complex merge logic.
- **Mitigation**: Facade fetches delta from CosmosDB (last sync time → now), overlays onto Synapse results
- **Example**: `/regulators/manage-packaging-data-submissions` - see [flows/manage-packaging-data-submissions-architecture.md](flows/manage-packaging-data-submissions-architecture.md)

## Key Services by Function

### Identity & Access
- **Azure AD B2C** (azureB2C): External user auth for producers/regulators
- [epr-backend-account-microservice](repos/epr-backend-account-microservice.md) (WA 407): User/org management, enrolment
  - Also contains [validation-data-api](repos/epr-backend-account-microservice.md) (FA 407): Separate deploy, provides org data for validation

### Data Submission & Validation
- [epr-packaging-frontend](repos/epr-packaging-frontend.md): Producer UI for packaging data submission
- [epr-pom-api-web](repos/epr-pom-api-web.md): Producer packaging data API
- [epr-pom-api-submission-status](repos/epr-pom-api-submission-status.md) (WA 408): **Event sourcing** - owns CosmosDB for submission events
- [epr-pom-func-producer-validation](https://github.com/DEFRA/epr-pom-func-producer-validation) (FA 402): Validates POM file contents
- [epr-pom-func-submission-check-splitter](https://github.com/DEFRA/epr-pom-func-submission-check-splitter) (FA 403): Splits POM files by producer ID for parallel validation
- [epr-registration-validation-function-app](repos/epr-registration-validation-function-app.md) (FA 404): Validates registration files, determines if brands/partnership files needed

### Regulator Oversight
- [epr-regulator-service](repos/epr-regulator-service.md) (WA 411): Regulator frontend - review/approve submissions
- [epr-regulator-service-facade](repos/epr-regulator-service-facade.md) (WA 406): Orchestrates dual-source queries (CosmosDB + Synapse)

### Fee Calculation & Payment
- [epr-calculator-service](https://github.com/DEFRA/epr-calculator-service): Core calculation engine for disposal fees
- [epr-calculator-api](https://github.com/DEFRA/epr-calculator-api): Calculation API
- [epr-calculator-frontend](https://github.com/DEFRA/epr-calculator-frontend): Calculator UI
- [epr-payment-service](repos/epr-payment-service.md) (WA 425): Fee calculation + payment record management, owns feesPaymentDB
- [epr-payment-facade](repos/epr-payment-facade.md): Payment orchestration
- [epr-payment-mopup](https://github.com/DEFRA/epr-payment-mopup) (FA 409): Polls GovPay for status updates, syncs to DB
- **GovPay**: External payment gateway

### PRN/PERN Management (Recycling Evidence Notes)
- [epr-prn-common-backend](https://github.com/DEFRA/epr-prn-common-backend) (WA 418): PRN data service, owns prnDB
- [epr-prn-integration-function](https://github.com/DEFRA/epr-prn-integration-function): PRN external integrations
- [epr-prn-obligationcalculations-function](https://github.com/DEFRA/epr-prn-obligationcalculations-function): Calculate recycling obligations

### Data & Analytics
- [epr-common-data-api](repos/epr-common-data-api.md) (WA 415): **Synapse-backed** analytics API - comprehensive queries, slight delay
- [epr-data-synapse](https://github.com/DEFRA/epr-data-synapse): Synapse ETL pipelines
- [epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb): SQL database definitions
- **PowerBI**: Reporting dashboards

### External Integrations (via Boomi)
- **Companies House**: Org verification
- **Postcode Lookup**: Address validation
- **NPWD**: Legacy system integration
- **FSS**: File storage service

### Cross-Cutting
- [epr-logging-api](https://github.com/DEFRA/epr-logging-api): Centralized logging API
- [epr-anti-virus-function-app](https://github.com/DEFRA/epr-anti-virus-function-app): File scanning
- [epr-common](https://github.com/DEFRA/epr-common): Shared libraries
- **GovNotify**: Email/SMS notifications

## Data Stores

### CosmosDB (NoSQL)
- **submissionDB** ({env}RWDDBSCOx401): Submission events - owned by [epr-pom-api-submission-status](repos/epr-pom-api-submission-status.md)
- **Purpose**: Event sourcing, real-time writes, change feed for deltas
- **Pattern**: Append-only events, no updates

### SQL Server
- **accountsDB**: User/org/enrolment data - owned by [epr-backend-account-microservice](repos/epr-backend-account-microservice.md)
- **feesPaymentDB**: Fee calculations + payment records - owned by [epr-payment-service](repos/epr-payment-service.md)
- **prnDB**: PRN/PERN data - owned by [epr-prn-common-backend](https://github.com/DEFRA/epr-prn-common-backend)

### Azure Synapse
- **Analytics warehouse**: ETL from CosmosDB + SQL databases
- **Access**: Via [epr-common-data-api](repos/epr-common-data-api.md) - `SynapseContext.SubmissionSummaries`
- **Trade-off**: Rich queries + history, but minutes-hours delay

### Blob Storage
- **File uploads**: Registration CSVs, POM files, brands/partnership files
- **Trigger**: Service Bus messages for async processing

### Service Bus Queues
- **registrationDataQueue**: Registration file uploads
- **pomValidationQueue**: POM file validation requests

## Key Business Domains

### Producer Journey
1. **Registration** (Y-2 Calculation Year): Determine if threshold met (£2M+ turnover, 50+ tonnes)
2. **Data Submission** (Y-1 Obligation Year): Report packaging by activity/type/class/material
3. **Fee Payment** (Y Relevant Year): Pay disposal fees + admin fees (first invoice Oct 2025)
4. **PRN Purchase**: Large producers buy recycling evidence notes to meet material targets

### Producer Classes (Multiple roles possible)
- Brand Owner, Packer/Filler, Importer, Distributor, OMP Operator, Service Provider

### Regulator Journey
1. Review submissions via [epr-regulator-service](repos/epr-regulator-service.md)
2. Approve/Reject with comments
3. Monitor compliance
4. Enforcement actions

## Testing Patterns

### Frontend Journey Tests
- [epr-playwright-bdd](https://github.com/DEFRA/epr-playwright-bdd): BDD tests across frontends
- Pattern: Feature files + Playwright

### Backend Tests
- Unit: xUnit + Moq (mockist avoided per CLAUDE.md - prefer outside-in)
- Integration: Test containers for databases

### Mock Servers
- **WireMock pattern**: See [epr-packaging-frontend MockApiServer.cs](https://github.com/DEFRA/epr-packaging-frontend/blob/79ffe0517defbdd73448996548467ca83610b272/src/FrontendSchemeRegistration.MockServer/MockApiServer.cs#L11)
- Mock facades to isolate frontend tests

## Technology Stack
- **Backend**: ASP.NET Core 6+/8+ Web APIs
- **Frontend**: ASP.NET MVC + Razor Pages
- **Functions**: Azure Functions v4 (C#)
- **Data**: SQL Server, Azure Synapse, CosmosDB
- **Messaging**: Azure Service Bus
- **Storage**: Azure Blob Storage
- **Auth**: Azure AD B2C
- **Integration**: Dell Boomi iPaaS
- **Infrastructure**: Azure, Terraform (not in this workspace)
- **CI/CD**: Azure DevOps (pipelines in separate repos)

## Naming Conventions
- **Web Apps**: WA {number} - e.g., WA 408 = {env}RWDWEBWAx408
- **Function Apps**: FA {number} - e.g., FA 404 = {env}RWDWEBFAx404
- **Resource prefix**: {env}RWDWEB... where env = DEV/TST/PRE/PRD
- **Repos**: `epr-{domain}-{type}` pattern

## C4 Architecture Diagrams
Location: [extended-producer-responsibility-docs/docs/architecture/report-packaging-data/](https://github.com/DEFRA/extended-producer-responsibility-docs/tree/main/docs/architecture/report-packaging-data)
- [`_index.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/_index.c4): Complete system overview
- [`model.producer-regulator.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4): Producer/regulator domain model
- [`view.producer-regulator.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/view.producer-regulator.c4): Producer/regulator views
- [`view.data.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/view.data.c4): Data flow views
- [`model.calc.c4`](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.calc.c4): Calculator domain
- Tags: `#DG1`, `#R16`, `#CAPRI`, etc. for delivery groups/releases

## Multi-Repo Management
Use [gitopolis](https://github.com/dwp/gitopolis) (assumed tool based on CLAUDE.md):
```bash
gitopolis list -t epr-producer          # List repos
gitopolis exec -t epr-producer -- git st # Status across repos
gitopolis exec -t epr-producer -- git pull # Update all
gitopolis exec -t epr-producer -- git rev-parse origin/main # Get SHAs for permalinks
```

## Key Dates & Milestones
- **1 Jan 2025**: EPR scheme effective (SI 2024/1332)
- **Oct 2025**: First disposal fee invoices (Y=2025, Y-1=2024 data, Y-2=2023 thresholds)
- **1 Oct 2025**: Large producer registration deadline for 2026 relevant year
- **31 Mar 2026**: Mandatory labeling (most materials)
- **2026+**: Modulated fees based on recyclability (RAM rating)

## Architectural Principles (As Designed)
- **Database ownership**: Each API owns its database - no shared DB writes
- **Facade pattern**: Never frontend → backend API direct - always via facade
- **Event sourcing**: CosmosDB for append-only events, SQL for mutable state
- **Async processing**: File validation via Functions, not synchronous
- **Dual-source merging**: Workaround for Synapse ETL delay with real-time overlay at facade
- **Outside-in testing**: Prefer integration tests over heavy mocking (per CLAUDE.md)

## Known Architectural Constraints
- **Synapse for OLTP**: Data warehouse used for operational queries - introduces latency, stale data risks, complex merge logic
- **Data across multiple stores**: Same logical data in CosmosDB, SQL, and Synapse with different schemas
- **Ownership boundaries**: Multiple services touch the same data through different paths
- **Testing approach**: Heavy mocking can obscure integration issues

## Common Gotchas
1. **Synapse delay**: Don't expect immediate data in analytics queries - use CosmosDB for real-time
2. **Multi-repo changes**: Co-ordinate facade + backend API changes across repos
3. **B2C auth**: Local dev requires B2C tenant config or mock JWT
4. **Service Bus local**: Use Azurite or real Azure resources for queue testing
5. **Git hooks**: Users may have pre-commit hooks (per CLAUDE.md warning)

## Where to Look for...
- **Business rules**: `about-epr.md` - thresholds, producer classes, fee structure
- **Data flows**: `flows/` directory - traced multi-service flows and documentation examples
- **System diagrams**: [C4 diagrams](https://github.com/DEFRA/extended-producer-responsibility-docs/tree/main/docs/architecture/report-packaging-data)
- **API contracts**: `{repo}/src/{project}.Api/Controllers/` - ASP.NET controllers
- **Database schema**: `epr-data-sqldb` repo (SQL), CosmosDB discovered via code
- **Configuration**: `appsettings.json` - BaseUrl configs, feature flags
- **Authentication**: Azure AD B2C config in app settings, claims in controllers
- **Queue processing**: `{function-repo}/src/Functions/*.cs` - Azure Function triggers
