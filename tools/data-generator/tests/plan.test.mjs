import assert from 'node:assert/strict';
import test from 'node:test';
import profile from '../profiles/baselines/preprod-complete-2025-prn-shape.json' with { type: 'json' };
import { buildPlan, normaliseIncrease } from '../src/plan.mjs';

test('normal-volume 2025 plan reproduces the completed 2025 PRN shape', () => {
  const plan = buildPlan(profile, { year: 2025, seed: 'test', referenceStart: 900000000 });
  assert.equal(plan.obligationYear, 2026);
  assert.equal(plan.expected.submitters, 311);
  assert.equal(plan.expected.producers, 6670);
  assert.equal(plan.expected.materialRows, 23547);
  assert.equal(plan.expected.pomRows, 47094);
  assert.equal(plan.expected.files, 622);
  assert.equal(plan.expected.prns, 9848);
  assert.equal(plan.expected.prnTonnes, 7500044);
  assert.ok(plan.prns.every((prn) => prn.prnNumber.length <= 20));
  assert.equal(plan.prns.filter((prn) => prn.status === 'ACCEPTED').length, 9832);
  assert.equal(plan.prns.filter((prn) => prn.status === 'AWAITINGACCEPTANCE').length, 16);
  const prnCounts = [...Map.groupBy(plan.prns, (prn) => prn.submitterId).values()]
    .map((prns) => prns.length)
    .sort((left, right) => right - left);
  assert.deepEqual(prnCounts.slice(0, 20), [
    2794, 1833, 599, 594, 411, 297, 255, 249, 227, 152,
    132, 115, 84, 81, 70, 67, 49, 46, 42, 28
  ]);
  const prnCountBySubmitter = new Map(
    Map.groupBy(plan.prns, (prn) => prn.submitterId)
      .entries()
      .map(([submitterId, prns]) => [submitterId, prns.length])
  );
  const schemesByProducerCount = plan.submitters
    .filter((submitter) => submitter.type === 'ComplianceScheme')
    .sort((left, right) => right.producerCount - left.producerCount || left.index - right.index);
  assert.deepEqual(
    schemesByProducerCount.map((submitter) => prnCountBySubmitter.get(submitter.submitterId)),
    [2794, 1833, 599, 594, 411, 297, 255, 249, 227, 152, 132, 115, 84, 81]
  );
  const largeDirectRegistrants = plan.submitters
    .filter((submitter) => submitter.type === 'DirectRegistrant' && submitter.producerCount >= 6)
    .sort((left, right) => right.producerCount - left.producerCount || left.index - right.index);
  assert.deepEqual(
    largeDirectRegistrants.map((submitter) => prnCountBySubmitter.get(submitter.submitterId)),
    [70, 67]
  );
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
  assert.equal(increased.expected.prns, 12310);
  assert.equal(
    Math.max(...Map.groupBy(increased.prns, (prn) => prn.submitterId).values().map((prns) => prns.length)),
    3493
  );
});
