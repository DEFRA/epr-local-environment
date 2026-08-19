# Waste obligations

The future Compose service `obligations` retrieves approved POM recycling data and calculates
obligations in-process. It has no database and does not persist data.

## Endpoint

```text
POST /organisations/{organisationId}/calculate-obligations?year={year}&page={page}&pageSize={pageSize}
```

`year` is required because it selects the approved POM reporting year. `page` and `pageSize` are
optional and are sent to `recycling-data` only when supplied. When omitted, the first request uses
the downstream defaults (`page=1`, `pageSize=100`). Regardless of the page requested, this service
then obtains every page before it calls the PRN calculator, so a calculation always uses the full
approved-recycling dataset for the organisation and year.

The response is `200 OK` with transient calculation obligations. It has no calculation ID because
no row is stored. The calculation uses the material-code map and annual recycling targets in
`calculation-reference-data.json`; update that file when the reference targets change.

For example:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build obligations
curl -X POST 'http://localhost:8014/organisations/a1767a6b-0599-5ef9-80d0-a1192c47e090/calculate-obligations?year=2025'
```

The request contains no body. The service gets approved recycling data for the organisation from
`recycling-data`, fetches every response page, and applies the same material and glass calculations
locally. It makes no PRN backend HTTP or database call.
