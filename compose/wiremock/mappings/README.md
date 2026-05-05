# Mappings

## oauth2-token.json

Default access token response.


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
