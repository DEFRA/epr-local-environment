#!/usr/bin/env node
// Seeds compliance declarations for the certificates-of-compliance page.
// Orgs in waste-organisations-seed without a matching file here become
// "Not Submitted" rows (the FE derives that bucket by subtraction).

import { readFile, readdir } from 'node:fs/promises'
import { join } from 'node:path'

const BASE_URL = 'http://waste-obligations:8080'
const AUTH = 'Basic ' + Buffer.from('Developer:developer-pwd').toString('base64')
const DECLARATIONS_DIR = '/payloads/compliance-declarations'

const REGULATOR_USER = {
  id: '45d7c3ca-eacb-4c84-84af-32c19d0e018a',
  email: 'regulator-reviewer@example.com',
  name: 'Regulator Reviewer'
}

async function fetchExisting(orgId, year) {
  const res = await fetch(
    `${BASE_URL}/organisations/${orgId}/compliance-declarations?obligationYear=${year}`,
    { headers: { Authorization: AUTH } }
  )
  if (!res.ok) throw new Error(`GET ${orgId}/${year}: ${res.status} ${await res.text()}`)
  return (await res.json()).complianceDeclarations
}

async function postDeclaration(orgId, payload) {
  const res = await fetch(`${BASE_URL}/organisations/${orgId}/compliance-declarations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: AUTH },
    body: JSON.stringify(payload)
  })
  if (!res.ok) throw new Error(`POST ${orgId}: ${res.status} ${await res.text()}`)
  return res.json()
}

async function patchToAccepted(orgId, declarationId) {
  const res = await fetch(
    `${BASE_URL}/organisations/${orgId}/compliance-declarations/${declarationId}`,
    {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: AUTH },
      body: JSON.stringify({ status: 'Accepted', user: REGULATOR_USER })
    }
  )
  if (!res.ok) throw new Error(`PATCH ${orgId}/${declarationId}: ${res.status} ${await res.text()}`)
}

async function seedDir(targetStatus) {
  const dir = join(DECLARATIONS_DIR, targetStatus)
  for (const file of (await readdir(dir)).filter(f => f.endsWith('.json'))) {
    const payload = JSON.parse(await readFile(join(dir, file), 'utf8'))
    const orgId = payload.organisation.id
    const year = payload.obligationYear
    if ((await fetchExisting(orgId, year)).length > 0) {
      console.log(`Skipping ${orgId} year ${year} — already seeded`)
      continue
    }
    const created = await postDeclaration(orgId, payload)
    console.log(`Created ${created.id} for ${orgId} year ${year}`)
    if (targetStatus === 'Accepted') {
      await patchToAccepted(orgId, created.id)
      console.log(`  Promoted ${created.id} to Accepted`)
    }
  }
}

await seedDir('Submitted')
await seedDir('Accepted')
