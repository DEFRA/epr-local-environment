# Testing strategy: Common Data API / local Synapse representation

`epr-common-data-api` reads the Synapse database represented locally by SQL Server. The database
definition is restored from the current `main` branch of
[epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb), not from SQL copied into this repository
or from the Common Data API migration image.

## The rule

1. **The endpoint reads an upstream SQL object and its data can be represented locally** → seed it.
   Add realistic, minimal rows to
   `compose/synapse-sqlserver-restore/seed/baseline.sql`, or use the data generator for volume.
2. **The upstream object needs a Synapse-only physical-storage declaration** → let the restore
   transform it. The transformer removes only physical declarations such as `DISTRIBUTION` and
   columnstore storage settings; it must not change business logic.
3. **The upstream SQL cannot execute on SQL Server without changing its business behaviour** →
   stub the HTTP endpoint with WireMock and document the reason in the mapping README. Do not add a
   second hand-maintained local stored procedure.

The `apps` schema is restored structurally. Production ETL data is not copied into the local stack,
so endpoints whose behaviour depends on that data need an explicit seed or stub decision.

## How to work on an endpoint

1. Find the object in `epr-data-sqldb` and identify its table and view dependencies.
2. Start the relevant profile. `synapse-source-sync` fetches the latest source and
   `synapse-sqlserver-restore` records the resolved commit in
   `dbo.LocalSynapseRestoreHistory`.
3. Seed only the rows needed for the scenario, using the upstream table semantics. Keep account,
   Cosmos/Azurite and payment seed identifiers aligned where the user journey crosses stores.
4. Exercise the endpoint through Common Data API. If the source is not SQL Server-compatible,
   keep that failure visible and replace the endpoint with a documented WireMock fixture rather
   than approximating the calculation in local SQL.

## Maintenance

- Do not add SQL definitions under `compose/` for Common Data API objects. Change the source in
  `epr-data-sqldb` and let the restore retrieve it.
- A source change requires an explicit database rebuild when the local database already contains
  data. The restore refuses to delete local generated data automatically.
- Record the upstream commit and source behaviour when adding a baseline scenario or a WireMock
  exception so drift can be investigated.
