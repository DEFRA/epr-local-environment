# Synapse

The current database definition for the common data API is produced from two places.

## https://github.com/DEFRA/epr-data-sqldb

At time of writing, main is stale and release 17.1 contains the latest versions. See https://github.com/DEFRA/epr-data-sqldb/tree/release/17.1

As the .sql files are for Synapse, they include syntax that will not work in SQL server.

The pipeline for this repo produces a .dacpac file but because of the issue above it cannot be used as a mechanism to recreate a local SQL server emulated version of Synapse.

Therefore, for the single use case currently of the obligation calculator, we take the .sql defintion files for the things we need and copy then into this repo. See the scripts folder for what has been copied.


## https://github.com/DEFRA/epr-common-data-api

Additional .sql definitions are also defined here for specific common data API functionality, which are applied on top of the existing Synapse DB.

See https://github.com/DEFRA/epr-common-data-api/pull/342 for changes that will produce a "migrations" docker image, which can be used in the local environment here.

Also note .sql file syntax changes, which will allow the files to be applied via sqlcmd as part of the migration process.

The use of `GREATEST` is a Synapse only term and has been replaced with a CASE WHEN THEN to replicate for SQL server.

## Running as part of local environment

Adding the following env vars to your local .env file:

```
EPR_COMMON_DATA_API_MIGRATIONS=feature_local-env-20260224.3-database-migrations
EPR_PRN_OBLIGATIONCALCULATIONS_FUNCTION=feature_local-env-20260225.1
```

And running the following startup:

```
docker compose --profile synapse up -d --build
```

The [run-migrations.sh](./run-migrations.sh) script will be used instead of the one in the docker image and it will apply the .sql files it needs from both sources discussed above.

Note that only a single scenario is covered here for the obligation calculator Azure function, which now needs only a single stored procedure in the Synapse database.

Once everything is running, the Azure function can be invoked and it will call the local common data API looking for data. There is nothing seeded currently so nothing else happens but this spike shows, in principle, we should be able to get something running locally away from any Azure or Synapse related resources.

Obviously this is not a real Synapse instance so regression checks would still be needed in an Azure environment at some point, but this local environment setup would help with early feedback when testing work that is in PRs and has not been merged to main.
