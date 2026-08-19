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

`synapse-sqlserver-restore` reads every schema, table, function, view and stored procedure in the
upstream source. It removes Synapse physical-storage clauses (`DISTRIBUTION`, columnstore, heap and
replicated-table declarations) before applying the SQL to the local SQL Server instance. The source
commit is recorded in `dbo.LocalSynapseRestoreHistory`.

The initial restore is intentionally more expensive than normal profile startup: it compiles the
complete upstream object set and resolves view dependencies over several passes. The shallow clone
and the resulting database are retained in Docker volumes, so an unchanged later start exits after
checking the recorded source commit.

The first profile run creates and seeds a fresh database. Later starts with the same source commit
finish immediately. If `main` has moved, or an older local database has no restore history, the
restore fails safely rather than deleting generated local data.

## Controls

The default is to synchronise and restore (`EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=true`). To start a
profile without network access or restore work, set this variable to `false` in `.env`. This assumes
that a compatible `EprCommonData` database already exists in the `sqledge-data` volume; it does not
create or validate one.

```dotenv
EPR_LOCAL_RESTORE_SYNAPSE_DATABASE=false
```

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
