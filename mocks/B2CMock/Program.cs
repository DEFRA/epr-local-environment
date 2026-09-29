// Stands in for Azure AD B2C so the local stack can sign users in without reaching the real
// tenant. The time-shift profile runs containers under faketime, but the real b2clogin.com
// certificate is only valid for a ~3 month window around the real date, so OIDC discovery fails
// the TLS handshake with NotTimeValid at any other TIMESHIFT_DATETIME.
//
// Tokens are genuinely RS256-signed and carry a seeded accounts-DB Users.UserId as oid/sub, so
// epr-facade-account-microservice and the other APIs go on validating tokens for real against the
// real seeded organisations - nothing downstream is stubbed.
//
// Two origins, one listener: the discovery document advertises browser-reachable URLs for the
// endpoints a browser visits (authorize, logout) and docker-network URLs for the ones containers
// call (token, jwks). That avoids needing a shared hostname in /etc/hosts.
//
// Endpoints are matched by path SUFFIX because callers build different paths for the same
// endpoint: the ASP.NET OpenIdConnect handler uses the URLs from the discovery document, while
// MSAL derives its own B2C authority ({instance}/{domain}/{policy}/oauth2/v2.0/token).

using System.Collections.Concurrent;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var config = app.Configuration;
var log = app.Logger;

var internalOrigin = config["B2CMock:InternalOrigin"] ?? "https://b2c-mock:8443";
var browserOrigin = config["B2CMock:BrowserOrigin"] ?? "https://localhost:8443";
var tenantId = config["B2CMock:TenantId"] ?? "8a3f509a-c892-4bec-bfe9-d5f5cf251813";
var policy = config["B2CMock:Policy"] ?? "B2C_1A_EPR_SignUpSignIn";
// Compose passes this through as an empty string when unset, which must not be mistaken for
// a real (unknown) user id.
var autoSelectUserId = config["B2CMock:AutoSelectUserId"] is { Length: > 0 } id ? id : null;

// AadIssuerValidator, which Microsoft.Identity.Web installs by default, expects
// "{authority-host}/{tid}/v2.0" - so shape the issuer that way and emit a matching tid claim.
var issuer = $"{internalOrigin}/{tenantId}/v2.0";

var jsonOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
var users = JsonSerializer.Deserialize<List<MockUser>>(File.ReadAllText("users.json"), jsonOptions) ?? [];
var clients = JsonSerializer.Deserialize<ClientConfig>(File.ReadAllText("clients.json"), jsonOptions)
              ?? new ClientConfig([], "");

// The signing key is committed and stable on purpose. Relying parties cache the JWKS for hours,
// so a key that changed on every restart would make them reject tokens with IDX10503 until they
// were restarted too. It is a local-development key with no more value than the dev certificate
// private keys already committed under compose/certs.
var rsa = RSA.Create();
var signingKeyPath = config["B2CMock:SigningKeyPath"] ?? "signing-key.pem";
if (File.Exists(signingKeyPath))
{
    rsa.ImportFromPem(File.ReadAllText(signingKeyPath));
}
else
{
    rsa = RSA.Create(2048);
}

// Derived from the public key so it is stable for as long as the key is.
var keyId = Base64Url(SHA256.HashData(rsa.ExportRSAPublicKey())[..16]);

var grants = new ConcurrentDictionary<string, Grant>();

// TIMESHIFT_DATETIME is set for the whole compose stack, so the mock can see which fake date the
// time-shifted containers are running at. Tokens must satisfy BOTH clocks at once: the frontend
// runs at the fake date while the facade and the other APIs run at the real one.
var timeshift = ParseTimeshift(config["TIMESHIFT_DATETIME"]);
log.LogInformation(
    "B2C mock: issuer={Issuer} browserOrigin={Browser} users={Count} timeshift={Timeshift} autoSelect={Auto}",
    issuer, browserOrigin, users.Count, timeshift?.ToString("u") ?? "(none)", autoSelectUserId ?? "(off)");

