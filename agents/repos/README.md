# Per-Repo Quick Reference

Lightweight summaries for quick orientation. For detailed specs, see [epr-assessment/specs/](https://github.com/DEFRA/epr-assessment/tree/main/specs).

## How to Use

Each file provides:
- **Purpose**: What the service does (1-2 sentences)
- **Entry points**: Where to start reading code
- **Dependencies**: What it calls
- **Consumers**: What calls it
- **Gotchas**: Misleading things specific to this repo
- **Detailed spec**: Link to epr-assessment if available

## Services by Domain

### Regulator Domain
- [epr-regulator-service.md](epr-regulator-service.md) - Regulator frontend (WA 411)
- [epr-regulator-service-facade.md](epr-regulator-service-facade.md) - Regulator orchestration (WA 406)

### Producer Domain
- [epr-packaging-frontend.md](epr-packaging-frontend.md) - Producer data submission (WA 410)
- [epr-pom-api-web.md](epr-pom-api-web.md) - Producer facade (WA 409)
- [epr-obligationchecker-frontend.md](epr-obligationchecker-frontend.md) - Public obligation checker (WA 401)

### Data & Events
- [epr-pom-api-submission-status.md](epr-pom-api-submission-status.md) - CosmosDB event store (WA 408)
- [epr-common-data-api.md](epr-common-data-api.md) - Synapse analytics API (WA 415)

### Payments
- [epr-payment-service.md](epr-payment-service.md) - Fee calculation + payments (WA 425)
- [epr-payment-facade.md](epr-payment-facade.md) - Payment orchestration (WA 424)

### Accounts
- [epr-backend-account-microservice.md](epr-backend-account-microservice.md) - Account API + validation API (WA 407 + FA 407)
- [epr-facade-account-microservice.md](epr-facade-account-microservice.md) - Account facade (WA 404)

### Validation Functions
- [epr-registration-validation-function-app.md](epr-registration-validation-function-app.md) - Registration validation (FA 404)
- [epr-pom-func-producer-validation.md](epr-pom-func-producer-validation.md) - POM validation (FA 402)
- [epr-pom-func-submission-check-splitter.md](epr-pom-func-submission-check-splitter.md) - POM splitter (FA 403)

## Quick Navigation by WA/FA Number

**Production config:** Check feature flags and settings in [epr-app-config-settings](https://github.com/DEFRA/epr-app-config-settings/tree/main/prd1)

| ID | Service | Summary | PRD Config |
|----|---------|---------|------------|
| WA 401 | epr-obligationchecker-frontend | [link](epr-obligationchecker-frontend.md) | [PRDRWDWEBWA1401.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1401.json) |
| WA 404 | epr-facade-account-microservice | [link](epr-facade-account-microservice.md) | [PRDRWDWEBWA1404.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1404.json) |
| WA 406 | epr-regulator-service-facade | [link](epr-regulator-service-facade.md) | [PRDRWDWEBWA1406.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1406.json) |
| WA 407 | epr-backend-account-microservice | [link](epr-backend-account-microservice.md) | [PRDRWDWEBWA1407.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1407.json) |
| WA 408 | epr-pom-api-submission-status | [link](epr-pom-api-submission-status.md) | [PRDRWDWEBWA1408.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1408.json) |
| WA 409 | epr-pom-api-web | [link](epr-pom-api-web.md) | [PRDRWDWEBWA1409.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1409.json) |
| WA 410 | epr-packaging-frontend | [link](epr-packaging-frontend.md) | [PRDRWDWEBWA1410.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1410.json) |
| WA 411 | epr-regulator-service | [link](epr-regulator-service.md) | [PRDRWDWEBWA1411.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1411.json) |
| WA 415 | epr-common-data-api | [link](epr-common-data-api.md) | [PRDRWDWEBWA1415.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1415.json) |
| WA 424 | epr-payment-facade | [link](epr-payment-facade.md) | [PRDRWDWEBWA1424.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1424.json) |
| WA 425 | epr-payment-service | [link](epr-payment-service.md) | [PRDRWDWEBWA1425.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBWA1425.json) |
| FA 402 | epr-pom-func-producer-validation | [link](epr-pom-func-producer-validation.md) | [PRDRWDWEBFA1402.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBFA1402.json) |
| FA 403 | epr-pom-func-submission-check-splitter | [link](epr-pom-func-submission-check-splitter.md) | [PRDRWDWEBFA1403.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBFA1403.json) |
| FA 404 | epr-registration-validation-function-app | [link](epr-registration-validation-function-app.md) | [PRDRWDWEBFA1404.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBFA1404.json) |
| FA 407 | validation-data-api | (in epr-backend-account-microservice) | [PRDRWDWEBFA1407.json](https://github.com/DEFRA/epr-app-config-settings/blob/main/prd1/PRDRWDWEBFA1407.json) |
