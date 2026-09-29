#!/bin/sh

set -e

cd "$(dirname "$0")"

# Backdated so the certificates are valid at any TIMESHIFT_DATETIME, not just from the day they
# were generated: faketime'd containers check them against the fake clock, and .NET rejects a
# chain with NotTimeValid if the root or the leaf is not yet valid.
not_before=20200101000000Z
not_after=20391231235959Z

# -not_before/-not_after need OpenSSL 3.4+. macOS /usr/bin/openssl is LibreSSL; use Homebrew's.
if ! openssl x509 -help 2>&1 | grep -q -- -not_before; then
  echo "$(openssl version) does not support -not_before; install OpenSSL 3.4+ (brew install openssl)" >&2
  exit 1
fi

new_ca=false
case "${1:-}" in
  --new-ca) new_ca=true ;;
  "") ;;
  *) echo "usage: $(basename "$0") [--new-ca]" >&2; exit 1 ;;
esac

if [ ! -f https/epr-local-root-ca.key ] || [ ! -f https/epr-local-root-ca.crt ]; then
  new_ca=true
fi

if [ "$new_ca" = true ]; then
  echo "Regenerating the local root CA..."
  openssl req -x509 -newkey rsa:4096 -keyout https/epr-local-root-ca.key -out https/epr-local-root-ca.crt -not_before "$not_before" -not_after "$not_after" -nodes -config cert.conf -extensions root_ca
else
  # Adding a SAN only needs a new leaf. Keeping the existing trust anchor means nobody has to
  # re-run the "Trusting the certificate" steps below on their machine or in their browser.
  echo "Reusing the existing local root CA (pass --new-ca to replace it)."
fi

echo "Regenerating the service certificate with cert.conf..."
openssl req -new -newkey rsa:4096 -keyout https/aspnetapp.key -nodes -subj "/CN=localhost" |
  openssl x509 -req -CA https/epr-local-root-ca.crt -CAkey https/epr-local-root-ca.key -set_serial 0x01 -out https/aspnetapp.crt -not_before "$not_before" -not_after "$not_after" -sha256 -extfile cert.conf -extensions server_cert
openssl pkcs12 -export -out https/aspnetapp.pfx -inkey https/aspnetapp.key -in https/aspnetapp.crt -certfile https/epr-local-root-ca.crt -password pass:password
openssl pkcs12 -in https/aspnetapp.pfx -clcerts -nokeys -passin pass:password | openssl x509 -out https/aspnetapp.cer

echo
echo "Updated service certificate:"
openssl x509 -in https/aspnetapp.crt -noout -ext subjectAltName
echo
openssl x509 -in https/aspnetapp.crt -noout -fingerprint -sha256 -dates

if [ "$new_ca" = true ]; then
  echo
  echo "The root CA changed - re-trust it on this machine, see the README."
fi