app.Run(async context =>
{
    var path = context.Request.Path.Value ?? "/";

    if (path.EndsWith("/.well-known/openid-configuration", StringComparison.OrdinalIgnoreCase))
    {
        await WriteJson(context, Discovery());
        return;
    }

    if (path.EndsWith("/discovery/v2.0/keys", StringComparison.OrdinalIgnoreCase))
    {
        await WriteJson(context, Jwks());
        return;
    }

    if (path.EndsWith("/oauth2/v2.0/authorize", StringComparison.OrdinalIgnoreCase))
    {
        await Authorize(context);
        return;
    }

    if (path.EndsWith("/oauth2/v2.0/token", StringComparison.OrdinalIgnoreCase))
    {
        await Token(context);
        return;
    }

    if (path.EndsWith("/oauth2/v2.0/logout", StringComparison.OrdinalIgnoreCase))
    {
        Logout(context);
        return;
    }

    if (path.Equals("/health", StringComparison.OrdinalIgnoreCase))
    {
        await context.Response.WriteAsync("OK");
        return;
    }

    context.Response.StatusCode = StatusCodes.Status404NotFound;
    await context.Response.WriteAsync($"B2C mock has no endpoint for {path}");
});

app.Run();
return;

object Discovery() => new Dictionary<string, object?>
{
    ["issuer"] = issuer,
    // Browser-facing: these are the two the user's browser is redirected to.
    ["authorization_endpoint"] = $"{browserOrigin}/oauth2/v2.0/authorize",
    ["end_session_endpoint"] = $"{browserOrigin}/oauth2/v2.0/logout",
    // Container-facing: these are called server-to-server over the docker network.
    ["token_endpoint"] = $"{internalOrigin}/oauth2/v2.0/token",
    ["jwks_uri"] = $"{internalOrigin}/discovery/v2.0/keys",
    ["response_modes_supported"] = new[] { "query", "fragment", "form_post" },
    ["response_types_supported"] = new[] { "code", "id_token", "code id_token", "id_token token" },
    ["grant_types_supported"] = new[] { "authorization_code", "refresh_token", "implicit" },
    ["scopes_supported"] = new[] { "openid", "profile", "offline_access" },
    ["subject_types_supported"] = new[] { "pairwise" },
    ["id_token_signing_alg_values_supported"] = new[] { "RS256" },
    ["token_endpoint_auth_methods_supported"] = new[] { "client_secret_post", "client_secret_basic" },
    ["claims_supported"] = new[]
    {
        "sub", "oid", "tid", "name", "given_name", "family_name", "emails", "tfp", "iss", "iat", "exp", "aud", "nonce"
    }
};

// Microsoft.Identity.Web reads client_info off the AUTHORIZE response to add the uid/utid claims
// that MSAL keys its token cache on, and MSAL reads it again off the TOKEN response to store the
// entry. Both have to agree or AcquireTokenSilent later fails with "user_null".
string ClientInfo(string userId) => Base64Url(JsonSerializer.SerializeToUtf8Bytes(new
{
    uid = $"{userId}-{policy.ToLowerInvariant()}",
    utid = tenantId
}));

object Jwks()
{
    var parameters = rsa.ExportParameters(false);
    return new
    {
        keys = new[]
        {
            new
            {
                kty = "RSA",
                use = "sig",
                alg = "RS256",
                kid = keyId,
                n = Base64Url(parameters.Modulus!),
                e = Base64Url(parameters.Exponent!)
            }
        }
    };
}

