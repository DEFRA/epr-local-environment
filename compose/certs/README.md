# Certs management

If a new service is added that uses a different host name ie. the service name in [`compose.yml`](../../compose.yml), then the local service certificate will need recreating:

1. Add the new hostname to [`cert.conf`](cert.conf) as another `DNS.N` entry under `[alt_names]`.

2. Regenerate the `epr-local-root-ca.{key,crt}` trust anchor and `aspnetapp.{key,crt,pfx,cer}` service certificate with [`regenerate.sh`](regenerate.sh) — it prints the service SAN list at the end, check your hostname is there:

   ```sh
   ./regenerate.sh
   ```

   The `password` baked in matches `ASPNETCORE_Kestrel__Certificates__Default__Password` in `compose.yml`.

3. Commit all six regenerated certificate files alongside `cert.conf`.

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
