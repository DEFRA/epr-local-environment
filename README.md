# EPR local environment

You will need to authenticate against Azure via the command line.

Select the `AZD-RWD-DEV1` subscription.

Then log into the container registry via:

```
az acr login --name devrwdinfac1401
```

The following profiles are available:

- paycal
- prn

They can be run via:

```
docker compose --profile paycal up -d
docker compose --profile prn up -d
```

To stop:

```
docker compose --profile paycal down
docker compose --profile prn down
```

To remove all, append `-v --remove-orphans`

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
