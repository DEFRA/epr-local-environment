#!/usr/bin/env node
// Seeds compliance declarations for the certificates-of-compliance page.
// Orgs in waste-organisations-seed without a matching folder here become
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

async function patchDeclaration(orgId, declarationId, body) {
  const res = await fetch(
    `${BASE_URL}/organisations/${orgId}/compliance-declarations/${declarationId}`,
    {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', Authorization: AUTH },
      body: JSON.stringify(body)
    }
  )
  if (!res.ok) throw new Error(`PATCH ${orgId}/${declarationId}: ${res.status} ${await res.text()}`)
}

async function listSubdirs(dir) {
  const entries = await readdir(dir, { withFileTypes: true })
  return entries.filter(e => e.isDirectory()).map(e => e.name).sort()
}

async function listJsonFiles(dir) {
  return (await readdir(dir)).filter(f => f.endsWith('.json')).sort()
}

async function seedComplianceDeclaration(filePath, orgId, year) {
  const { _status, _reason, ...payload } = JSON.parse(await readFile(filePath, 'utf8'))
  payload.obligationYear = year
  const created = await postDeclaration(orgId, payload)
  console.log(`Created ${created.id} for ${orgId} year ${year} (target: ${_status})`)
  let patchBody
  switch (_status) {
    case 'Submitted':
      return
    case 'Cancelled':
      patchBody = { status: 'Cancelled', reason: _reason, user: payload.user }
      break
    case 'Accepted':
      patchBody = { status: 'Accepted', user: REGULATOR_USER }
      break
    default:
      throw new Error(`Unknown _status "${_status}" in ${filePath}`)
  }
  await patchDeclaration(orgId, created.id, patchBody)
  console.log(`  Patched ${created.id} to ${_status}`)
}

async function seedComplianceDeclarations() {
  for (const orgId of await listSubdirs(DECLARATIONS_DIR)) {
    const orgDir = join(DECLARATIONS_DIR, orgId)
    for (const yearName of await listSubdirs(orgDir)) {
      const year = Number(yearName)
      const yearDir = join(orgDir, yearName)
      if ((await fetchExisting(orgId, year)).length > 0) {
        console.log(`Skipping ${orgId} year ${year} — already seeded`)
        continue
      }
      for (const file of await listJsonFiles(yearDir)) {
        await seedComplianceDeclaration(join(yearDir, file), orgId, year)
      }
    }
  }
}

await seedComplianceDeclarations()
