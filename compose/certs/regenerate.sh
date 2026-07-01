#!/bin/sh

set -e

cd "$(dirname "$0")"

echo "Regenerating certificate with cert.conf..."
openssl req -x509 -newkey rsa:4096 -keyout https/aspnetapp.key -out https/aspnetapp.crt -days 3650 -nodes -config cert.conf -extensions v3_req
openssl pkcs12 -export -out https/aspnetapp.pfx -inkey https/aspnetapp.key -in https/aspnetapp.crt -password pass:password
openssl pkcs12 -in https/aspnetapp.pfx -clcerts -nokeys -out https/aspnetapp.cer -passin pass:password

echo
echo "Updated certificate:"
openssl x509 -in https/aspnetapp.crt -noout -ext subjectAltName
echo
openssl x509 -in https/aspnetapp.crt -noout -fingerprint -sha256
