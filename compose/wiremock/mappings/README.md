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
