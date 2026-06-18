#!/bin/bash

AUTH=$(echo -n 'waste-organisations-seed:waste-organisations-seed-pwd' | base64)

put_organisation() {
  PAYLOAD=$1
  YEAR=$2
  ORGANISATION_ID=$(basename "$PAYLOAD" .json)

  sed "s/\"registrationYear\": 2025/\"registrationYear\": $YEAR/" "$PAYLOAD" | curl -v -X PUT \
    -H 'Content-Type: application/json' \
    -H "Authorization: Basic $AUTH" \
    -d @- \
    "http://waste-organisations:8080/organisations/$ORGANISATION_ID"
}

for YEAR in 2025 2026 2027 2028 2029 2030; do
  # User test+17122025143216@ee.com - compliance scheme
  # the ID is taken from the compliance scheme external ID and not the org
  put_organisation \
    /payloads/d93376e3-0681-46be-aeb4-7450a2e784d8.json \
    "$YEAR"

  # User test+directproducer@ee.com - producer
  # the ID is taken from the organisation external ID
  put_organisation \
    /payloads/e2316c5e-d434-41da-8274-494dc0762d20.json \
    "$YEAR"
done
