import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import profile from '../profiles/baselines/preprod-pom-2025-prn-2026.json' with { type: 'json' };
import { buildPlan } from './plan.mjs';
import {
  approvedSubmissions,
  assertLinkedAccountAnchors,
  assertPrerequisites,
  assertRunDoesNotExist,
  closeDatabases,
  insertPrns,
  insertSynapseData,
  openDatabases,
  referenceStart,
  removeExistingYear,
  validateDatabaseShape
} from './database.mjs';

const usage = `
EPR local data generator

Usage:
  data-generator generate-year <pom-year> [--seed <value>] [--run-id <id>] [--increase <percent>] [--replace-existing] [--link-local-accounts] [--skip-calculate] [--dry-run]
  data-generator calculate-year <pom-year> --run <run-id>
  data-generator validate-year <pom-year> --run <run-id>
  data-generator profile

Examples:
  docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2025
  docker compose -f compose.yml -f compose.cli.yml run --rm data-generator generate-year 2026 --link-local-accounts
  docker compose -f compose.yml -f compose.cli.yml run --rm data-generator validate-year 2025 --run pom2025-1234567890
`;

function parseArguments(args) {
  const [command = 'help', ...remaining] = args;
  const flags = {};
  const positionals = [];
  for (let index = 0; index < remaining.length; index += 1) {
    const value = remaining[index];
    if (!value.startsWith('--')) {
      positionals.push(value);
      continue;
    }
    const name = value.slice(2);
    if (['link-local-accounts', 'skip-calculate', 'dry-run', 'replace-existing'].includes(name)) {
      flags[name] = true;
      continue;
    }
    const supplied = remaining[index + 1];
    if (!supplied || supplied.startsWith('--')) throw new Error(`--${name} needs a value.`);
    flags[name] = supplied;
    index += 1;
  }
  return { command, year: positionals[0], flags };
}

function manifestDirectory() {
  return process.env.MANIFEST_DIRECTORY ?? path.resolve(process.cwd(), 'manifests');
}

function manifestPath(runId) {
  if (!/^[a-zA-Z0-9-]+$/.test(runId)) throw new Error('Run ID may contain only letters, digits and hyphens.');
  return path.join(manifestDirectory(), `${runId}.json`);
}

