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

Set the `EPR_CALCULATOR_SERVICE` variable in your terminal to the image tag you require, which can be found in ADO.

Then start the services:

```
EPR_CALCULATOR_SERVICE=required-image-tag docker compose --profile paycal up -d
```

Multiple varibles can be specified if needed, either within the same command or via environment variables, whatever suits.

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

## Licence Information

THIS INFORMATION IS LICENSED UNDER THE CONDITIONS OF THE OPEN GOVERNMENT LICENCE found at:

http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3

### About the licence

The Open Government Licence (OGL) was developed by the Controller of Her Majesty's Stationery Office (HMSO) to enable information providers in the public sector to license the use and re-use of their information under a common open licence.

It is designed to encourage use and re-use of information freely and flexibly, with only a few conditions.
