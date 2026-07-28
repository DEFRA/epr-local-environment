# EPR local environment

You will need to authenticate against Azure via the command line.

Select the `AZD-RWD-DEV1` subscription.

Then log into the container registry via:

```
az acr login --name devrwdinfac1401
```

## Secrets

Copy the `.env.example` file as `.env` and collect the secrets from a colleague.

## Service profiles

The following profiles are available:

- paycal
- prn
- packaging
- obligations

## Time shift

To run services that have time shift capability, you can include an additional profile with `timeshift-` as a prefix to the profile name you're attempting to run. This will include applicable overrides so service(s) can be started at a specific datetime. For example:

```
docker compose -f compose.yml -f compose.timeshift.yml --profile packaging --profile timeshift-packaging up -d --build
```

See your .env file for TIMESHIFT_DATETIME and the default value applicable service(s) will be started at.

Note the inclusion of `--build` with the above command to force use of the correct container if the tag version is being overridden.

Then to stop:

```
docker compose -f compose.yml -f compose.timeshift.yml --profile packaging --profile timeshift-packaging down -v --remove-orphans
```

## Migrations

The Dockerfile for migrations is unchanged, however, a different `run-migrations.sh` script is included in this repo.

The seeding process is also included here if needed so specific local environment data can be loaded.

## Override image tag

The `main-latest` tag is used by default, therefore whatever has been built last from the main branch.

You can override the image tag used as follows.

Find the variable name of the service you want to override from the compose.yml.

Example:

```
epr-calculator-service:
    pull_policy: always
    image: devrwdinfac1401.azurecr.io/eprcalculatorservicerepository:${EPR_CALCULATOR_SERVICE:-main-latest}
```

Set the `EPR_CALCULATOR_SERVICE` variable in your .env file to the image tag you require, which can be found in ADO:

```
EPR_CALCULATOR_SERVICE=image-tag-name-to-use
```

Then start the services.

Multiple varibles can be specified if needed for each service you want to override.

## Specific service profile instructions

### paycal

Obtain the necessary secrets.

To start:

```
docker compose --profile paycal up -d
```

Once started, access the system via https://localhost:7163 and you can login with your @onmicrosoft account. If login fails then compare with a colleague who can log in as you may need adding to an Azure group.

To stop:

```
docker compose --profile paycal down
```

To remove all, append `-v --remove-orphans`

### prn

Obtain the necessary secrets.

To start:

```
docker compose --profile prn up -d
```

Note that service `epr-common-data-api` uses the Azure CLI to retrieve an access token via the `token-provider` service for Synapse.

Connection strings are authenticated via Active Directory, and services running via Docker cannot access the local AZ creds of the user, therefore a different approach was used.

You will need the initial connection string pointing to Synapse in Azure and then it will be augmented with the access token retrieved from the `token-provider`.

Further access token files can be retrieved as needed should additional services join the local environment.

You will need to be on the Azure VPN when running this profile.

To stop:

```
docker compose --profile prn down
```

To remove all, append `-v --remove-orphans`

### packaging

Obtain the necessary secrets.

To start:

```
docker compose --profile packaging up -d
```

Once started, access the system via https://localhost:7084/report-data and it will prompt to login.

Obtain a dev login account from a colleague.

If you get into a redirect cycle on login that you cannot break out of then your previous session cookie might be invalid. Visit https://localhost:7084/admin/health and remove all cookies, then try again.

You will need to be on the Azure VPN when running this profile.

To stop:

```
docker compose --profile packaging down
```

To remove all, append `-v --remove-orphans`

#### Antivirus scanning

File uploads (`epr-pom-api-web`) are scanned via a local stand-in for the real "Trade Antivirus API": `trade-antivirus-mock` (source at `mocks/TradeAntivirusApi.Mock`). It accepts the uploaded file, then asynchronously publishes a scan result onto the `defra.epr.antivirus.scanresult.local` Service Bus topic, which `epr-anti-virus-function-app` consumes to update the submission status (same as the real production flow, minus the actual scanning).

- By default every upload is reported as clean (`Success`) after ~1 second.
- To exercise the "virus found" path, name the uploaded file so it contains `virus` (case-insensitive), e.g. `test-virus-file.csv` — the mock will report `Quarantined` instead, and the submission status should show the antivirus-failure outcome.
- The match pattern and scan delay are configurable via the `VirusFilenamePattern` / `ScanDelaySeconds` environment variables on `trade-antivirus-mock` in `compose.yml`.

Once a registration file passes the antivirus check, `epr-registration-validation-function-app` picks it up (via the same Service Bus flow) to run CSV row validation and post the final result back to submission status — this is what clears the "uploading organisation details" spinner page in the frontend. Both this and the antivirus function need the stack's self-signed dev cert trusted inside their containers (see the `init-container.sh` mount on each service) since they call `epr-pom-api-submission-status` over HTTPS.