async Task Authorize(HttpContext context)
{
    // The picker posts back to this same endpoint, so both verbs land here.
    var source = HttpMethods.IsPost(context.Request.Method)
        ? (await context.Request.ReadFormAsync()).ToDictionary(f => f.Key, f => f.Value.ToString())
        : context.Request.Query.ToDictionary(q => q.Key, q => q.Value.ToString());

    string? Value(string key) => source.TryGetValue(key, out var v) && !string.IsNullOrEmpty(v) ? v : null;

    var redirectUri = Value("redirect_uri");
    var clientId = Value("client_id");
    var state = Value("state");
    var responseMode = Value("response_mode") ?? "query";

    if (redirectUri is null || clientId is null)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        await context.Response.WriteAsync("B2C mock: authorize requires client_id and redirect_uri");
        return;
    }

    var selectedUserId = Value("b2cmock_user") ?? autoSelectUserId;
    var user = users.FirstOrDefault(u => string.Equals(u.UserId, selectedUserId, StringComparison.OrdinalIgnoreCase));

    if (user is null)
    {
        // An unrecognised id is still honoured, so the "user exists in B2C but not in the accounts
        // DB" journey (which redirects to /create-account) stays testable.
        if (selectedUserId is not null)
        {
            user = new MockUser(selectedUserId, $"{selectedUserId}@b2c-mock.local", "Unknown", "User", "(not in accounts DB)", "");
        }
        else
        {
            await WriteHtml(context, PickerPage(source));
            return;
        }
    }

    var code = Base64Url(RandomNumberGenerator.GetBytes(32));
    grants[code] = new Grant(
        user.UserId,
        clientId,
        redirectUri,
        Value("nonce"),
        Value("scope") ?? "openid",
        Value("code_challenge"),
        Value("code_challenge_method"));

    log.LogInformation("B2C mock: issued code for {Email} ({UserId})", user.Email, user.UserId);

    var payload = new Dictionary<string, string?>
    {
        ["code"] = code,
        ["state"] = state,
        ["client_info"] = ClientInfo(user.UserId)
    };

    if (responseMode.Equals("form_post", StringComparison.OrdinalIgnoreCase))
    {
        // ASP.NET Core's OpenIdConnect handler defaults to form_post, so this is the usual path.
        await WriteHtml(context, AutoPostPage(redirectUri, payload));
        return;
    }

    var separator = redirectUri.Contains('?') ? "&" : "?";
    var query = string.Join("&", payload
        .Where(p => p.Value is not null)
        .Select(p => $"{Uri.EscapeDataString(p.Key)}={Uri.EscapeDataString(p.Value!)}"));
    context.Response.Redirect($"{redirectUri}{separator}{query}");
}

async Task Token(HttpContext context)
{
    var form = await context.Request.ReadFormAsync();
    var grantType = form["grant_type"].ToString();
    var isRefresh = grantType == "refresh_token";

    Grant? grant;
    if (isRefresh)
    {
        grants.TryGetValue(form["refresh_token"].ToString(), out grant);
    }
    else
    {
        // Authorization codes are single use; the refresh token below replaces them.
        grants.TryRemove(form["code"].ToString(), out grant);
    }

    if (grant is null)
    {
        await WriteJson(context, new { error = "invalid_grant", error_description = "B2C mock: unknown or already-redeemed code" }, StatusCodes.Status400BadRequest);
        return;
    }

    // PKCE only applies to the code exchange - a refresh carries no verifier.
    if (!isRefresh && !VerifyPkce(grant, form["code_verifier"].ToString()))
    {
        await WriteJson(context, new { error = "invalid_grant", error_description = "B2C mock: PKCE code_verifier does not match code_challenge" }, StatusCodes.Status400BadRequest);
        return;
    }

    var user = users.FirstOrDefault(u => string.Equals(u.UserId, grant.UserId, StringComparison.OrdinalIgnoreCase))
               ?? new MockUser(grant.UserId, $"{grant.UserId}@b2c-mock.local", "Unknown", "User", "(not in accounts DB)", "");

    // A requested scope may be re-scoped per call (MSAL asks for the downstream API separately from
    // the sign-in), so resolve the audience from whatever this request asked for.
    var requestedScope = string.IsNullOrEmpty(form["scope"].ToString()) ? grant.Scope : form["scope"].ToString();
    var (audience, scp) = ResolveAudience(requestedScope);

    var (notBefore, expires) = TokenWindow();
    var expiresIn = (long)(expires - DateTimeOffset.UtcNow).TotalSeconds;

    var idToken = Sign(BaseClaims(user, grant.ClientId, notBefore, expires, grant.Nonce));

    var accessClaims = BaseClaims(user, audience, notBefore, expires, nonce: null);
    accessClaims["scp"] = scp;
    accessClaims["azp"] = grant.ClientId;
    var accessToken = Sign(accessClaims);

    var refreshToken = Base64Url(RandomNumberGenerator.GetBytes(32));
    grants[refreshToken] = grant;

    await WriteJson(context, new Dictionary<string, object?>
    {
        ["access_token"] = accessToken,
        ["id_token"] = idToken,
        ["token_type"] = "Bearer",
        ["scope"] = requestedScope,
        ["expires_in"] = expiresIn,
        ["ext_expires_in"] = expiresIn,
        ["id_token_expires_in"] = expiresIn,
        ["refresh_token"] = refreshToken,
        ["refresh_token_expires_in"] = expiresIn,
        ["not_before"] = notBefore.ToUnixTimeSeconds(),
        ["client_info"] = ClientInfo(user.UserId)
    });
}

