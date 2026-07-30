#!/bin/sh

set -e

cd "$(dirname "$0")"

echo "Regenerating local root CA and service certificate with cert.conf..."
openssl req -x509 -newkey rsa:4096 -keyout https/epr-local-root-ca.key -out https/epr-local-root-ca.crt -days 3650 -nodes -config cert.conf -extensions root_ca
openssl req -new -newkey rsa:4096 -keyout https/aspnetapp.key -nodes -subj "/CN=localhost" |
  openssl x509 -req -CA https/epr-local-root-ca.crt -CAkey https/epr-local-root-ca.key -set_serial 0x01 -out https/aspnetapp.crt -days 3650 -sha256 -extfile cert.conf -extensions server_cert
openssl pkcs12 -export -out https/aspnetapp.pfx -inkey https/aspnetapp.key -in https/aspnetapp.crt -certfile https/epr-local-root-ca.crt -password pass:password
openssl pkcs12 -in https/aspnetapp.pfx -clcerts -nokeys -passin pass:password | openssl x509 -out https/aspnetapp.cer

echo
echo "Updated service certificate:"
openssl x509 -in https/aspnetapp.crt -noout -ext subjectAltName
echo
openssl x509 -in https/aspnetapp.crt -noout -fingerprint -sha256
