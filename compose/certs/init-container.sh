#!/bin/sh

set -e

# Trust the local development root CA used to sign the HTTPS service certificate.
cp /https/epr-local-root-ca.crt /usr/local/share/ca-certificates/

# Update system trust store
update-ca-certificates

# Launch main process
exec "$@"
