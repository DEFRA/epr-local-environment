#!/usr/bin/env node
// TEMPORARY: stands in for waste-case-intake-processor until its message processing is built.
//
// Creates a CSoC case for every compliance declaration in waste-obligations, as the Case Intake
// Processor will: one case per submission, keyed on the declaration id, so re-running creates
// nothing new. Each case starts in its declaration's current state.
//
// Once the processor consumes waste-obligations' events, add it to the regulator profile and delete
// this seed (and its service in compose.yml): waste-obligations-seed's declarations will then reach
// Case Management through the real event path instead of being copied across here.

import { createHmac, randomBytes } from 'node:crypto'

const WASTE_OBLIGATIONS_URL = 'http://waste-obligations:8080'
const WASTE_OBLIGATIONS_AUTH = 'Basic ' + Buffer.from('Developer:developer-pwd').toString('base64')
const CASE_MANAGEMENT_URL = 'http://waste-regulator-case-management:8085'
const CASE_INTAKE_CLIENT_ID = 'case-intake-processor'
const CASE_INTAKE_SECRET = process.env.CASE_INTAKE_SECRET

async function fetchAllDeclarations() {
  const declarations = []
  for (let page = 1; ; page++) {
    const res = await fetch(`${WASTE_OBLIGATIONS_URL}/compliance-declarations?page=${page}&pageSize=100`, {
      headers: { Authorization: WASTE_OBLIGATIONS_AUTH }
    })
    if (!res.ok) throw new Error(`GET compliance-declarations page ${page}: ${res.status} ${await res.text()}`)
    const body = await res.json()
    declarations.push(...body.complianceDeclarations)
    if (body.complianceDeclarations.length === 0 || declarations.length >= body.total) return declarations
  }
}

// The legacy v3 form signed by callers with no user role or nation; see the BFF signing contract
// in waste-regulator-case-management's docs/cdp-deployment.md.
function signedIntakeHeaders() {
  const timestamp = new Date().toISOString()
  const nonce = randomBytes(16).toString('base64url')
  const payload = ['v3', CASE_INTAKE_CLIENT_ID, '', '', timestamp, nonce].join('\n')
  return {
    'x-cdp-client-id': CASE_INTAKE_CLIENT_ID,
    'x-cdp-auth-timestamp': timestamp,
    'x-cdp-auth-nonce': nonce,
    'x-cdp-auth-signature': createHmac('sha256', CASE_INTAKE_SECRET).update(payload).digest('base64')
  }
}

function nation(regulator) {
  switch (regulator) {
    case 'Environment Agency':
      return 'ENGLAND'
    case 'Natural Resources Wales':
      return 'WALES'
    case 'Scottish Environment Protection Agency':
      return 'SCOTLAND'
    case 'Northern Ireland Environment Agency':
      return 'N_IRELAND'
    default:
      throw new Error(`Unknown regulator "${regulator}"`)
  }
}

function producerType(registrationType) {
  switch (registrationType) {
    case 'DirectProducer':
      return 'DIRECT_PRODUCER'
    case 'ComplianceScheme':
      return 'COMPLIANCE_SCHEME'
    default:
      throw new Error(`Unknown registration type "${registrationType}"`)
  }
}

function caseState(status) {
  switch (status) {
    case 'Submitted':
      return 'SUBMITTED'
    case 'Accepted':
      return 'ACCEPTED'
    case 'Cancelled':
      return 'CANCELLED'
    default:
      throw new Error(`Unknown compliance declaration status "${status}"`)
  }
}

function organisationName(organisation) {
  switch (organisation.registrationType) {
    case 'DirectProducer':
      return organisation.name
    case 'ComplianceScheme':
      return organisation.schemeOperatorName
    default:
      throw new Error(`Unknown registration type "${organisation.registrationType}"`)
  }
}

async function createCase(declaration) {
  const { organisation } = declaration
  const res = await fetch(`${CASE_MANAGEMENT_URL}/cases`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...signedIntakeHeaders() },
    body: JSON.stringify({
      caseType: 'CSoC',
      sourceSystemId: declaration.id,
      callbackUrl: `${WASTE_OBLIGATIONS_URL}/organisations/${organisation.id}/compliance-declarations/${declaration.id}`,
      nation: nation(organisation.regulator),
      orgId: organisation.id,
      producerType: producerType(organisation.registrationType),
      displayData: {
        organisationName: { value: organisationName(organisation), type: 'string' }
      },
      initialState: caseState(declaration.status),
      createdAt: declaration.created,
      source: 'waste-regulator-case-management-seed'
    })
  })
  if (!res.ok) throw new Error(`POST /cases for declaration ${declaration.id}: ${res.status} ${await res.text()}`)
  const created = await res.json()
  console.log(`Case ${created.id} for declaration ${declaration.id} (${organisationName(organisation)}, ${declaration.obligationYear}, ${declaration.status})`)
}

const declarations = await fetchAllDeclarations()
for (const declaration of declarations) {
  await createCase(declaration)
}
console.log(`Seeded ${declarations.length} CSoC cases`)
