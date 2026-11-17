# Mappings

Stubbing a common-data-api endpoint here instead of seeding real data into the Synapse-replica
DB? See
[../../../agents/common-data-api-testing-strategy.md](../../../agents/common-data-api-testing-strategy.md)
for when that's the right call and how to structure the fixture.

## oauth2-token.json

Default client-credentials access token response (`access_token`, `expires_in`).

Used locally by:

- `waste-obligations` (AccountBackend, PrnCommonBackend token endpoints)
- `waste-obligations-frontend` (`BACKEND_ACCOUNT_API_OAUTH_TOKEN_ENDPOINT`) after B2C sign-in when loading user organisations from epr-backend-account-microservice


## epr-pom-api-web-oauth2-token.json

JWT:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlcHItcG9tLWFwaS13ZWIiLCJjbGllbnRfaWQiOiJlcHItcG9tLWFwaS13ZWIiLCJpc3MiOiJ0ZXN0LWlzc3VlciIsImF1ZCI6InRlc3QtYXVkaWVuY2UiLCJpYXQiOjE3Nzc5ODE4MjUsImV4cCI6NDkzMzc0MTgyNX0.0z-PpFb_lOYtJag2jSNk2z3kVhRyRZY0DtL-1r-pQlg
```

To generate again:

```
npm install jsonwebtoken
node -e "console.log(require('jsonwebtoken').sign({ sub: 'epr-pom-api-web', client_id: 'epr-pom-api-web', iss: 'test-issuer', aud: 'test-audience' }, 'super-secret-test-key', { expiresIn: '100y' }))"
```

Note 100 year expiry.

The `client_id` claim is the important one that CDP services look at for what Cognito has allowed through.

## govuk-notify-send-email.json

Stub for `POST /v2/notifications/email`, the GOV.UK Notify .NET client's `SendEmailAsync`
(`NOTIFY-API-NET-CLIENT` user agent). `waste-obligations` points `GovukNotify__BaseAddress` at
`http://wiremock/` (comment it out in compose.yml to hit the real service instead) and calls this
when a compliance declaration is submitted, to send the submitter a confirmation email. Without
this mapping, wiremock 404s ("No matching mapping found") and `Notify.Exceptions.NotifyClientException`
is thrown - logged as "Submitted email could not be sent" but otherwise swallowed, so the
declaration itself still succeeds; this just stops that error and matches what a real send would
return. Response body matches the real API's `SendEmailAsync` response shape (`id`, `content`,
`template`) since the Notify client deserializes the response into a typed model - an empty body
would trade one exception for another.

## log-events.json

Stub for `POST /api/v1/log-events`, EPR.Common.Logging's protective-monitoring event sink
(`LoggingApiClient.SendEventAsync`). Without this mapping, wiremock returns 404 for any
`LoggingApiConfig__BaseUrl`/`LoggingApi__BaseUrl` pointed at it (matches `http://wiremock` in
`compose.yml`), which several services treat as fire-and-forget (swallowed) but
`epr-anti-virus-function-app`'s `AntivirusService.HandleAsync` does not: it awaits
`LogAsync` before creating the `AntivirusResultEvent`/forwarding the scan result onward, so a
404 here throws unhandled and the Service Bus trigger invocation fails before the real
antivirus-result work ever runs — the frontend then polls `GetSubmission` forever waiting for
a scan result that will never arrive.

## common-data-api-approved-submissions.json, common-data-api-approved-submissions-other-years.json

Stub for epr-common-data-api's `GET /api/submissions/v1/pom/approved-submissions/{year}`, read by
`waste-submit-reg-packaging-api` (`submit-data` profile) through `CommonDataApi__BaseUrl`.

**Why a stub:** the endpoint is on epr-common-data-api's `SUB-410-approved-submissions-with-obligations` branch and not
yet on `main`, so the local `epr-common-data-api` image doesn't serve it. This is a temporary exception to the
[testing strategy](../../../agents/common-data-api-testing-strategy.md): once the endpoint is on `main`, seed the
data it reads instead and point the API at `epr-common-data-api` with `SUBMIT_DATA_COMMON_DATA_API_BASE_URL` (see the
`submit-data` section of the main README).

- `2024` returns synthetic rows: a direct registrant (`11111111-1111-4111-8111-111111111111`) with PL and PC, and a
  compliance scheme (`aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`) with four members, one of which left (code `13`,
  2024-09-30).
- Any other year returns `204 No Content`, which the API reads as no data.

The rows follow the shape `CommonDataApiApprovedSubmissionsProvider` in waste-submit-reg-packaging-api reads
(`submitterType`, `submitterId`, `organisationId`, `packagingMaterial`, `packagingMaterialWeightKg`, and the optional
`leaverCode`, `joinerDate`, `leaverDate`). Change them together.
