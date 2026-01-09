# EPR local environment

You will need to authenticate against Azure via the command line.

Select the `AZD-RWD-DEV1` subscription.

Then log into the container registry via:

```
az acr login --name devrwdinfac1401
```

## Service profiles

The following profiles are available:

- paycal
- prn
- packaging

They can be run via:

```
docker compose --profile paycal up -d
docker compose --profile prn up -d
docker compose --profile packaging up -d
```

To stop:

```
docker compose --profile paycal down
docker compose --profile prn down
docker compose --profile packaging down
```

To remove all, append `-v --remove-orphans`

## Specific service instructions

### epr-calculator-frontend

Requires a client secret in order to retrieve an access token for communication with `epr-calculator-api`.

Once started, access the system via https://localhost:7163 and you can login with the @onmicrosoft account.

### epr-common-data-api

Uses the Azure CLI to retrieve an access token via the `token-provider` service for Synapse.

Connection strings are authenticated via Active Directory, and services running via Docker cannot access the local AZ creds of the user, therefore a different approach was used.

Further access token files can be retrieved as needed should additional services join the local environment.

### epr-packaging-frontend

Once started, access the system via https://localhost:7084/report-data and it will prompt to login.

Obtain a dev login account from a fellow developer.

### Migrations

The Dockerfile for migrations is unchanged, however, a different `run-migrations.sh` script is included in this repo. The seeding process is also included here if needed. Likewise, depending on the work you're doing, different seeding files could be used for testing different scenarios.

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

Set the `EPR_CALCULATOR_SERVICE` variable in your terminal to the image tag you require, which can be found in ADO.

Then start the services:

```
EPR_CALCULATOR_SERVICE=required-image-tag docker compose --profile paycal up -d
```

Multiple varibles can be specified if needed, either within the same command or via environment variables, whatever suits.

## Secrets

Copy the `.env.example` file as `.env` and collect the secrets from Keyvault or a fellow developer.
