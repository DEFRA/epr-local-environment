#!/bin/sh

set -e

# Copy the pre-extracted cert to trusted store
cp /https/aspnetapp.crt /usr/local/share/ca-certificates/

# Update system trust store
update-ca-certificates

# Launch main process
exec "$@"
