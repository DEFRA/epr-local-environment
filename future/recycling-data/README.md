# Recycling data

The first future-state service is a .NET minimal API that returns approved POM recycling data for
one submitter and reporting year. It runs the query embedded in `Program.cs`; it does **not** call
`dbo.sp_GetApprovedSubmissionsMyc`.

## Endpoint

```text
GET /recycling-data?year={year}&submitterId={guid}&page={page}&pageSize={pageSize}
```

For example, after starting the future profile:

```sh
docker compose -f compose.yml -f compose.future.yml --profile future up --build recycling-data
curl 'http://localhost:8012/recycling-data?year=2025&submitterId=a1767a6b-0599-5ef9-80d0-a1192c47e090&page=1&pageSize=100'
```

`year` and `submitterId` are required query parameters. `page` defaults to `1` and `pageSize`
defaults to `100`; both must be positive integers. There is deliberately no configured maximum page
size. Responses contain `items`, `page`, `pageSize` and `totalItems`.

The service fixes the inclusion lists to:

- packaging materials: `AL,FC,GL,PC,PL,ST,WD`;
- packaging types: `HH,NH,PB,HDC,NDC`.

The database connection is supplied through `ConnectionStrings__EprCommonData`. In the local future
profile it connects to the same `EprCommonData` database as Common Data API. The query retains the
upstream `dbo.udf_DQ_SubmissionPeriod` data-quality helper, but has no dependency on the approved
submissions stored procedure.
