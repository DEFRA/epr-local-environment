# Certs management

If a new service is added that uses a different host name ie. the service name in [`compose.yml`](../../compose.yml), then the local service certificate will need recreating:

1. Add the new hostname to [`cert.conf`](cert.conf) as another `DNS.N` entry under `[alt_names]`.

2. Regenerate the `aspnetapp.{key,crt,pfx,cer}` service certificate with [`regenerate.sh`](regenerate.sh) — it prints the service SAN list at the end, check your hostname is there:

   ```sh
   ./regenerate.sh
   ```

   The existing `epr-local-root-ca.{key,crt}` trust anchor is reused, so nobody has to redo the trust steps below. Pass `--new-ca` to replace the trust anchor too — everyone then has to re-trust it.

   Do this with the stack stopped. If the certificates change while containers are running, services end up on different certificate generations and every inter-service HTTPS call fails with `PartialChain` while every container still reports healthy.

   The `password` baked in matches `ASPNETCORE_Kestrel__Certificates__Default__Password` in `compose.yml`.

3. Commit the four regenerated `aspnetapp.*` files alongside `cert.conf` — plus the two `epr-local-root-ca.*` files if you used `--new-ca`.

## Trusting the certificate

### macOS

```sh
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db https/epr-local-root-ca.crt
```

### Firefox on macOS

`epr-local-root-ca` is the local-development trust anchor used to sign the HTTPS
service certificate in this stack. It can be imported from **View Certificates** >
**Authorities**.

To allow Firefox to use the certificate, add its public certificate to the macOS
System Keychain (rather than the per-user login keychain):

```sh
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain https/epr-local-root-ca.crt
```

In Firefox, open `about:config`, set `security.enterprise_roots.enabled` to
`true`, then fully restart Firefox. This enables Firefox to use trusted roots
from the macOS System Keychain.
