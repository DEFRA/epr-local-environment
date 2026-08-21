# Waste obligations

The future Compose service `obligations` retrieves approved POM recycling data and calculates
obligations in-process. It has no database and does not persist data.

## Endpoint

```text
GET /organisations/{organisationId}/calculate-obligations?year={year}&page={page}&pageSize={pageSize}
```

`year` is required because it selects the approved POM reporting year. `page` and `pageSize` are
optional and are sent to `recycling-data` only when supplied. When omitted, the first request uses
the downstream defaults (`page=1`, `pageSize=100`). Regardless of the page requested, this service
then obtains every page before calculating, so a calculation always uses the full
approved-recycling dataset for the organisation and year.

The response is `200 OK` with transient calculation obligations. It has no calculation ID because
no row is stored. The calculation uses the material-code map and annual recycling targets in
`calculation-reference-data.json`; update that file when the reference targets change.

For example:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build obligations
organisation_id=$(curl --silent \
  'http://localhost:8016/admin/submitters?year=2025&take=1&submitterType=ComplianceScheme' \
  | jq -r '.items[0].submitterId')
curl "http://localhost:8018/organisations/${organisation_id}/calculate-obligations?year=2025"
```

The request contains no body. The service gets approved recycling data for the organisation from
`recycling-data`, fetches every response page, and applies the same material and glass calculations
locally. It makes no PRN backend HTTP or database call. Both calculation routes return
`Cache-Control: no-store`: although they are GET requests, the response is calculated from the
latest downstream data and must not be reused by browsers or intermediaries.

## Calculated obligations with PRNs

```text
GET /organisations/{organisationId}/calculate-obligations-with-prns?year={year}&page={page}&pageSize={pageSize}
```

This follows the same POM retrieval and transient calculation flow as
`calculate-obligations`, then retrieves every page of the organisation's PRNs from `reex`. It
returns the equivalent of the PRN backend's obligation view, without storing the calculated rows:

- `obligationData` has one entry for each obligation material, with the calculated `tonnage`,
  target, obligation to meet, accepted and awaiting-acceptance PRN tonnage, outstanding tonnage,
  and `Met`, `NotMet`, or `NoDataYet` status.
- Paper and Fibre Composite are combined into the Paper entry, as they are in the PRN backend.
- Only accepted PRNs affect `TonnageAccepted`, the outstanding amount, and the Met/NotMet status.
  Awaiting-acceptance PRNs are returned separately and counted in
  `numberOfPrnsAwaitingAcceptance`.
- The PRN eligibility rules mirror the PRN backend: accepted PRNs must have the calculated
  compliance year; awaiting-acceptance PRNs can also be December waste from the previous
  accreditation year. The normal glass-remelt surplus adjustment is applied before the response
  is returned.

`year` remains the POM submission year. The generated obligation and PRN year is therefore
`year + 1`; for example, a 2025 POM request is matched with PRNs for obligation year 2026.
`page` and `pageSize` are optional. When supplied they are used for the initial calls to both
downstream services; the service always follows every remaining page, so the assessment covers the
full organisation dataset.

For example:

```sh
curl \
  "http://localhost:8018/organisations/${organisation_id}/calculate-obligations-with-prns?year=2025"
```

## Performance benchmark and result discussion

`benchmark-obligations-with-prns.sh` measures the full transient calculation, including retrieval
of all Recycling Data and ReEx pages. Its timings cover only the future-state flow: the `obligations`
endpoint plus its two future-service dependencies. It does not call or time the existing PRN backend.

The default `pageSize=50000` keeps the current generated high-volume scheme in one downstream page.
The endpoint still traverses every page at smaller sizes, but every extra page repeats the Recycling
Data query and increases the measured end-to-end time. Use a page size above the generated result
count to measure the intended full-dataset path, then run a smaller-page test separately if paging
overhead is the subject being assessed.

```sh
./future/waste-obligations/benchmark-obligations-with-prns.sh \
  --year 2025 \
  --page-size 50000
```

By default the script discovers the largest generated compliance scheme. Supply
`--organisation-id {guid}` to use a different generated organisation, and use `--iterations` to
change the number of post-warm-up requests.

### Recorded local result

On 21 August 2026, the largest generated compliance scheme for POM year 2025
(14,850 generated POM rows) was measured with `pageSize=50000`. The three-run benchmark after
warm-up measured **1.965s minimum**, **1.974s median**, **1.972s mean** and **1.977s maximum**.
The call returned seven material assessments and no awaiting-acceptance PRNs. These times include
the full future Recycling Data, ReEx and in-process calculation path only.

For a single real-time call to both obligations routes at every representative generated volume,
using default downstream paging, see the [future-state real-time benchmark](../benchmark/README.md).
