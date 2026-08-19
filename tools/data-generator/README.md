# Data generator

This directory is the home for a local synthetic-data generator for the EPR obligations journey. Its first target is a connected, realistic year of POM, PRN and obligation-calculation data.

> Status: first runnable iteration. It creates SP-relevant Synapse rows and source PRNs, then invokes the existing PRN calculation backend. It does not create upload files/Cosmos documents, account users, payment data, or a replacement Common Data API endpoint.

## Intended command contract

```text
data-generator generate-year 2025
data-generator generate-year 2025 --increase 25%
data-generator generate-year 2025 --link-local-accounts
data-generator generate-year 2025 --replace-existing
```

`2025` is the POM reporting year. The resulting determination, PRN and obligation-calculation year is therefore `2026`. The default command will reproduce the selected baseline's normal volume and shape; `--increase` scales connected entities and their data proportionally rather than merely increasing weights.

The generator runs against an already running local stack from the CLI-only [`compose.cli.yml`](../../compose.cli.yml). It connects through the existing Compose network and database service names; it does not need a separate Docker project name or bespoke network.

## First-iteration outcome

- Generate only data which materially reaches `dbo.sp_GetApprovedSubmissionsMyc`.
- Generate matching accepted/awaiting PRNs for the same submitter identities.
- Re-run the existing PRN obligation calculation path, rather than directly inserting final calculation rows.
- Preserve a realistic compliance-scheme/direct-registrant mix, material mix, producer associations, POM rows and PRN volume.
- Optionally attach a small, representative part of the generated data to the existing local Northbridge and Pop Quest account/organisation fixtures, so normal login can show it.

The detailed decision record, source-repository trace, snapshot figures, identity contract and repeatable refresh process are in [first-iteration.md](docs/first-iteration.md). The profile and SQL-checking conventions are in [profiles/README.md](profiles/README.md) and [sql/README.md](sql/README.md).

## Run it

Start the normal obligations stack first. Then build and run the CLI container:

```sh
docker compose -f compose.yml -f compose.cli.yml build data-generator
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025
```

The command writes a manifest to `tools/data-generator/manifests/<run-id>.json`. It executes the stored procedure directly for the requested POM year, filters to the generated identity set, groups rows as the obligation function does, and posts them to the existing PRN backend calculation endpoint.

Useful variants:

```sh
# Preview deterministic counts and identities without writing data.
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025 --dry-run

# Replace the local source and calculation data for this POM/obligation year,
# then generate and calculate it again.
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025 --replace-existing

# Create source data only; calculate later using the manifest.
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025 --skip-calculate
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator calculate-year 2025 --run <run-id>

# Compare source and calculation counts later.
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator validate-year 2025 --run <run-id>
```

`--link-local-accounts` attaches one scheme and one direct-registrant population to the seeded Northbridge and Pop Quest anchors. It is deliberately rejected where those anchors already have POM data for the selected year, preventing generated and fixture submissions from mixing.

`--replace-existing` is deliberately destructive and is intended only for the local stack. For POM year `Y`, it removes all `Y-H1`/`Y-H2` POM rows and their related metadata, submission events and submissions from `EprCommonData`; it also removes `Y + 1` determination rows, PRNs (and their status history), and obligation calculations. It retains organisations, account/user data, lookup/target data and other years. Each database is internally transactional, but the two database clean-ups cannot be one transaction; do not use this option outside a disposable local environment.

## Directory layout

```text
tools/data-generator/
├── docs/                 Design, data-flow and refresh records
├── manifests/            Generated-run manifests (kept out of source control when populated)
├── profiles/
│   ├── baselines/        Versioned anonymous aggregate profiles
│   └── schemas/          Profile file schemas and validation rules
├── sql/
│   ├── baseline/         Queries used to collect a pre-production baseline
│   ├── validation/       Comparable local/pre-production shape checks
│   └── local/            Local-only, run-scoped diagnostics
├── src/                  CLI implementation
└── tests/                Deterministic plan tests
```

## Guardrails

- Store aggregate, anonymous statistics only in `profiles/`; never copy production organisation, user, address, submission, PRN or file data.
- Resolve lookup IDs by name in the target database. Do not copy local seed IDs into generated PRN data.
- Maintain the identifier relationships described in the decision record exactly, especially across both POM half-year submissions.
- A generated run must record its baseline version, seed, scale, POM year, resulting obligation year and generated identifiers in a manifest.
- Re-running the same run ID is rejected before database writes. Generated POM rows carry `data-generator/<run-id>/`; generated PRNs carry `DG-<run-id>` in `IssuerReference` for safe inspection.
- Do not modify unrelated payment, waste-obligations or legacy calculator fixtures as part of the initial data path.
