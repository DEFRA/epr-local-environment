# Future-state real-time benchmark

This guide creates a connected local POM/PRN year and measures the future-state services with the
same generated submitters. It is deliberately an end-to-end local benchmark: timings include the
HTTP calls made by `obligations` to its future-service dependencies and are not compared with the
current PRN common backend.

The benchmark is for design feedback, not a representation of production Synapse performance. The
local `EprCommonData` database is a SQL Server restoration of Synapse source objects, and machine,
Docker and database cache state affect every timing.

## What is measured

The runner makes one sequence of real-time requests for each selected volume band:

| Direct request | Default request | What the runner records |
| --- | --- | --- |
| Recycling Data | `GET /recycling-data?year={year}&submitterId={id}` | Total recycling records and page count |
| ReEx | `GET /organisations/{id}/prns` | Total PRNs and page count |
| Obligations | `GET /organisations/{id}/calculate-obligations?year={year}` | **End-to-end calculation latency** |
| Obligations with PRNs | `GET /organisations/{id}/calculate-obligations-with-prns?year={year}` | **End-to-end calculation latency** |

Unless `--page-size` is supplied, the direct calls use `page=1&pageSize=100`. Both calculation
endpoints accept the same optional parameters, but after their first downstream request they traverse
**every** remaining page before producing their response. That distinction is essential to
interpreting the two obligations timings.

## Future-state service flow

```mermaid
flowchart LR
    caller[Benchmark runner or caller]

    subgraph future[Future-state Compose services]
        recycling[recycling-data :8016]
        reex[reex :8017]
        obligations[obligations :8018]
    end

    common[(EprCommonData local SQL Server representation of Synapse)]
    prn[(EprPrnBackend local SQL Server)]

    caller -->|GET /recycling-data| recycling
    caller -->|GET /organisations/{id}/prns| reex
    caller -->|GET /organisations/{id}/calculate-obligations| obligations
    caller -->|GET /organisations/{id}/calculate-obligations-with-prns| obligations

    obligations -->|GET /recycling-data - first page, then all pages| recycling
    obligations -->|GET /organisations/{id}/prns - first page, then all pages, with PRNs route only| reex
    recycling --> common
    reex --> prn
```

`calculate-obligations` has one downstream dependency: Recycling Data. It returns a transient,
detailed calculation row for each eligible recycling row; Glass generates both Glass and Glass
Remelt calculations. It neither reads nor stores PRNs.

`calculate-obligations-with-prns` first performs that same transient calculation, then retrieves
all ReEx PRNs. It returns a compact material assessment: accepted PRNs determine Met/NotMet and
outstanding tonnes; awaiting-acceptance PRNs are shown separately. Paper and Fibre Composite are
combined, and the Glass Remelt surplus rule is applied. It stores nothing.

Both calculation endpoints are `GET` because they have no body and make no state change. They set
`Cache-Control: no-store`, so a browser, proxy or other intermediary must not reuse a calculation
that was derived from source data which may have changed since the earlier request.

Both routes accept `maxConcurrency=1` through `8`. When omitted, page retrieval stays sequential.
`4` is the recommended initial local comparison: after the first page determines the page count, it
allows up to four page requests at once without creating an unbounded number of concurrent full SQL
aggregations. The PRN-aware route completes its Recycling Data pages before it begins its ReEx pages.

## Prepare the local environment

Prerequisites are Docker Compose, `curl`, `jq`, and enough local disk for the cached Synapse source
and database volumes. From a fresh checkout, copy `.env.example` to `.env` and set any credentials
needed by the normal obligations profile.

The obligations profile includes private Defra container images. If Docker reports an
`authentication required` error while it pulls from `devrwdinfac1401.azurecr.io`, sign in to the
registry with an account that has access before starting the profile:

```sh
az acr login --name devrwdinfac1401
```

This is a one-time local Docker credential step until the registry login expires; it is not needed
to call the future-service endpoints after the stack is already running.

The default `.env` settings restore the Common Data database from the latest shallow `main` checkout
of `epr-data-sqldb`. The source cache is retained in `.cache/synapse-source`, which is ignored by
Git. The first startup is therefore slower than later starts. See the
[Synapse restore README](../../compose/synapse-sqlserver-restore/README.md) for rebuild, schema-set
and local-index controls.

