# Recycling data

The first future-state service is a .NET minimal API that returns approved POM recycling data for
one submitter and reporting year. It runs the query embedded in `Program.cs`; it does **not** call
`dbo.sp_GetApprovedSubmissionsMyc`.

## Endpoint

```text
GET /recycling-data?year={year}&submitterId={guid}&page={page}&pageSize={pageSize}&useLocalSqlOptimisation={true|false}
```

For example, after starting the future profile:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build recycling-data
submitter_id=$(curl --silent \
  'http://localhost:8012/admin/submitters?year=2025&take=1&submitterType=ComplianceScheme' \
  | jq -r '.items[0].submitterId')
curl "http://localhost:8012/recycling-data?year=2025&submitterId=${submitter_id}&page=1&pageSize=100"
```

`year` and `submitterId` are required query parameters. `page` defaults to `1` and `pageSize`
defaults to `100`; both must be positive integers. There is deliberately no configured maximum page
size. `useLocalSqlOptimisation` defaults to `true`; set it to `false` to execute the same request
through the baseline SQL path without local access projections or index predicates. The API uses this
flag to select one of two distinct SQL command texts; it is not passed into SQL as a query parameter.
Responses contain `items`, `page`, `pageSize`, `totalItems` and `useLocalSqlOptimisation`.

## Local data discovery

After the data generator has run, use the local-only discovery endpoint to find submitter IDs that
exercise realistic high volumes:

```text
GET /admin/submitters?year={year}&take={take}&submitterType={type}
```

It returns submitters ordered by generated POM-row volume, with their type, distinct producer count
and packaging-material count. This is a fast way to identify a realistic high-volume target; the
benchmark then reports the exact `/recycling-data` result count.
For example:

```sh
curl 'http://localhost:8012/admin/submitters?year=2025&take=10&submitterType=ComplianceScheme'
```

`year` is required and `take` defaults to `10`. Optionally use `submitterType=ComplianceScheme` or
`submitterType=DirectRegistrant` to focus the ranking. This endpoint is intended for the local
generated dataset; it has no business-facing purpose.

The service fixes the inclusion lists to:

- packaging materials: `AL,FC,GL,PC,PL,ST,WD`;
- packaging types: `HH,NH,PB,HDC,NDC`.

The database connection is supplied through `ConnectionStrings__EprCommonData`. In the local future
profile it connects to the same `EprCommonData` database as Common Data API. The query retains the
upstream `dbo.udf_DQ_SubmissionPeriod` data-quality helper, but has no dependency on the approved
submissions stored procedure.

## Performance benchmark

Use [`benchmark-recycling-data.sh`](benchmark-recycling-data.sh) after starting `recycling-data` to
measure equivalent requests through both SQL paths. It makes one unmeasured warm-up call for each
path, then reports minimum, median, mean and maximum end-to-end HTTP durations. It also fails if the
two payloads differ after omitting `useLocalSqlOptimisation`.

The baseline path (`useLocalSqlOptimisation=false`) retains the source-query behaviour but runs on
the local SQL Server replica. It is a comparison baseline, not an emulation or timing of a Synapse
dedicated SQL pool. The local path (`true`) adds the local-only bounded access projections, indexes
and early submitter restriction.

Unless `--submitter-id` is supplied, the script calls `/admin/submitters?take=1` with
`submitterType=ComplianceScheme` and uses the largest discovered compliance scheme for the requested
year. It prints the actual `totalItems`, so it follows each new data-generator run rather than relying
on an obsolete fixed ID.

Run the normal paged request first:

```sh
./future/recycling-data/benchmark-recycling-data.sh \
  --year 2025 \
  --page-size 100
```

Then request one large page. `pageSize=10000` exceeds the current 7,377-row result and therefore
drives the full result set through a single page, which tests JSON serialisation and transfer as well
as the database query:

```sh
./future/recycling-data/benchmark-recycling-data.sh \
  --year 2025 \
  --page-size 10000
```

Use a page size greater than the displayed `totalItems` for a one-page test after generating a
different volume. To benchmark a specific discovered record, add `--submitter-id {guid}`. Keep the
year, submitter, page size and iteration count unchanged when comparing the two modes.

### Recorded local result

The following is a local snapshot from 19 August 2026, using the generated 2025 dataset and the
largest discovered compliance scheme. It returned 7,377 recycling rows. Timings are mean end-to-end
HTTP durations after warm-up, and will vary by machine and local database state.

| Request | Baseline source-style SQL | Local SQL Server optimisation |
| --- | ---: | ---: |
| `page=1&pageSize=100` | 2.57s | 2.11s |
| `page=1&pageSize=10000` (all 7,377 rows in one response) | 2.55s | 2.11s |

The two SQL modes returned equivalent payloads in both cases, excluding the diagnostic
`useLocalSqlOptimisation` response field. The near-identical timings for `100` and `10000` show that
the query materialises and aggregates the whole result before applying `OFFSET`/`FETCH`; a smaller
page only reduces response serialisation and transfer for that one call.

This does **not** mean that retrieving all data through small pages is equivalent to one large page.
At `pageSize=100`, 7,377 rows need 74 requests, and each request reruns the full query. Where a
consumer needs the entire result, a one-page request with a safely sufficient page size avoids those
repeated database executions. Paging remains useful when the consumer only needs one page or should
limit its response-body size.

### Why optimisation stops here

The local SQL Server optimisation has already introduced the submitter restriction early and uses
local-only access projections and indexes. It improves the representative request by about 18%, but
it cannot make a small page an inexpensive database operation while retaining the current response
contract. Before `OFFSET`/`FETCH` can run, the query must identify latest accepted files, pair the
two half-year submissions, join and aggregate POM rows, apply determination data, order the final
records, and calculate `totalItems`. Applying `TOP` earlier would produce an incomplete or incorrectly
ordered result.

Further indexes or local-only query rewrites are therefore stopped at this point. They would add
restore time, storage and divergence from the Synapse source for diminishing and uncertain benefit;
the remaining work is intrinsic to rebuilding the complete result on every request. This baseline is
useful for validating future designs, but it is not the intended long-term latency solution.

If a lower latency is required for small-page requests, the next work should be architectural rather
than another index iteration:

- make `totalItems` opt-in or retrieve it separately, then measure the saving;
- use a cursor/keyset page contract for an already ordered result; and/or
- build a year-and-submitter recycling read model or cache, indexed for organisation and material,
  and refresh it when source POM decisions change.

The last option permits an indexed page lookup rather than reconstructing the calculation on every
request. It should be evaluated against the actual Synapse implementation as well as this local SQL
Server representation.