void Logout(HttpContext context)
{
    var redirect = context.Request.Query["post_logout_redirect_uri"].ToString();
    context.Response.Redirect(string.IsNullOrEmpty(redirect) ? browserOrigin : redirect);
}

Dictionary<string, object?> BaseClaims(MockUser user, string audience, DateTimeOffset notBefore, DateTimeOffset expires, string? nonce)
{
    var claims = new Dictionary<string, object?>
    {
        ["iss"] = issuer,
        ["aud"] = audience,
        ["exp"] = expires.ToUnixTimeSeconds(),
        ["nbf"] = notBefore.ToUnixTimeSeconds(),
        ["iat"] = notBefore.ToUnixTimeSeconds(),
        // The accounts DB links a B2C user by Users.UserId, matched on oid/sub.
        ["sub"] = user.UserId,
        ["oid"] = user.UserId,
        ["tid"] = tenantId,
        ["name"] = $"{user.GivenName} {user.FamilyName}".Trim(),
        ["given_name"] = user.GivenName,
        ["family_name"] = user.FamilyName,
        // epr-pom-api-web reads emails with .Single() and throws without it.
        ["emails"] = new[] { user.Email },
        ["tfp"] = policy,
        ["ver"] = "1.0"
    };

    if (nonce is not null)
    {
        claims["nonce"] = nonce;
    }

    return claims;
}

// One token has to be valid on two clocks at once - the time-shifted frontend's and the real one
// every other container runs on - so the window is stretched to cover both.
(DateTimeOffset NotBefore, DateTimeOffset Expires) TokenWindow()
{
    var now = DateTimeOffset.UtcNow;
    var earliest = timeshift is { } shift && shift < now ? shift : now;
    var latest = timeshift is { } shift2 && shift2 > now ? shift2 : now;
    return (earliest.AddDays(-1), latest.AddYears(1));
}

(string Audience, string Scope) ResolveAudience(string requestedScope)
{
    var scopes = requestedScope.Split(' ', StringSplitOptions.RemoveEmptyEntries);
    var apiScope = scopes.FirstOrDefault(s => s.StartsWith("https://", StringComparison.OrdinalIgnoreCase));

    if (apiScope is null)
    {
        return (clients.DefaultAudience, string.Join(' ', scopes));
    }

    var match = clients.ScopeAudiences.FirstOrDefault(m => apiScope.StartsWith(m.Prefix, StringComparison.OrdinalIgnoreCase));
    var shortScope = apiScope[(apiScope.LastIndexOf('/') + 1)..];
    return (match?.Audience ?? clients.DefaultAudience, shortScope);
}

bool VerifyPkce(Grant grant, string codeVerifier)
{
    if (grant.CodeChallenge is null)
    {
        return true;
    }

    if (string.IsNullOrEmpty(codeVerifier))
    {
        return false;
    }

    if (string.Equals(grant.CodeChallengeMethod, "plain", StringComparison.OrdinalIgnoreCase))
    {
        return codeVerifier == grant.CodeChallenge;
    }

    return Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(codeVerifier))) == grant.CodeChallenge;
}

