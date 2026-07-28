// Stands in for Azure's managed identity token endpoint so DefaultAzureCredential
// (used by epr-payment-facade's TokenAuthorizationHandler in Release builds) can
// succeed locally instead of timing out against the real IMDS/managed-identity
// endpoints, which don't exist outside Azure. Point a client at this via the
// App Service-style IDENTITY_ENDPOINT/IDENTITY_HEADER env vars - Azure.Identity's
// ManagedIdentityCredential picks these up automatically and calls this endpoint
// instead of IMDS.
//
// The issued token is a fixed placeholder string, not a real JWT. This only works
// because the receiving service (epr-payment-service) doesn't validate the bearer
// token it receives - there is no real authentication happening here, just enough
// of the shape DefaultAzureCredential expects to stop it from failing.
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok("Healthy"));

app.MapGet("/{**catchAll}", (HttpRequest request) =>
{
    var resource = request.Query["resource"].ToString();
    var expiresOn = DateTimeOffset.UtcNow.AddHours(1).ToUnixTimeSeconds().ToString();

    return Results.Json(new
    {
        access_token = "fake-local-dev-managed-identity-token",
        expires_on = expiresOn,
        resource,
        token_type = "Bearer",
    });
});

app.Run();
