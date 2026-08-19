# Data generator

This directory is the home for a local synthetic-data generator for the EPR obligations journey. Its first target is a connected, realistic year of POM, PRN and obligation-calculation data.

> Status: first runnable iteration. It creates stored-procedure-relevant Synapse rows and source PRNs, then invokes the existing PRN calculation backend. It does not create upload files/Cosmos documents, account users, payment data, determination records, or a replacement Common Data API endpoint.

## Intended command contract

```text
data-generator generate-year 2025
data-generator generate-year 2025 --increase 25%
data-generator generate-year 2025 --link-local-accounts
data-generator generate-year 2025 --replace-existing
```

`2025` is the POM reporting year. The resulting PRN and obligation-calculation year is therefore
`2026`; determination records are intentionally omitted, so `NumberOfDaysObligated` follows the
stored procedure's natural null/no-data behaviour. The default command reproduces the checked-in
2025/2026 baseline shape; another reporting year uses the same synthetic shape and is not a claim
about that year's production volume. `--increase` scales connected entities and their data
proportionally rather than merely increasing weights.

The generator runs against an already running local stack from the CLI-only [`compose.cli.yml`](../../compose.cli.yml). It connects through the existing Compose network and database service names; it does not need a separate Docker project name or bespoke network.

## First-iteration outcome

- Generate only data which materially reaches `dbo.sp_GetApprovedSubmissionsMyc`.
- Generate matching accepted/awaiting PRNs for the same submitter identities.
- Re-run the existing PRN obligation calculation path, rather than directly inserting final calculation rows.
- Preserve a realistic compliance-scheme/direct-registrant mix, material mix, producer associations, POM rows and PRN volume.
- Optionally attach a small, representative part of the generated data to the existing local Northbridge and Pop Quest account/organisation fixtures, so normal login can show it.

The detailed decision record, source-repository trace, snapshot figures, identity contract and repeatable refresh process are in [first-iteration.md](docs/first-iteration.md). The profile and SQL-checking conventions are in [profiles/README.md](profiles/README.md) and [sql/README.md](sql/README.md).

## Run it

Start the normal obligations stack first and wait for the Common Data restore and PRN migrations to
complete. The default `common-data-api` schema set contains the generator's required objects; `full`
also works. Then build and run the CLI container:

```sh
docker compose -f compose.yml -f compose.cli.yml build data-generator
docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025
```

The first iteration always imports the checked-in
`preprod-pom-2025-prn-2026` profile. Adding a newly collected profile is a versioned data change,
but selecting a different profile at the command line is not implemented yet; update the default
profile import only after completing the profile-refresh validation process.

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

## Generate, discover and assess future-state data

This is the repeatable local workflow for generating a year, finding the newly created identifiers,
calling the future-state APIs and assessing their latency. It deliberately discovers IDs after each
run: generated identifiers are not stable and should never be copied into scripts or documentation.

1. Start the obligations journey plus the future-state services. Wait for Compose to report that the
   restore and migrations have completed.

   ```sh
   docker compose -f compose.yml -f compose.future.yml \
     --profile obligations --profile future up -d --build --wait
   ```

2. Generate the POM year. Use `--replace-existing` only when intentionally replacing that local
   year's generated data.

   ```sh
   docker compose -f compose.yml -f compose.cli.yml run --rm \
     data-generator generate-year 2025 --replace-existing
   ```

3. Discover usable IDs. Recycling Data ranks generated POM-row volume, so the first compliance
   scheme is a realistic largest-scheme target; the benchmark reports its exact recycling result
   count. ReEx ranks organisations by PRN count. For POM year `2025`, the matching PRN obligation
   year is `2026`.

   ```sh
   curl 'http://localhost:8012/admin/submitters?year=2025&take=10&submitterType=ComplianceScheme' | jq
   curl 'http://localhost:8013/admin/organisations/prns?obligationYear=2026&take=10' | jq
   ```