string Sign(Dictionary<string, object?> claims)
{
    var header = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT", kid = keyId }));
    var payload = Base64Url(JsonSerializer.SerializeToUtf8Bytes(claims));

    // RSA instances are not thread-safe, and two browsers signing in at once share this one.
    byte[] signature;
    lock (rsa)
    {
        signature = rsa.SignData(Encoding.ASCII.GetBytes($"{header}.{payload}"), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    }

    return $"{header}.{payload}.{Base64Url(signature)}";
}

string PickerPage(Dictionary<string, string> source)
{
    var hidden = new StringBuilder();
    foreach (var (key, value) in source.Where(p => p.Key != "b2cmock_user"))
    {
        hidden.Append($"""<input type="hidden" name="{Encode(key)}" value="{Encode(value)}">""");
    }

    var rows = new StringBuilder();
    foreach (var group in users.GroupBy(u => u.Organisation))
    {
        rows.Append($"<tr><th colspan=\"3\">{Encode(group.Key)}</th></tr>");
        foreach (var user in group)
        {
            rows.Append($"""
                <tr>
                  <td>{Encode(user.GivenName)} {Encode(user.FamilyName)}</td>
                  <td>{Encode(user.Role)}</td>
                  <td><button name="b2cmock_user" value="{Encode(user.UserId)}">Sign in</button>
                      <div class="email">{Encode(user.Email)}</div></td>
                </tr>
                """);
        }
    }

    return $$"""
        <!doctype html>
        <html lang="en">
        <head><meta charset="utf-8"><title>Mock B2C sign-in</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 2rem auto; max-width: 60rem; padding: 0 1rem; }
          h1 { font-size: 1.5rem; }
          p.note { color: #505a5f; }
          table { border-collapse: collapse; width: 100%; }
          th, td { text-align: left; padding: .5rem; border-bottom: 1px solid #b1b4b6; vertical-align: top; }
          th[colspan] { background: #f3f2f1; padding-top: 1rem; }
          button { font: inherit; background: #00703c; color: #fff; border: 0; padding: .4rem .8rem; cursor: pointer; }
          .email { color: #505a5f; font-size: .85rem; margin-top: .25rem; }
        </style>
        </head>
        <body>
          <h1>Mock B2C sign-in</h1>
          <p class="note">This is the local stand-in for Azure AD B2C. Every account below is seeded in the
          accounts database. Set <code>B2CMock__AutoSelectUserId</code> to skip this page.</p>
          <form method="post">
            {{hidden}}
            <table>{{rows}}</table>
          </form>
        </body>
        </html>
        """;
}

string AutoPostPage(string redirectUri, Dictionary<string, string?> payload)
{
    var fields = new StringBuilder();
    foreach (var (key, value) in payload.Where(p => p.Value is not null))
    {
        fields.Append($"""<input type="hidden" name="{Encode(key)}" value="{Encode(value!)}">""");
    }

    return $$"""
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8"><title>Signing in</title></head>
        <body onload="document.forms[0].submit()">
          <form method="post" action="{{Encode(redirectUri)}}">{{fields}}<noscript><button>Continue</button></noscript></form>
        </body></html>
        """;
}

static string Encode(string value) => System.Net.WebUtility.HtmlEncode(value);

static string Base64Url(byte[] bytes) =>
    Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

static DateTimeOffset? ParseTimeshift(string? value) =>
    DateTime.TryParse(value, CultureInfo.InvariantCulture,
        DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var parsed)
        ? new DateTimeOffset(parsed, TimeSpan.Zero)
        : null;

async Task WriteJson(HttpContext context, object body, int status = StatusCodes.Status200OK)
{
    context.Response.StatusCode = status;
    context.Response.ContentType = "application/json";
    await context.Response.WriteAsync(JsonSerializer.Serialize(body));
}

static async Task WriteHtml(HttpContext context, string html)
{
    context.Response.ContentType = "text/html; charset=utf-8";
    await context.Response.WriteAsync(html);
}

internal sealed record MockUser(
    string UserId, string Email, string GivenName, string FamilyName, string Organisation, string Role);

internal sealed record ScopeAudience(string Prefix, string Audience);

internal sealed record ClientConfig(List<ScopeAudience> ScopeAudiences, string DefaultAudience);

internal sealed record Grant(
    string UserId, string ClientId, string RedirectUri, string? Nonce, string Scope,
    string? CodeChallenge, string? CodeChallengeMethod);
