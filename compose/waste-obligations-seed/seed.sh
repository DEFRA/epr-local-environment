#!/bin/sh
# Seeds compliance-declarations into waste-obligations for the regulator-profile
# certificates-of-compliance page. Requires waste-organisations to already be
# seeded (the create endpoint reads the org from waste-organisations first).

set -eu

AUTH=$(printf 'Developer:developer-pwd' | base64 | tr -d '\n')
BASE_URL=http://waste-obligations:8080

post_declaration() {
  PAYLOAD=$1
  ORG_ID=$2
  YEAR=$3

  sed "s/\"obligationYear\": 2025/\"obligationYear\": $YEAR/" "$PAYLOAD" | curl -fsS -X POST \
    -H 'Content-Type: application/json' \
    -H "Authorization: Basic $AUTH" \
    -d @- \
    "$BASE_URL/organisations/$ORG_ID/compliance-declarations"
  echo
}

# Direct producer declarations across multiple years
for YEAR in 2025 2026; do
  post_declaration /payloads/direct-producer.json e2316c5e-d434-41da-8274-494dc0762d20 "$YEAR"
done

# Compliance scheme declarations across multiple years
for YEAR in 2025 2026; do
  post_declaration /payloads/compliance-scheme.json d93376e3-0681-46be-aeb4-7450a2e784d8 "$YEAR"
done
