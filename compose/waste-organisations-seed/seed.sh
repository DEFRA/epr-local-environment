#!/bin/bash

AUTH=$(echo -n 'waste-organisations-seed:waste-organisations-seed-pwd' | base64)

# User test+17122025143216@ee.com
curl -v -X PUT \
  -H 'Content-Type: application/json' \
  -H "Authorization: Basic $AUTH" \
  -d @/payloads/94bfc917-b9b6-45d7-847b-e5f500bfe198.json \
  http://waste-organisations:8080/organisations/94bfc917-b9b6-45d7-847b-e5f500bfe198

# User test+directproducer@ee.com
curl -v -X PUT \
  -H 'Content-Type: application/json' \
  -H "Authorization: Basic $AUTH" \
  -d @/payloads/e2316c5e-d434-41da-8274-494dc0762d20.json \
  http://waste-organisations:8080/organisations/e2316c5e-d434-41da-8274-494dc0762d20
