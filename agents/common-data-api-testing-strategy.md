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

### Stubbing an exception

A WireMock mapping is effective only when the caller is configured to use it. In the local stack,
the POM API, obligation-calculation function and regulator facade normally call
`epr-common-data-api` directly. For those callers, adding a WireMock mapping alone changes nothing:
either deliberately reroute that caller (or introduce a proxy) for the scenario, or keep the
upstream SQL failure visible. Do not hide an unavailable upstream procedure by adding a separate
hand-maintained local stored procedure.

### Known negative-path behaviour

`RegistrationFeeCalculationDetailsService` currently catches SQL exceptions and returns `null`; its
controller translates that to HTTP 204, the same response used for no result. A local fixture or
seed cannot distinguish those cases. Treat negative-path coverage for
`get-registration-fee-calculation-details` as an API-service concern until that behaviour changes.

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

## Extending the local Common Data API schema set

The default local restore uses the `common-data-api` set in
[`schema-map.txt`](../compose/synapse-sqlserver-restore/schema-map.txt), rather than every object
in `epr-data-sqldb`. Extend that set whenever a new Common Data API operation needs an object that
is not already present.

1. Find the database entry point in `epr-common-data-api` and identify its recursive dependencies:
   tables, views, functions and any procedures it calls. Include dependency objects, not only the
   endpoint's top-level procedure.
2. Confirm that every object has a source script in the current `main` revision of
   `epr-data-sqldb`. Add its source-relative path to the `common-data-api` section of
   `schema-map.txt`. The restore processes entries by object type, so list the exact `.sql` source
   files; do not copy their SQL into this repository.
3. If an API-exposed object has no upstream script, add an `@unavailable=schema.object` entry to
   the set and document or stub the endpoint. Do not introduce a hand-maintained replacement
   stored procedure locally. The restore reports these entries clearly.
4. Verify the change against a disposable database first, using
   `EPR_LOCAL_SYNAPSE_SCHEMA_SET=common-data-api` and a new database name. Exercise the API route,
   not just the procedure creation.
5. Rebuild the normal local database only when ready. A database restored with a different schema
   set is intentionally not considered compatible. `full` is available as a temporary compatibility
   fallback, but the map should be completed before making a feature part of the normal local flow.

## Maintenance

- Do not add SQL definitions under `compose/` for Common Data API objects. Change the source in
  `epr-data-sqldb` and let the restore retrieve it.
- A source change requires an explicit database rebuild when the local database already contains
  data. The restore refuses to delete local generated data automatically.
- Record the upstream commit and source behaviour when adding a baseline scenario or a WireMock
  exception so drift can be investigated.
