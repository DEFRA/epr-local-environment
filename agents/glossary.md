# EPR Glossary

Quick reference for terminology used across the EPR codebase.

## Business Terms

| Term | Full Name | Description |
|------|-----------|-------------|
| **EPR** | Extended Producer Responsibility | UK scheme making producers responsible for packaging waste costs |
| **POM** | Packaging Materials / Producer Obligations Materials | The main data file producers submit with packaging tonnage |
| **PRN** | Packaging Recovery Note | Evidence notes proving recycling targets met (UK domestic) |
| **PERN** | Packaging Export Recovery Note | PRN equivalent for exported packaging waste |
| **CSO** | Compliance Scheme Operator | Organisation that manages EPR compliance on behalf of producers |
| **OMP** | Online Marketplace | Platform facilitating non-UK sales into UK (e.g., Amazon) |
| **RAM** | Recyclability Assessment Methodology | System for rating packaging recyclability (affects fees from 2026) |

## Year Terminology

The scheme uses overlapping 3-year cycles:

| Term | Meaning | Example (2025) |
|------|---------|----------------|
| **Y-2** | Calculation Year | 2023 - determines if thresholds met |
| **Y-1** | Obligation Year | 2024 - data being reported |
| **Y** | Relevant Year | 2025 - fees due based on Y-1 data |

## Producer Classifications

| Class | Description |
|-------|-------------|
| **Large Producer** | ≥£2M turnover AND >50 tonnes - full obligations |
| **Small Producer** | ≥£1M turnover AND >25 tonnes - registration + annual reporting |
| **Brand Owner** | UK owner of brand on filled packaging |
| **Packer/Filler** | Fills unbranded or non-UK brand packaging |
| **Importer** | UK business importing filled packaging |
| **Distributor** | Supplies unfilled packaging to non-large producers |

## Azure Resource Naming

| Pattern | Meaning | Example |
|---------|---------|---------|
| **WA 4xx** | Web Application | WA 408 = `{env}RWDWEBWAx408` |
| **FA 4xx** | Function App | FA 404 = `{env}RWDWEBFAx404` |
| **{env}** | Environment prefix | DEV, TST, PRE, PRD |
| **RWD** | Report Waste Data (legacy name) | All EPR resources |

## Key Service Numbers

| Number | Service | Purpose |
|--------|---------|---------|
| **WA 401** | epr-obligationchecker-frontend | Public obligation checker |
| **WA 406** | epr-regulator-service-facade | Regulator facade |
| **WA 407** | epr-backend-account-microservice | Account management API |
| **WA 408** | epr-pom-api-submission-status | CosmosDB event store |
| **WA 409** | epr-pom-api-web | Producer facade |
| **WA 410** | epr-packaging-frontend | Producer frontend |
| **WA 411** | epr-regulator-service | Regulator frontend |
| **WA 415** | epr-common-data-api | Synapse analytics API |
| **WA 425** | epr-payment-service | Fee calculation + payments |
| **FA 402** | epr-pom-func-producer-validation | POM file validation |
| **FA 403** | epr-pom-func-submission-check-splitter | POM file splitting |
| **FA 404** | epr-registration-validation-function-app | Registration validation |
| **FA 407** | validation-data-api | Org data for validation |

See [epr-assessment/specs/producer/epr-producer-repositories.md](https://github.com/DEFRA/epr-assessment/blob/main/specs/producer/epr-producer-repositories.md) for complete list.

## Data Stores

| Name | Type | Owner | Purpose |
|------|------|-------|---------|
| **submissionDB** | CosmosDB | WA 408 | Event sourcing for submissions |
| **accountsDB** | SQL Server | WA 407 | User/org data |
| **feesPaymentDB** | SQL Server | WA 425 | Fees and payment records |
| **prnDB** | SQL Server | WA 418 | PRN cache from NPWD |
| **Synapse** | Analytics | - | ETL warehouse, queried via WA 415 |

## Code Terminology

| Term | Meaning |
|------|---------|
| **Facade** | Orchestration layer between frontend and backend APIs |
| **Submission** | A data file upload (registration or POM) |
| **SubmissionEvent** | An append-only event in CosmosDB (decisions, uploads, etc.) |
| **Delta** | Recent changes from CosmosDB since last Synapse sync |
| **LastSyncTime** | Timestamp of last successful Synapse ETL |

## Regulator Terms

| Term | Description |
|------|-------------|
| **Nation** | England (EA), Scotland (SEPA), Wales (NRW), Northern Ireland (NIEA) |
| **RegulatorAdmin** | Full admin access to regulator portal |
| **RegulatorBasic** | Standard review access |
| **ApprovedPerson** | Can make regulatory decisions |
| **DelegatedPerson** | Delegated authority for decisions |

## Submission Statuses

| Status | Meaning |
|--------|---------|
| **Pending** | Awaiting regulator review |
| **Accepted** | Approved by regulator |
| **Rejected** | Rejected, may require resubmission |
| **Queried** | Regulator has questions |
| **Granted** | Registration approved |
| **Refused** | Registration refused |

## External Systems

| System | Purpose |
|--------|---------|
| **Azure AD B2C** | User authentication |
| **GovPay** | Payment gateway |
| **GovNotify** | Email/SMS notifications |
| **Boomi** | Integration platform (Companies House, postcodes) |
| **NPWD** | National Packaging Waste Database (legacy) |
| **FSS** | File Storage Service |