1. Start the obligations profile and future services. Wait for the restore, migrations and service
   health checks to finish.

   ```sh
   docker compose -f compose.yml -f compose.future.yml \
     --profile obligations --profile future up -d --build --wait
   ```

2. Build the separate CLI image and generate a complete reporting year. On a new local database,
   omit `--replace-existing`.

   ```sh
   docker compose -f compose.yml -f compose.cli.yml build data-generator
   docker compose -f compose.yml -f compose.cli.yml run --rm \
     data-generator generate-year 2025
   ```

   The command writes a manifest under `tools/data-generator/manifests/` and creates connected
   2025 POM data, 2026 PRNs, and persisted current-backend calculations. The future benchmark does
   not use those persisted calculations; it recalculates from the generated source data.

   To intentionally remove existing **local** POM/PRN/calculation data for this year before a new
   run, add `--replace-existing`. Read the generator's destructive-operation warning first:

   ```sh
   docker compose -f compose.yml -f compose.cli.yml run --rm \
     data-generator generate-year 2025 --replace-existing
   ```

3. Confirm the generated shape and discover live IDs. Do not copy IDs from an earlier run.

   ```sh
   curl 'http://localhost:8016/admin/submitters?year=2025&take=20&submitterType=ComplianceScheme' | jq
   curl 'http://localhost:8016/admin/submitters?year=2025&take=20&submitterType=DirectRegistrant' | jq
   curl 'http://localhost:8017/admin/organisations/prns?obligationYear=2026&take=20' | jq
   ```

## Run the benchmark

Run the full default-paging suite:

```sh
./future/benchmark/run-real-time-benchmark.sh --year 2025
```

The output is a Markdown table. It chooses the generated submitter with the most POM rows in each
available producer-association band, so it works with a different seed or `--increase` scale.

Start with an inexpensive direct-registrant scenario while checking a new environment:

```sh
./future/benchmark/run-real-time-benchmark.sh \
  --year 2025 \
  --scenario direct-one
```

To compare the default sequential page retrieval with the initial concurrent setting, run the same
multi-page scenario twice. `4` is deliberately an explicit opt-in, so production-like sequential
behaviour remains the default.

```sh
./future/benchmark/run-real-time-benchmark.sh --year 2025 --scenario scheme-large
./future/benchmark/run-real-time-benchmark.sh --year 2025 --scenario scheme-large --max-concurrency 4
```

The available scenarios are:

| Scenario | Submitter type | Producer-association band |
| --- | --- | --- |
| `scheme-small` | Compliance scheme | 1–100 |
| `scheme-medium` | Compliance scheme | 101–500 |
| `scheme-large` | Compliance scheme | 501–2,000 |
| `scheme-very-large` | Compliance scheme | 2,001+ |
| `direct-one` | Direct registrant | 1 |
| `direct-small` | Direct registrant | 2–5 |
| `direct-large` | Direct registrant | 6–20 |

`--scenario all` is the default. The large compliance-scheme scenarios can take many minutes with
default paging. This is expected behaviour in the current design, not a runner failure. Keep the
terminal open until the one-off calls complete.

To make a separate one-page experiment, explicitly override the page size. This is **not** the
default-paging benchmark and should be labelled separately in any result record:

```sh
./future/benchmark/run-real-time-benchmark.sh \
  --year 2025 \
  --scenario scheme-very-large \
  --page-size 50000
```

## Generated default-profile volumes

The checked-in `preprod-complete-2025-prn-shape` profile is an anonymous aggregate snapshot observed
on 20 August 2026. The table shows the unscaled 2025 local plan before a caller chooses one
representative submitter from each band.

| Submitter-volume group | Submitters | Producer associations | Recycling records | PRNs |
| --- | ---: | ---: | ---: | ---: |
| Compliance scheme: 1–100 producers | 5 | 260 | 922 | 564 |
| Compliance scheme: 101–500 producers | 4 | 1,307 | 4,659 | 1,028 |
| Compliance scheme: 501–2,000 producers | 4 | 2,674 | 9,359 | 3,437 |
| Compliance scheme: 2,001+ producers | 1 | 2,093 | 7,425 | 2,794 |
| Direct registrant: 1 producer | 278 | 278 | 964 | 1,646 |
| Direct registrant: 2–5 producers | 17 | 45 | 169 | 242 |
| Direct registrant: 6–20 producers | 2 | 14 | 49 | 137 |
| **Total** | **311** | **6,671** | **23,547** | **9,848** |

