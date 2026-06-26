#!/usr/bin/env node
// Seeds compliance-declarations into waste-obligations for the
// regulator-profile certificates-of-compliance page. Requires
// waste-organisations to already be seeded (the create endpoint reads
// the org from waste-organisations first).
//
// Idempotent: the POST endpoint has no upsert and generates server-side
// ids, so we GET existing declarations for the (org, year) pair first
// and skip if any are already present. Without this, every docker up
// would accumulate duplicate rows.

import { readFile } from 'node:fs/promises'

const BASE_URL = 'http://waste-obligations:8080'
const AUTH = 'Basic ' + Buffer.from('Developer:developer-pwd').toString('base64')

async function declarationExists(orgId, year) {
  const res = await fetch(
    `${BASE_URL}/organisations/${orgId}/compliance-declarations?obligationYear=${year}`,
    { headers: { Authorization: AUTH } }
  )
  if (!res.ok) {
    throw new Error(`GET ${orgId}/${year} failed: ${res.status} ${await res.text()}`)
  }
  const { complianceDeclarations } = await res.json()
  return complianceDeclarations.length > 0
}

async function postDeclaration(payloadPath, orgId, year) {
  if (await declarationExists(orgId, year)) {
    console.log(`Skipping ${orgId} for ${year} — declaration already exists`)
    return
  }

  const body = JSON.parse(await readFile(payloadPath, 'utf8'))
  body.obligationYear = year

  const res = await fetch(`${BASE_URL}/organisations/${orgId}/compliance-declarations`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH
    },
    body: JSON.stringify(body)
  })

  if (!res.ok) {
    throw new Error(`POST ${orgId}/${year} failed: ${res.status} ${await res.text()}`)
  }
  console.log(`Created declaration for ${orgId} year ${year}`)
}

const directProducerId = 'e2316c5e-d434-41da-8274-494dc0762d20'
const complianceSchemeId = 'd93376e3-0681-46be-aeb4-7450a2e784d8'

for (const year of [2025, 2026]) {
  await postDeclaration('/payloads/direct-producer.json', directProducerId, year)
}

for (const year of [2025, 2026]) {
  await postDeclaration('/payloads/compliance-scheme.json', complianceSchemeId, year)
}
