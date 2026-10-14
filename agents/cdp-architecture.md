# EPR on CDP

The CDP-hosted slice of the EPR system. Most new and migrated functionality lands here, though some change continues on the Azure side.

For platform specifics (deployment model, persistence, networking, auth, telemetry) consult `cdp-documentation` locally - it is GitHub-internal and is not paraphrased here. For the cross-platform overview see [architecture.md](architecture.md). For the Azure side see [azure-architecture.md](azure-architecture.md).

## Producer-team CDP repos

Permalinks pin to the SHA the trace was performed against. Re-run `git rev-parse origin/main` in each repo to refresh.

### Registration & Enrolment

- [epr-register-enrol-frontend](https://github.com/DEFRA/epr-register-enrol-frontend) - producer registration & enrolment UI. Calls `epr-register-enrol-backend` ([`config.js#L295-L308`](https://github.com/DEFRA/epr-register-enrol-frontend/blob/c91275b78e3c8ca9187a7a154086d46e933073a4/src/config/config.js#L295-L308), [`api-client.js#L47`](https://github.com/DEFRA/epr-register-enrol-frontend/blob/c91275b78e3c8ca9187a7a154086d46e933073a4/src/server/common/api-client.js#L47)). External auth: Azure Entra ID (regulators) + Defra ID (operators) ([`auth/providers/`](https://github.com/DEFRA/epr-register-enrol-frontend/tree/c91275b78e3c8ca9187a7a154086d46e933073a4/src/server/common/helpers/auth/providers)).
- [epr-register-enrol-backend](https://github.com/DEFRA/epr-register-enrol-backend) - registration/enrolment API. CDP-only today - no Azure-side EPR calls. ReEx and CaseWorking adapters are dev stubs ([`Program.cs#L92-L99`](https://github.com/DEFRA/epr-register-enrol-backend/blob/0fb61f49b0db1ecdd24841deb4d026607f7dc937/EprRegisterEnrolBackend/Program.cs#L92-L99) registers stubs and logs that real implementations must be registered for non-Development environments).
- [epr-register-enrol-fe-tests](https://github.com/DEFRA/epr-register-enrol-fe-tests) - frontend test suite for the above.

### Waste / PRN obligations

- [waste-obligations-frontend](https://github.com/DEFRA/waste-obligations-frontend) - UI for PRN obligation views. Calls CDP-side `waste-organisations` and (via `waste-obligations`) the Azure PRN backend.
- [waste-obligations](https://github.com/DEFRA/waste-obligations) - obligations API. **Crosses the chasm**: calls Azure-hosted [epr-prn-common-backend](https://github.com/DEFRA/epr-prn-common-backend) (WA 418) for `api/v1/prn/obligationcalculation/{year}` ([`PrnCommonBackendService.cs#L14`](https://github.com/DEFRA/waste-obligations/blob/f4f317c916c7114306087cb5e41f980daf29291c/src/Api/Services/PrnCommonBackend/PrnCommonBackendService.cs#L14)). Per-env base URL in `cdp-app-config/services/waste-obligations/{env}/waste-obligations.env` (`PrnCommonBackend__BaseAddress`); [dev config#L15-L21](https://github.com/DEFRA/cdp-app-config/blob/dcf7dde9910dda5f310a7728caaa1ac5af5f0a86/services/waste-obligations/dev/waste-obligations.env#L15-L21). Auth via OAuth2 client credentials against Azure Entra ID ([`OAuth2TokenCache.cs#L48`](https://github.com/DEFRA/waste-obligations/blob/f4f317c916c7114306087cb5e41f980daf29291c/src/Api/Utils/OAuth2/OAuth2TokenCache.cs#L48)). Also calls CDP-side `waste-organisations` for org lookups (no Azure crossing on that side).

## Cross-platform calls

Confirmed CDP → Azure HTTP paths today:
- `waste-obligations → epr-prn-common-backend` (WA 418)

See [architecture.md](architecture.md#cross-platform-interactions) for detail. There may be others not yet documented.

## Tagged repos

`gitopolis list -t cdp` for the full list (includes `cdp-documentation` and `cdp-app-config` reference repos).
