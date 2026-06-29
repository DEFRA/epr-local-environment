#!/usr/bin/env node
// Seeds organisations into waste-organisations across multiple registration
// years. PUT is upsert-by-(id, year), so re-running is safe.
//
// Every /payloads/*.json file is sent once per year in YEARS; the basename
// (minus .json) is used as the organisation id, and registrationYear is
// stamped into the payload before each PUT.

import { readFile, readdir } from 'node:fs/promises'
import { basename, join } from 'node:path'

const BASE_URL = 'http://waste-organisations:8080'
const AUTH = 'Basic ' + Buffer.from('waste-organisations-seed:waste-organisations-seed-pwd').toString('base64')
const PAYLOAD_DIR = '/payloads'
const YEARS = [2025, 2026, 2027, 2028, 2029, 2030]

async function putOrganisation(orgId, payload) {
  const res = await fetch(`${BASE_URL}/organisations/${orgId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: AUTH
    },
    body: JSON.stringify(payload)
  })
  if (!res.ok) {
    throw new Error(`PUT ${orgId} (year ${payload.registration.registrationYear}): ${res.status} ${await res.text()}`)
  }
}

const files = (await readdir(PAYLOAD_DIR)).filter(f => f.endsWith('.json'))

for (const year of YEARS) {
  for (const file of files) {
    const orgId = basename(file, '.json')
    const payload = JSON.parse(await readFile(join(PAYLOAD_DIR, file), 'utf8'))
    payload.registration.registrationYear = year
    await putOrganisation(orgId, payload)
    console.log(`PUT organisation ${orgId} for year ${year}`)
  }
}