There are 6,670 unique producers: the extra association represents one producer linked to two
schemes. The profile contains 9,832 accepted PRNs and 16 awaiting-acceptance PRNs. The retained PRN
shape is deliberately concentrated. Its ranked PRN counts are assigned to organisations in descending
producer-association order, so larger schemes receive the larger PRN populations while retaining the
observed aggregate total. The runner reports the exact ReEx total for each selected organisation.

## Response contracts and sizes

### Recycling Data

```json
{
  "items": [
    {
      "submissionPeriod": "2025-H1",
      "submitterType": "ComplianceScheme",
      "submitterId": "guid",
      "organisationId": "guid",
      "packagingMaterial": "PL",
      "packagingMaterialWeight": 123456,
      "numberOfDaysObligated": null
    }
  ],
  "page": 1,
  "pageSize": 100,
  "totalItems": 7425,
  "useLocalSqlOptimisation": true
}
```

The default response contains at most 100 aggregated recycling records. `totalItems` reveals the
complete result size for the chosen submitter; the benchmark prints both the first-page count and
the total so the number of source pages behind each calculation duration is clear.

This is the **current Synapse-derived aggregation**: it combines approved recycling POM data and
`NumberOfDaysObligated` in the same response record. The embedded application SQL follows the
approved-submissions behaviour but does not call `sp_GetApprovedSubmissionsMyc` at runtime. The
initial synthetic dataset has no determination records, so `numberOfDaysObligated` is normally
`null`; this preserves the current no-data calculation behaviour.

This combined shape is transitional. The intended future direction is to split recycling-data
ingestion/querying from the source of obligation-day information. Until that work exists, this
endpoint is the current aggregation used by both calculation routes and must be treated as the
benchmark input contract.

### ReEx PRNs

```json
{
  "items": [
    {
      "prnId": "guid",
      "prnNumber": "DG...",
      "organisationId": "guid",
      "status": "ACCEPTED",
      "material": "Plastic",
      "tonnage": 123,
      "issueDate": "2026-01-01T00:00:00",
      "accreditationYear": "2026",
      "obligationYear": "2026",
      "decemberWaste": false,
      "isExport": false
    }
  ],
  "page": 1,
  "pageSize": 100,
  "totalItems": 2794
}
```

ReEx also returns at most 100 records by default. For the PRN-aware calculation route, the status,
material, tonnage, obligation year, accreditation year and December-waste flag are all significant:
the service fetches every page and applies accepted/awaiting-acceptance eligibility before assessing
the calculated obligations.

### Calculation responses

| Route | Response shape and expected scale |
| --- | --- |
| `calculate-obligations` | JSON array of detailed transient calculation rows. It scales with the full Recycling Data result and adds a second row for each Glass record. The response can therefore contain thousands of records for a large scheme. |
| `calculate-obligations-with-prns` | Object containing `obligationData` and `numberOfPrnsAwaitingAcceptance`. `obligationData` has seven current material assessments: Aluminium, Glass, Glass Remelt, Plastic, Steel, Wood, and combined Paper/Fibre Composite. Its response is small even where the work to calculate it is large. |

## Interpreting the results

The direct Recycling Data timing for `pageSize=100` is the cost of a **single page request**, not
the cost of retrieving the complete data set. The current query materialises the full approved,
aggregated result and `totalItems` before `OFFSET`/`FETCH` selects the page. A request for one large
page therefore has broadly similar execution time to a request for 100 items; it mostly changes
serialisation and transfer.

That becomes critical for the real-time calculation routes. They require the complete input on every
call, so with default paging a 7,425-record scheme makes roughly 75 Recycling Data requests. Each
request repeats the current aggregation work. The PRN-aware route additionally retrieves all PRN
pages, although ReEx is normally much cheaper than Recycling Data. The overall calculation-call latency—not the
time for an individual first page—is the principal benchmark result.

This behaviour is intentional for the present prototype: the calculation is real-time and reads the
latest available source data on each request. It is not a long-term read-model design. The next
design step is expected to introduce a separate service that ingests recycling data and makes it
independently queryable. Do not attempt to hide the current repeated aggregation with benchmark-only
caching; record the default-page timings first, then evaluate that next service against them.

## Recorded local results

