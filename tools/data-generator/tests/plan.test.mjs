import assert from 'node:assert/strict';
import test from 'node:test';
import profile from '../profiles/baselines/preprod-pom-2025-prn-2026.json' with { type: 'json' };
import { buildPlan, normaliseIncrease } from '../src/plan.mjs';

test('normal-volume 2025 plan reproduces the captured aggregate shape', () => {
  const plan = buildPlan(profile, { year: 2025, seed: 'test', referenceStart: 900000000 });
  assert.equal(plan.obligationYear, 2026);
  assert.equal(plan.expected.submitters, 311);
  assert.equal(plan.expected.producers, 6670);
  assert.equal(plan.expected.materialRows, 23547);
  assert.equal(plan.expected.pomRows, 47094);
  assert.equal(plan.expected.files, 622);
  assert.equal(plan.expected.prns, 4046);
  assert.equal(plan.expected.prnTonnes, 6392804);
  assert.equal(plan.associations.filter((association) => association.materials.has('GL')).length, 1068);
  for (const type of ['ComplianceScheme', 'DirectRegistrant']) {
    for (const [material, targetTonnes] of Object.entries(profile.pom.annualTonnes[type])) {
      const generatedTonnes = plan.associations
        .filter((association) => association.type === type)
        .reduce((sum, association) => sum + (association.materials.get(material) ?? 0) / 1000, 0);
      assert.equal(generatedTonnes, targetTonnes, `${type} ${material} tonnage`);
    }
  }
});

test('every producer association has both accepted half-year source rows', () => {
  const plan = buildPlan(profile, { year: 2025, seed: 'period-test', referenceStart: 900000000 });
  const rowsByProducer = Map.groupBy(plan.pomRows, (row) => `${row.organisationReferenceNumber}/${row.subsidiaryReferenceNumber ?? ''}`);
  assert.equal(rowsByProducer.size, plan.associations.length);
  for (const rows of rowsByProducer.values()) {
    assert.ok(rows.some((row) => row.submissionPeriod === '2025-H1'));
    assert.ok(rows.some((row) => row.submissionPeriod === '2025-H2'));
  }
});

test('increase accepts the documented percent syntax and adds connected volume', () => {
  const normal = buildPlan(profile, { year: 2025, seed: 'scale', referenceStart: 900000000 });
  const increased = buildPlan(profile, { year: 2025, seed: 'scale', referenceStart: 900000000, increase: '25%' });
  assert.equal(normaliseIncrease('25%'), 25);
  assert.ok(increased.expected.producers > normal.expected.producers);
  assert.ok(increased.expected.materialRows > normal.expected.materialRows);
  assert.ok(increased.expected.prns > normal.expected.prns);
});
