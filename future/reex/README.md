# Reex

`reex` is a future-state .NET minimal API for an organisation's PRNs. It reads the existing
`EprPrnBackend` database directly and does not call `epr-prn-common-backend`.

## Endpoint

```text
GET /organisations/{organisationId}/prns?page={page}&pageSize={pageSize}
```

`page` defaults to `1` and `pageSize` defaults to `100`. Both must be positive integers; there is
deliberately no configured maximum page size. The response contains `items`, `page`, `pageSize` and
`totalItems`. PRNs are ordered by issue date descending, then PRN number and ID.

Each item includes its ID and number, organisation, status, material, tonnage, issue date,
accreditation/obligation years, December-waste flag and export flag.

## Local data discovery

After generating data, the local-only discovery endpoint identifies organisation IDs with the most
PRNs. These IDs can be passed straight to `/organisations/{organisationId}/prns`:

```text
GET /admin/organisations/prns?obligationYear={year}&take={take}
```

For example, to find the ten largest PRN holders for the PRN obligation year corresponding to a 2025
POM run (2026):

```sh
curl 'http://localhost:8013/admin/organisations/prns?obligationYear=2026&take=10'
```

The result is ordered by PRN count, then tonnage. `obligationYear` is optional and `take` defaults to
`10`. The endpoint returns only identifiers and aggregate data, and is intended for local generated
data rather than a business-facing API.

Start it from the future profile:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build reex
organisation_id=$(curl --silent \
  'http://localhost:8013/admin/organisations/prns?obligationYear=2026&take=1' \
  | jq -r '.items[0].organisationId')
curl "http://localhost:8013/organisations/${organisation_id}/prns?page=1&pageSize=100"
```