#### Registration fee calculation

On submit, `epr-pom-api-submission-status` publishes a `RegistrationSubmittedForFeesCalculation` message onto the `defra.epr.pom.registrationsubmittedforfeescalculation.local` Service Bus topic (self-provisioned at startup — see `ServiceBus:AdminConnectionString`, which needs the emulator's management port, `asb-backend:5300`, not the AMQP endpoint). `epr-payment-service` subscribes to this topic, reads the submitted CSV from blob storage, and stores the fee-calculation snapshot in its own SQL Server database (migrated by `epr-payment-service-migrations`, same `sqledge` instance used elsewhere).

The frontend/facade read that snapshot via `epr-payment-facade`, which proxies to `epr-payment-service` using a `TokenAuthorizationHandler` that calls `DefaultAzureCredential` for service-to-service auth in Release builds. Since there's no real Azure AD app-to-app credentials or managed identity available locally, `managed-identity-mock` (source at `mocks/ManagedIdentityMock`) stands in for Azure's managed-identity token endpoint: `epr-payment-facade` points at it via the App Service-style `IDENTITY_ENDPOINT`/`IDENTITY_HEADER` env vars, which `DefaultAzureCredential`'s `ManagedIdentityCredential` picks up automatically instead of trying (and timing out against) the real IMDS endpoint. The issued token is a fixed placeholder string, not a real JWT — this only works because `epr-payment-service` never validates the bearer token it receives. Verified directly: ran `DefaultAzureCredential.GetTokenAsync` against the mock standalone and confirmed it returns a token instead of throwing `CredentialUnavailableException`.

#### Local Cosmos DB (submission data)

`epr-pom-api-submission-status` no longer connects to the real cloud Cosmos DB account — `cosmosdb-emulator` (the same `azure-cosmos-emulator:vnext-preview` image this repo's own integration tests use) runs locally instead, with `cosmosdb-emulator-init` (source at `mocks/CosmosDbInit`) creating the database and containers on startup.

- Data Explorer UI: `http://localhost:1234`.
- The emulator's self-signed cert is handled via `Database__IgnoreCertificateErrors: true` — an escape hatch already built into the app for exactly this case, so no cert-trust dance is needed here (unlike the antivirus/registration-validation functions above).
- All four containers defined in the app's EF Core model (`SubmissionContext.cs`) are created: `Submissions`, `SubmissionEvents`, `ProducerValidationErrors`, `ProducerValidationWarnings` — including the Producer/POM validation error/warning containers, which the registration flow this stack is set up to test doesn't exercise, but are ready if needed.
- If you ever see `Connection refused (127.0.0.1:8081)` from a client after its first successful call, check `GATEWAY_PUBLIC_ENDPOINT` on `cosmosdb-emulator` — it must match the hostname other containers use to reach it, or the emulator's Gateway-mode responses point clients back at its own loopback address.

### obligations

Obtain the necessary secrets (including from Key Vault or a teammate).

#### waste-obligations-frontend sign-in

Sign-in uses Azure AD B2C, then calls **epr-backend-account-microservice** (`GET /api/users/user-organisations`) to load the user. In this stack the account API runs in Development without JWT validation; the frontend still requests a bearer token via client credentials.

| Service | Local URL |
| --- | --- |
| waste-obligations-frontend (Docker HTTP) | http://localhost:8008 |
| waste-obligations-frontend (HTTPS proxy) | https://localhost:8010 |
| epr-backend-account-microservice | http://localhost:8003/api/ |
| waste-organisations | http://localhost:8006 |
| waste-obligations | http://localhost:8007 |
| wiremock | http://localhost:9090 |
| Floci (SNS/SQS emulator) | http://localhost:4566 |

**Docker (packaged frontend):** set in `.env`:

- `WasteObligationsFrontend__AzureAdB2C__ClientId`
- `WasteObligationsFrontend__AzureAdB2C__ClientSecret`

OAuth for the backend account API is wired in `compose.yml` to **Wiremock** (`BACKEND_ACCOUNT_API_OAUTH_TOKEN_ENDPOINT=http://wiremock/oauth2/v2.0/token`) — no MO-119 secret is required for Docker.

Use **https://localhost:8010** (HTTPS proxy) for the app and B2C redirect — not port 8008. Register `https://localhost:8010/signin-oidc` and `https://localhost:8010/signed-out` on the B2C app registration if they are not already present.

**npm run dev:** start the obligations profile, then configure [waste-obligations-frontend/.env.example](https://github.com/DEFRA/waste-obligations-frontend/blob/main/.env.example) in that repo:

- Set `AZURE_AD_B2C_CLIENT_SECRET` (same B2C app as Docker).
- For backend account OAuth, either use Wiremock (`BACKEND_ACCOUNT_API_OAUTH_TOKEN_ENDPOINT=http://localhost:9090/oauth2/v2.0/token` with the client id/secret from `compose.yml`) or real MO-119 Azure credentials (`BACKEND_ACCOUNT_API_OAUTH_CLIENT_ID` / `BACKEND_ACCOUNT_API_OAUTH_CLIENT_SECRET`).

Stop the packaged frontend containers so port 8010 is free for the dev server:

```bash
docker compose --profile obligations stop waste-obligations-frontend waste-obligations-frontend-proxy
```

The B2C user's `oid`/`sub` must match a seeded account `UserId` — see [Seeded users](#seeded-users-packaging-profile).

To start:

```
docker compose --profile obligations up -d
```

The packaging front end will be started alongside all necessary services that allow the obligation calculation process to function.

The profile also starts MongoDB as a single-node replica set and Floci with the Waste Obligations analytics SNS topic and subscribed SQS queue provisioned automatically.

A local emulated version of Synapse will be started in sqledge. Currently only the obligation calculation process is supported in the SQL definitions applied within Synapse.

Also note that this is a very brittle approach to standing up a DB that emulates Synapse. There are SQL definitions from the epr-common-data-api layer on top of definitions from epr-data-sqldb and not all are applied. See [further README](./compose/epr-common-data-api-migrations/README.md) for more details at time of writing.

This approach should provide an early feedback loop yet there could still be subtle syntax/behaviour differences between a Synapse and SQL server instance.

See [packaging](#packaging) profile for local running.

The cron for the obligation calculator function is set for a single run at 10am. If you need to run the function manually to kick of the process, it can be initiated via:

```
curl -v POST "http://localhost:7234/admin/functions/StoreApprovedSubmissionsFunction" \
-H "x-functions-key: this-is-a-dummy-value" \
-H "Content-Type: application/json" \
-d '{}'
```

You will need to be on the Azure VPN when running this profile.

To stop:

```
docker compose --profile obligations down
```

To remove all, append `-v --remove-orphans`

## Seeded users (packaging profile)

The following users are seeded into the account microservice DB via `compose/epr-backend-account-microservice-migrations/seed.sql`.

Service roles: `1 = Approved Person`, `2 = Delegated Person`, `3 = Basic User`.

### Compliance Scheme — "Organisation Name" (CHN `12345678`)

| Email | Role | UserId |
|-------|------|--------|
| `test+17122025143216@ee.com` | Approved Person | `579C319D-D552-47A2-BF4C-5A125A3183BC` |
| `francis.chelladurai+07042026@equalexperts.com` | Delegated Person (nominated by `test+17122025143216@ee.com`) | `ef2fd2a5-24bf-4b22-89a0-17a0367aee1c` |
| `francis.chelladurai+260407@equalexperts.com` | Basic User | `13e26b8a-e2b2-4870-b040-d6bdf5d689fa` |

### Direct Producer — "POP QUEST LTD" (CHN `17121895`)

| Email | Role | UserId |
|-------|------|--------|
| `test+directproducer@ee.com` | Approved Person | `79d0deab-c22d-4c30-8082-508ff8dc1bd7` |
| `bmmmdmgz@sharklasers.com` | Delegated Person (nominated by `test+directproducer@ee.com`) | `513a78ee-d5bf-4fa4-9d8f-136550ea6072` |
| `francis.chelladurai+31032026@equalexperts.com` | Basic User | `d062d4fe-34f8-468e-ada8-d950cc9a3c2a` |

### Compliance Scheme — "Northbridge Compliance Solutions Ltd" (CHN `11000000`)

| Email | Role | UserId |
|-------|------|--------|
| `ahmed.hussein+dev9+1784615966009+09640-DONT_USE@equalexperts.com` | Approved Person | `94BFD894-8F64-4F8D-9975-259D08786C2B` |
| `ahmed.hussein+dev9+1784616197060+61532-DONT_USE@equalexperts.com` | Delegated Person (nominated by the Approved Person above) | `F0CA633F-C62F-4DDB-8009-893C1DF9EBC3` |
| `ahmed.hussein+dev9+1784616229626+56548-DONT_USE@equalexperts.com` | Basic User | `637B0DEA-83FA-49CE-AFD9-C5527A820CE1` |

Viewing the scheme members panel on this account's landing page requires the `FeatureManagement__ShowComplianceSchemeMemberManagement` env var set to `true` on the `epr-packaging-frontend` service in `compose.yml` (defaults to `false` in the shipped image).

#### Members of Northbridge Compliance Solutions Ltd (10)

Each row is its own direct producer organisation, linked to the scheme via `OrganisationsConnections` + `SelectedSchemes`, with a single Approved Person account.

| Organisation | CHN | Email | UserId |
|---|---|---|---|
| BRAMBLEWOOD PACKAGING LTD | `11000001` | `ahmed.hussein+dev9+1782714701839+98807-DONT_USE@equalexperts.com` | `A16AE06C-3629-4F04-89A6-B8D1912C99FE` |
| SILVERDALE FOODS LTD | `11000002` | `ahmed.hussein+dev9+1782714726947+48306-DONT_USE@equalexperts.com` | `972111C5-42D1-4AAA-A076-BD61098A75C7` |
| TIDELINE BEVERAGES LTD | `11000003` | `ahmed.hussein+dev9+1782714740443+61628-DONT_USE@equalexperts.com` | `8CE8A6C7-16E6-412F-ABBE-036C2DD7E11A` |
| COPPERGATE HOMEWARES LTD | `11000004` | `ahmed.hussein+dev9+1782714811219+93870-DONT_USE@equalexperts.com` | `410953E4-5D24-4A3C-95F6-E38E8E6802A1` |
| FERNLEIGH COSMETICS LTD | `11000005` | `ahmed.hussein+dev9+1782714821734+90170-DONT_USE@equalexperts.com` | `575067A3-F25E-4B5A-91BC-5BC763BF7556` |
| QUARRYSTONE HARDWARE LTD | `11000006` | `ahmed.hussein+dev9+1782714833475+55076-DONT_USE@equalexperts.com` | `9ECC9140-47E7-4E5E-9B71-1FF3129C5EB5` |
| MAPLECROFT STATIONERY LTD | `11000007` | `ahmed.hussein+dev9+1782714878221+10813-DONT_USE@equalexperts.com` | `103B8411-58F4-4B71-B985-B3A4450B32B3` |
| HARBOURVIEW TEXTILES LTD | `11000008` | `ahmed.hussein+dev9+1782714888354+70374-DONT_USE@equalexperts.com` | `FFD8A042-7BFB-4CE6-BC3A-3BD2E6CDEFE9` |
| GREENFIELD DAIRY LTD | `11000009` | `ahmed.hussein+dev9+1782714921449+05316-DONT_USE@equalexperts.com` | `296C40CC-6694-4E42-95C3-DFD1C0F9692C` |
| STONEBRIDGE ELECTRONICS LTD | `11000010` | `ahmed.hussein+dev9+1782715019923+87659-DONT_USE@equalexperts.com` | `F3F0C069-B981-44CE-946C-484B943B763A` |

#### Subsidiaries (4)

Linked via `OrganisationRelationships` (type `Parent`) + `SubsidiaryOrganisations`. Subsidiaries have no login account of their own — they're managed under their parent member's account.

| Subsidiary | CHN | Parent member |
|---|---|---|
| BRAMBLEWOOD PACKAGING (NORTH) LTD | `11000011` | BRAMBLEWOOD PACKAGING LTD |
| BRAMBLEWOOD PACKAGING (SOUTH) LTD | `11000012` | BRAMBLEWOOD PACKAGING LTD |
| SILVERDALE FOODS DISTRIBUTION LTD | `11000013` | SILVERDALE FOODS LTD |
| SILVERDALE FOODS RETAIL LTD | `11000014` | SILVERDALE FOODS LTD |

All emails above end `-DONT_USE@equalexperts.com` and their `UserId` values are the real Azure B2C Object IDs (`oid`) for those accounts in the shared tenant — see the note earlier in this README that the B2C user's `oid`/`sub` must match a seeded account `UserId` for why this matters.

All enrolments are seeded with `EnrolmentStatusId = 3` (Approved/Active).

## Govuk Notify emails

The `waste-obligations` service uses Govuk Notify. The service is configured with an env var in the .env.example file that needs to be
set. See guidance in the .env.example file.

Default configuration is to use Wiremock but you can comment out the base address line in the compose.yml file and use the real service, alongside using a valid API key (ideally a test key that will allow you to observe what emails have been sent in the Govuk Notify portal).

## Contributing

### Adding services

If the new service serves HTTPS on the docker network under its compose service name (i.e. anything else in the stack calls it as `https://<service-name>:...`), the self-signed cert needs that name added as a SAN or .NET clients will fail with `RemoteCertificateNameMismatch`. See [compose/certs/README.md](compose/certs/README.md) for the regen steps.

## Licence Information

THIS INFORMATION IS LICENSED UNDER THE CONDITIONS OF THE OPEN GOVERNMENT LICENCE found at:

http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3

### About the licence

The Open Government Licence (OGL) was developed by the Controller of Her Majesty's Stationery Office (HMSO) to enable information providers in the public sector to license the use and re-use of their information under a common open licence.

It is designed to encourage use and re-use of information freely and flexibly, with only a few conditions.
