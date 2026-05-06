# EPR Architecture - Overview

UK Extended Producer Responsibility (EPR) for packaging. Multi-tenant microservices system spanning **two platforms**:

- **Azure** - the original estate. Primarily in maintenance, with some ongoing change. See [azure-architecture.md](azure-architecture.md) for the full breakdown (3-tier pattern, event-driven processing, dual-source merging, services by function, data stores, etc.). Synapse / PowerBI reporting expected to stay on Azure for the foreseeable future.
- **CDP** - active development. Most new and migrated functionality lands here. See [cdp-architecture.md](cdp-architecture.md) for the producer-team CDP repos and what they call. Platform specifics live in `cdp-documentation` (GitHub-internal).

## Cross-platform interactions

Flows often cross the boundary - follow the call, don't stop at the platform line.

### Confirmed cross-cloud HTTP calls

Permalinks below pin to the SHA the trace was performed against. Re-run `git rev-parse origin/main` in each repo to refresh.

- **regulator-frontend (CDP) → regulator-gateway (CDP) → epr-backend-account-microservice (Azure, WA 407)**
  - `epr-regulator-gateway` configures `UserService.BaseUrl` pointing at the Azure-hosted account microservice in [`appsettings.json#L8-L9`](https://github.com/DEFRA/epr-regulator-gateway/blob/a90d0b9eec4490e3bbcfed91486c5946054c74e2/EprRegulatorGateway/appsettings.json#L8-L9) (`devrwdwebwa9407.azurewebsites.net` for dev).
  - Outbound calls are made from [`UserApiClient.GetUserOrganisationsAsync()`](https://github.com/DEFRA/epr-regulator-gateway/blob/a90d0b9eec4490e3bbcfed91486c5946054c74e2/EprRegulatorGateway/Account/Services/UserApiClient.cs#L9) → `api/users/user-organisations`.
  - Auth crosses the boundary via [`DefaultAzureCredential` in `UserServiceAuthorisationHandler.cs#L25`](https://github.com/DEFRA/epr-regulator-gateway/blob/a90d0b9eec4490e3bbcfed91486c5946054c74e2/EprRegulatorGateway/Account/Handlers/UserServiceAuthorisationHandler.cs#L25) - the gateway acquires an Azure AD token to call the Azure-hosted API.
  - The frontend itself does not call Azure directly; it talks to the gateway via [`account-details.js#L103-L105`](https://github.com/DEFRA/epr-regulator-frontend/blob/d73fdf50a5dc29380fc9e633112ed3232969c0ae/src/server/common/services/account-details.js#L103-L105).

- **waste-obligations-frontend (CDP) → waste-obligations (CDP) → epr-prn-common-backend (Azure, WA 418)**
  - `waste-obligations` calls the Azure-hosted PRN backend for obligation calculations. Per-environment base URL in `cdp-app-config/services/waste-obligations/{env}/waste-obligations.env` (`PrnCommonBackend__BaseAddress`); [dev config#L15-L21](https://github.com/DEFRA/cdp-app-config/blob/dcf7dde9910dda5f310a7728caaa1ac5af5f0a86/services/waste-obligations/dev/waste-obligations.env#L15-L21) points at `https://devrwdwebwa9418.azurewebsites.net`.
  - In-repo HTTP client: [`PrnCommonBackendService.cs#L14`](https://github.com/DEFRA/waste-obligations/blob/f4f317c916c7114306087cb5e41f980daf29291c/src/Api/Services/PrnCommonBackend/PrnCommonBackendService.cs#L14) calling `api/v1/prn/obligationcalculation/{year}`.
  - Auth crosses via OAuth2 client credentials against Azure Entra ID; token acquired in [`OAuth2TokenCache.cs#L48`](https://github.com/DEFRA/waste-obligations/blob/f4f317c916c7114306087cb5e41f980daf29291c/src/Api/Utils/OAuth2/OAuth2TokenCache.cs#L48). Config (`PrnCommonBackend__TokenEndpoint` / `__ClientId` / `__Scope`) lives in `cdp-app-config`.
  - `waste-obligations` also calls a CDP-side `waste-organisations` service for organisation lookups - that side does not cross to Azure.

### Other CDP repos (no current Azure-side EPR calls)

- `epr-register-enrol-frontend` → `epr-register-enrol-backend` (CDP-side only). External auth via Azure Entra ID (regulators) and Defra ID (operators).
- `epr-register-enrol-backend` - no Azure-side EPR calls. ReEx and CaseWorking adapters are dev stubs only ([`Program.cs#L92-L99`](https://github.com/DEFRA/epr-register-enrol-backend/blob/0fb61f49b0db1ecdd24841deb4d026607f7dc937/EprRegisterEnrolBackend/Program.cs#L92-L99) registers stubs and logs that real implementations must be registered for non-Development environments).
- `waste-obligations-frontend` - no direct Azure calls. Talks to `waste-obligations` (CDP) which is the bridge.

### Auth boundary

- **Azure side**: Azure AD B2C (external users), AAD (internal).
- **CDP side**: Defra ID (external operators), Azure Entra ID (internal regulators).
- A request crossing the platform boundary often involves the CDP service acquiring its own Azure AD token rather than forwarding the user token. Look for `DefaultAzureCredential` / token handlers, not pass-through bearer tokens.

### Data boundary

- No shared database. Data crosses platforms only via HTTP API calls.
- Reporting data (Synapse) does not cross to CDP - it remains the long-term home for historical / aggregated data even after services migrate.

## Where to look next

- [azure-architecture.md](azure-architecture.md) - all the Azure detail (services, data stores, patterns, gotchas).
- [cdp-architecture.md](cdp-architecture.md) - CDP repo inventory and outbound calls.
- [flows/](flows/) - traced multi-service data flows.
- [gotchas.md](gotchas.md) - traps and misleading names.