async function writeManifest(manifest) {
  await fs.mkdir(manifestDirectory(), { recursive: true });
  await fs.writeFile(manifestPath(manifest.runId), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
}

async function readManifest(runId) {
  try {
    return JSON.parse(await fs.readFile(manifestPath(runId), 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') throw new Error(`No manifest exists for run '${runId}'.`);
    throw error;
  }
}

function toManifest(plan) {
  return {
    version: 1,
    runId: plan.runId,
    profile: profile.name,
    profilePomYear: profile.pomYear,
    generatedAt: new Date().toISOString(),
    status: 'planned',
    pomYear: plan.pomYear,
    obligationYear: plan.obligationYear,
    seed: plan.seed,
    increasePercent: plan.increase,
    linkedLocalAccounts: plan.linkedAccounts,
    replaceExisting: false,
    filePrefix: `data-generator/${plan.runId}/`,
    expected: {
      ...plan.expected,
      PomRows: plan.expected.pomRows,
      MetadataRows: plan.expected.files,
      AcceptedDecisionRows: plan.expected.files,
      PrnRows: plan.expected.prns,
      PrnTonnes: plan.expected.prnTonnes,
      approvedSubmissionRows: plan.expected.materialRows,
      CalculationRows: plan.expected.materialRows + plan.associations.filter((association) => association.materials.has('GL')).length
    },
    submitters: plan.submitters.map((submitter) => ({
      type: submitter.type,
      submitterId: submitter.submitterId,
      referenceNumber: submitter.referenceNumber,
      linkedAccount: submitter.linkedAccount
    })),
    producerIds: [...new Set(plan.associations.map((association) => association.producerExternalId))]
  };
}

function normalised(value) {
  return String(value).toLowerCase();
}

async function calculateYear(synapse, manifest) {
  const source = await approvedSubmissions(synapse, manifest.pomYear);
  const submitterIds = new Set(manifest.submitters.map((submitter) => normalised(submitter.submitterId)));
  const producerIds = new Set(manifest.producerIds.map(normalised));
  const generatedRows = source.filter((row) => submitterIds.has(normalised(row.SubmitterId)) && producerIds.has(normalised(row.OrganisationId)));
  if (generatedRows.length !== manifest.expected.approvedSubmissionRows) {
    throw new Error(`Stored procedure returned ${generatedRows.length} generated rows; expected ${manifest.expected.approvedSubmissionRows}. The run has not been sent to the calculation backend.`);
  }
  const groups = Map.groupBy(generatedRows, (row) => normalised(row.SubmitterId));
  const endpoint = process.env.PRN_BACKEND_URL;
  if (!endpoint) throw new Error('PRN_BACKEND_URL is required to recalculate obligations.');
  const entries = [...groups.entries()];
  const results = [];
  const workers = Array.from({ length: Math.min(6, entries.length) }, async () => {
    while (entries.length > 0) {
      const [submitterId, rows] = entries.shift();
      const response = await fetch(`${endpoint.replace(/\/$/, '')}/api/v1/prn/organisation/${submitterId}/calculate`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(rows)
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(`Calculation backend rejected submitter ${submitterId}: HTTP ${response.status} ${body}`);
      }
      const body = await response.json();
      results.push({ submitterId, sourceRows: rows.length, calculationRows: body?.data?.length ?? null });
    }
  });
  await Promise.all(workers);
  return { sourceRows: generatedRows.length, submitters: results.length, groups: results };
}

function compare(actual, expected, field) {
  const actualNumber = Number(actual[field]);
  const expectedNumber = Number(expected[field]);
  return { field, expected: expectedNumber, actual: actualNumber, matches: actualNumber === expectedNumber };
}

async function validateYear(synapse, prn, manifest) {
  const [actual, source] = await Promise.all([
    validateDatabaseShape(synapse, prn, manifest),
    approvedSubmissions(synapse, manifest.pomYear)
  ]);
  const submitterIds = new Set(manifest.submitters.map((submitter) => normalised(submitter.submitterId)));
  const producerIds = new Set(manifest.producerIds.map(normalised));
  const generatedSourceRows = source.filter((row) => submitterIds.has(normalised(row.SubmitterId)) && producerIds.has(normalised(row.OrganisationId))).length;
  const checks = [
    compare(actual, manifest.expected, 'PomRows'),
    compare(actual, manifest.expected, 'MetadataRows'),
    compare(actual, manifest.expected, 'AcceptedDecisionRows'),
    compare(actual, manifest.expected, 'PrnRows'),
    compare(actual, manifest.expected, 'PrnTonnes'),
    { field: 'ApprovedSubmissionRows', expected: manifest.expected.approvedSubmissionRows, actual: generatedSourceRows, matches: generatedSourceRows === manifest.expected.approvedSubmissionRows }
  ];
  if (manifest.calculation) {
    checks.push(compare(actual, manifest.expected, 'CalculationRows'));
  }
  return { checks, successful: checks.every((check) => check.matches) };
}

async function generateYear(year, flags) {
  let databases;
  try {
    if (flags['dry-run']) {
      const plan = buildPlan(profile, {
        year,
        increase: flags.increase,
        seed: flags.seed,
        runId: flags['run-id'],
        referenceStart: 900000000,
        linkLocalAccounts: flags['link-local-accounts']
      });
      const manifest = toManifest(plan);
      console.log(JSON.stringify({
        dryRun: true,
        runId: manifest.runId,
        profile: manifest.profile,
        pomYear: manifest.pomYear,
        obligationYear: manifest.obligationYear,
        increasePercent: manifest.increasePercent,
        linkedLocalAccounts: manifest.linkedLocalAccounts,
        replaceExisting: Boolean(flags['replace-existing']),
        expected: manifest.expected,
        note: 'No database connection or manifest file was created.'
      }, null, 2));
      return;
    }
    databases = await openDatabases(process.env);
    await assertPrerequisites(databases.synapse);
    const start = await referenceStart(databases.synapse);
    const plan = buildPlan(profile, {
      year,
      increase: flags.increase,
      seed: flags.seed,
      runId: flags['run-id'],
      referenceStart: start,
      linkLocalAccounts: flags['link-local-accounts']
    });
    const manifest = toManifest(plan);
    if (flags['replace-existing']) {
      manifest.replaceExisting = true;
      manifest.removedExisting = await removeExistingYear(databases.synapse, databases.prn, plan.pomYear);
    } else {
      await assertRunDoesNotExist(databases.synapse, plan.runId);
    }
    if (plan.linkedAccounts) await assertLinkedAccountAnchors(process.env, databases.synapse, plan.pomYear);
    await writeManifest(manifest);
    await insertSynapseData(databases.synapse, plan);
    await insertPrns(databases.prn, plan);
    manifest.status = 'generated';
    manifest.generatedAt = new Date().toISOString();
    await writeManifest(manifest);
    if (!flags['skip-calculate']) {
      manifest.calculation = await calculateYear(databases.synapse, manifest);
      manifest.status = 'calculated';
      manifest.calculatedAt = new Date().toISOString();
      await writeManifest(manifest);
    }
    const validation = await validateYear(databases.synapse, databases.prn, manifest);
    manifest.validation = validation;
    manifest.status = validation.successful ? 'validated' : 'validation-failed';
    manifest.validatedAt = new Date().toISOString();
    await writeManifest(manifest);
    console.log(JSON.stringify({ runId: manifest.runId, status: manifest.status, validation }, null, 2));
    if (!validation.successful) process.exitCode = 2;
  } finally {
    await closeDatabases(databases ?? {});
  }
}

async function main() {
  const { command, year, flags } = parseArguments(process.argv.slice(2));
  if (command === 'help' || command === '--help' || command === '-h') {
    console.log(usage.trim());
    return;
  }
  if (command === 'profile') {
    console.log(JSON.stringify(profile, null, 2));
    return;
  }
  if (!year) throw new Error(`${command} needs a POM reporting year.`);
  if (command === 'generate-year') return generateYear(year, flags);
  if (!flags.run) throw new Error(`${command} needs --run <run-id>.`);
  let databases;
  try {
    const manifest = await readManifest(flags.run);
    if (Number(year) !== manifest.pomYear) throw new Error(`Run '${flags.run}' is for POM year ${manifest.pomYear}, not ${year}.`);
    databases = await openDatabases(process.env);
    await assertPrerequisites(databases.synapse);
    if (command === 'calculate-year') {
      manifest.calculation = await calculateYear(databases.synapse, manifest);
      manifest.status = 'calculated';
      manifest.calculatedAt = new Date().toISOString();
      await writeManifest(manifest);
      console.log(JSON.stringify(manifest.calculation, null, 2));
      return;
    }
    if (command === 'validate-year') {
      manifest.validation = await validateYear(databases.synapse, databases.prn, manifest);
      manifest.status = manifest.validation.successful ? 'validated' : 'validation-failed';
      manifest.validatedAt = new Date().toISOString();
      await writeManifest(manifest);
      console.log(JSON.stringify(manifest.validation, null, 2));
      if (!manifest.validation.successful) process.exitCode = 2;
      return;
    }
    throw new Error(`Unknown command '${command}'.\n${usage}`);
  } finally {
    await closeDatabases(databases ?? {});
  }
}

main().catch((error) => {
  const message = error?.message || error?.originalError?.message || error?.cause?.message || String(error);
  console.error(`data-generator: ${message}`);
  const cause = error?.cause;
  if (cause) {
    console.error(JSON.stringify({
      name: cause.name,
      code: cause.code,
      number: cause.number,
      state: cause.state,
      class: cause.class,
      lineNumber: cause.lineNumber,
      originalError: cause.originalError?.message,
      precedingErrors: cause.precedingErrors?.map((item) => item.message)
    }));
  }
  if (error?.stack) console.error(error.stack);
  process.exitCode = 1;
});