4. Call the APIs with IDs returned by those commands. The first `jq` expression below selects the
   largest compliance scheme from the generated data; do not replace it with a fixed GUID.

   ```sh
   submitter_id=$(curl --silent \
     'http://localhost:8012/admin/submitters?year=2025&take=1&submitterType=ComplianceScheme' \
     | jq -r '.items[0].submitterId')
   prn_organisation_id=$(curl --silent \
     'http://localhost:8013/admin/organisations/prns?obligationYear=2026&take=1' \
     | jq -r '.items[0].organisationId')

   curl "http://localhost:8012/recycling-data?year=2025&submitterId=${submitter_id}&page=1&pageSize=100"
   curl "http://localhost:8013/organisations/${prn_organisation_id}/prns?page=1&pageSize=100"
   curl -X POST "http://localhost:8014/organisations/${submitter_id}/calculate-obligations?year=2025"
   curl -X POST "http://localhost:8014/organisations/${submitter_id}/calculate-obligations-with-prns?year=2025"
   ```

   To capture an end-to-end HTTP duration without printing the response body, use the same IDs with
   `curl --write-out`:

   ```sh
   curl --fail --silent --output /dev/null \
     --write-out 'recycling-data: %{http_code} %{time_total}s\n' \
     "http://localhost:8012/recycling-data?year=2025&submitterId=${submitter_id}&page=1&pageSize=100"
   curl --fail --silent --output /dev/null \
     --write-out 'reex: %{http_code} %{time_total}s\n' \
     "http://localhost:8013/organisations/${prn_organisation_id}/prns?page=1&pageSize=100"
   curl --fail --silent --output /dev/null -X POST \
     --write-out 'obligations: %{http_code} %{time_total}s\n' \
     "http://localhost:8014/organisations/${submitter_id}/calculate-obligations?year=2025"
   curl --fail --silent --output /dev/null -X POST \
     --write-out 'obligations with PRNs: %{http_code} %{time_total}s\n' \
     "http://localhost:8014/organisations/${submitter_id}/calculate-obligations-with-prns?year=2025&pageSize=50000"
   ```

5. Benchmark Recycling Data using the same generated largest compliance scheme. The first command
   assesses normal paging. The second uses a sufficiently large page for the current 2025 profile to
   return all results in one page; after changing the profile, use a value greater than the reported
   `totalItems`.

   ```sh
   ./future/recycling-data/benchmark-recycling-data.sh --year 2025 --page-size 100
   ./future/recycling-data/benchmark-recycling-data.sh --year 2025 --page-size 50000
   ```

   Each command warms both SQL paths, verifies that their payloads are equivalent and reports
   minimum, median, mean and maximum end-to-end durations. `useLocalSqlOptimisation=false` is the
   source-query baseline on local SQL Server; `true` is the local-only indexed optimisation. It is a
   comparative local measurement, not a benchmark of an actual Synapse dedicated SQL pool. The
   recorded local result and the important distinction between one small-page call and retrieving
   all small pages are in the [Recycling Data benchmark results](../../future/recycling-data/README.md#recorded-local-result).

6. Benchmark the complete future-state calculation with PRNs. This measures only the `obligations`
   endpoint and its calls to the future Recycling Data and ReEx services; it does not call or time
   the existing PRN backend.

   ```sh
   ./future/waste-obligations/benchmark-obligations-with-prns.sh \
     --year 2025 \
     --page-size 50000
   ```

   The script discovers the largest generated compliance scheme unless `--organisation-id` is
   supplied. See the [Obligations benchmark results](../../future/waste-obligations/README.md#recorded-local-result)
   for the recorded result and the rationale for using a page size that covers the full dataset.

The endpoint-specific fields and response shapes are documented in
[Recycling Data](../../future/recycling-data/README.md), [ReEx](../../future/reex/README.md) and
[Obligations](../../future/waste-obligations/README.md).

## Directory layout

```text
tools/data-generator/
├── docs/                 Design, data-flow and refresh records
├── manifests/            Generated-run manifests (kept out of source control when populated)
├── profiles/
│   ├── baselines/        Versioned anonymous aggregate profiles
│   └── schemas/          Reserved for future profile JSON schemas
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
