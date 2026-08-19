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

Start it from the future profile:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build reex
curl 'http://localhost:8013/organisations/a1767a6b-0599-5ef9-80d0-a1192c47e090/prns?page=1&pageSize=100'
```