The following current results were captured on 21 August 2026 from the fully started local
obligations and future profiles, after regenerating the 2025 profile with PRNs assigned by descending
producer-association count. Each table cell is one real HTTP request. The calculation calls follow
the direct service calls and can therefore observe their warmed local database cache. They are local
design evidence, not a prediction of Synapse production latency.

Read the two right-most columns first: they are the primary result. The input columns explain how
much source data the real-time calculation traversed. The standalone Recycling Data benchmark below
contains the separate source-query timings. The table below uses the default sequential page
retrieval (`maxConcurrency=1`).

`🟠` marks a response time above the 2-second warning threshold.

| Scenario | Page size | Recycling data (pages) | PRNs (pages) | `calculate-obligations` | `calculate-obligations-with-prns` |
| --- | ---: | ---: | ---: | ---: | ---: |
| Compliance scheme: 1–100 producers | 100 | 190 (2) | 132 (2) | **0.557s** | **0.538s** |
| Compliance scheme: 101–500 producers | 100 | 1,181 (12) | 297 (3) | 🟠 **12.188s** | 🟠 **12.183s** |
| Compliance scheme: 501–2,000 producers | 100 | 2,363 (24) | 599 (6) | 🟠 **85.555s** | 🟠 **83.100s** |
| Compliance scheme: 2,001+ producers | 50,000 | 7,425 (1) | 2,794 (1) | **1.962s** | **1.974s** |
| Direct registrant: 1 producer | 100 | 7 (1) | 6 (1) | **0.169s** | **0.175s** |
| Direct registrant: 2–5 producers | 100 | 16 (1) | 46 (1) | **0.174s** | **0.185s** |
| Direct registrant: 6–20 producers | 100 | 25 (1) | 67 (1) | **0.177s** | **0.182s** |

The 2,001+ scheme is shown with a one-page request because its default size would make each
calculation replay 75 Recycling Data pages, plus 28 PRN pages for the PRN-aware route. Its result is
not comparable with the default-page rows. The standalone Recycling Data benchmark shows that a
larger page does not materially reduce a single query's SQL work; it avoids repeating that work for
every page.

### Concurrent page retrieval comparison

The following fresh comparison was run after recreating the future services and regenerating the
2025 dataset. Each paired call uses the same representative submitter, default downstream paging,
and the runner's normal source calls before the real-time calculation. `maxConcurrency=4` retains a
sequential first page, then retrieves the remaining pages in batches of up to four. The values are
single local requests, so the direction and magnitude are useful design evidence rather than a
production prediction.

| Scenario | Source volume (Recycling / PRNs) | `calculate-obligations`: sequential → 4-way | `calculate-obligations-with-prns`: sequential → 4-way |
| --- | --- | --- | --- |
| Compliance scheme: 101–500 producers | 1,181 records (12 pages) / 297 PRNs (3 pages) | 🟠 **12.188s** → 🟠 **4.943s**<br>**↓ 7.246s (59.4% lower)** | 🟠 **12.183s** → 🟠 **4.441s**<br>**↓ 7.742s (63.5% lower)** |
| Compliance scheme: 501–2,000 producers | 2,363 records (24 pages) / 599 PRNs (6 pages) | 🟠 **85.555s** → 🟠 **26.210s**<br>**↓ 59.345s (69.4% lower)** | 🟠 **83.100s** → 🟠 **25.967s**<br>**↓ 57.133s (68.8% lower)** |

This improves the local prototype materially for multi-page organisations, but it does not remove
the underlying issue: each Recycling Data page still executes the current full aggregation. Four is
therefore an opt-in, bounded local experiment rather than a replacement for the planned recycling
read model. One-page calls have no remaining pages to parallelise and should not be expected to
change.

## Record a result

Keep each benchmark result with the local details needed to repeat it:

- Git commit and `git status --short` output.
- POM year, generator run ID/manifest, profile name, seed and `--increase` value.
- `.env` restore settings, particularly schema set and local-index setting.
- Runner command, whether default or overridden page size was used, and the Markdown table output.
- Docker host details and whether the call followed a cold or warm database/container start.

The older focused benchmarks remain useful for their specific questions:

- [Recycling Data SQL-path benchmark](../recycling-data/README.md#performance-benchmark)
- [Obligations-with-PRNs repeated large-page benchmark](../waste-obligations/README.md#performance-benchmark-and-result-discussion)
- [Data-generator profile and validation workflow](../../tools/data-generator/README.md)
