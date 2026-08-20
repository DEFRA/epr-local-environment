# Local Synapse-to-SQL Server restore

This replaces the retired Common Data API migration image. It creates the local `EprCommonData`
database from the current `main` branch of
[epr-data-sqldb](https://github.com/DEFRA/epr-data-sqldb), then applies the local baseline seed.

`synapse-source-sync` keeps a shallow clone in `.cache/synapse-source` in this repository. It
fetches only the current tip of `main` and writes the resolved commit there. The directory is
ignored by Git and is created on the first restore, so the source does not need to exist beforehand.

The directory is mounted at `/cache` in the two restore containers. It contains the checkout at
`/cache/epr-data-sqldb` and its commit marker at `/cache/resolved-commit`:

```text
epr-local-environment/
└── .cache/
    └── synapse-source/
        ├── epr-data-sqldb/
        └── resolved-commit
```

It survives all Docker Compose lifecycle commands, including `docker compose down --volumes`, because
it is an ordinary ignored host directory. Delete `.cache/synapse-source` when a fresh shallow clone
is wanted.

`synapse-sqlserver-restore` selects its source SQL files from
[`schema-map.txt`](./schema-map.txt). The default `common-data-api` set contains every source object
needed by the current Common Data API surface used in the local environment. The `full` set retains the
historic behaviour of reading every supported schema, table, function, view and stored procedure in the
upstream source. The restore removes Synapse physical-storage clauses (`DISTRIBUTION`, columnstore, heap
and replicated-table declarations) before applying SQL to the local SQL Server instance. The source
commit, selected schema set and map fingerprint are recorded in `dbo.LocalSynapseRestoreHistory`.

The initial restore is intentionally more expensive than normal profile startup. The `full` set
compiles the complete upstream object set and resolves view dependencies over several passes; the
default `common-data-api` set restores only its declared dependency closure. The shallow clone is
retained in the ignored host directory above, while the resulting database is retained in the
`sqledge-data` Docker volume. An unchanged later start exits after checking the recorded source
commit, schema set and map fingerprint.

The first profile run creates and seeds a fresh database. A database restored with a different source
commit, schema set or map fingerprint is not treated as compatible. The restore fails safely rather
than deleting generated local data; rebuild explicitly when replacement is intended.

## Controls

The default is to synchronise and restore (`EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=true`). To start a
profile without network access or restore work, set this variable to `false` in `.env`. This assumes
that a compatible `EprCommonData` database already exists in the `sqledge-data` volume; it does not
create or validate one. With the default setting, the first restore requires network access to fetch
the current `main` revision of `epr-data-sqldb`.

```dotenv
EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=false
```

## Schema sets

Set `EPR_LOCAL_SYNAPSE_SCHEMA_SET` in `.env` to choose a set in
[`schema-map.txt`](./schema-map.txt). It defaults to `common-data-api`.

| Set | Purpose | Seed |
| --- | --- | --- |
| `common-data-api` | Default. Static dependency closure for every current Common Data API database operation used by the local stack: 2 schemas, 24 tables, 1 function, 1 view and 15 procedures. | Baseline |
| `full` | Every supported object from `epr-data-sqldb`. | Baseline |

Changing this setting requires a rebuild because a smaller set is not interchangeable with a full
database:

```sh
EPR_LOCAL_SYNAPSE_SCHEMA_SET=common-data-api \
EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=true \
EPR_LOCAL_REBUILD_SYNAPSE_DATABASE=true \
docker compose --profile obligations up -d
```

To use the complete upstream schema instead, select `full` and rebuild in the same way:

```sh
EPR_LOCAL_SYNAPSE_SCHEMA_SET=full \
EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=true \
EPR_LOCAL_REBUILD_SYNAPSE_DATABASE=true \
docker compose --profile obligations up -d
```

## Maintaining the Common Data API map

`schema-map.txt` is deliberately an allow-list, not an automatic dependency scanner. When a Common
Data API operation gains a database dependency, add every required source-relative SQL file to the
`common-data-api` section and verify the API route against a disposable database before rebuilding
the normal local database. The complete process, including handling an upstream object that has no
source script, is in the [Common Data API testing strategy](../../agents/common-data-api-testing-strategy.md).

The map explicitly records one upstream compatibility gap:
`dbo.sp_IsPOMResubmissionSynchronised` is called by the current Common Data API source but is absent
from the current `epr-data-sqldb` source. It cannot be restored until those repositories are aligned.

To explicitly replace the database, stop dependants and set both controls. Rebuilding drops the
local `EprCommonData` database before restoring and seeding it.

```sh
EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=true \
EPR_LOCAL_REBUILD_SYNAPSE_DATABASE=true \
docker compose --profile obligations up -d
```

This is a SQL Server-compatible logical representation of Synapse, not a physical Synapse backup.
Any upstream SQL Server-incompatible behaviour must be made explicit in this restore process rather
than silently ignored.
