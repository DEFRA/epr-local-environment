# Certs management

If a new service is added that uses a different host name ie. the service name in [`compose.yml`](../../compose.yml), then the self signed cert will need recreating:

1. Add the new hostname to [`cert.conf`](cert.conf) as another `DNS.N` entry under `[alt_names]`.

2. Regenerate `aspnetapp.{key,crt,pfx,cer}` with [`regenerate.sh`](regenerate.sh) — it prints the new SAN list at the end, check your hostname is there:

   ```sh
   ./regenerate.sh
   ```

   The `password` baked in matches `ASPNETCORE_Kestrel__Certificates__Default__Password` in `compose.yml`.

3. Commit all four regenerated files alongside `cert.conf`.

## Trusting the certificate

Mac:

```sh
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db https/aspnetapp.cer
```
