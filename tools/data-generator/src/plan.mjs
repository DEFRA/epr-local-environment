import crypto from 'node:crypto';

const LINKED_ACCOUNTS = {
  scheme: {
    accountExternalId: '0bb650b9-125e-4d64-b1d0-06b9e167b2d4',
    referenceNumber: 110000,
    submitterId: 'cac58048-62a1-4419-9bee-4b386454d776',
    name: 'Northbridge Compliance Solutions Ltd'
  },
  direct: {
    referenceNumber: 165282,
    externalId: 'e2316c5e-d434-41da-8274-494dc0762d20',
    name: 'POP QUEST LTD'
  }
};

export function normaliseIncrease(value = '0') {
  if (typeof value === 'number') return value;
  const parsed = Number(String(value).trim().replace(/%$/, ''));
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 200) {
    throw new Error('--increase must be a percentage from 0 to 200.');
  }
  return parsed;
}

export function createRandom(seed) {
  let state = 2166136261;
  for (const char of String(seed)) {
    state ^= char.charCodeAt(0);
    state = Math.imul(state, 16777619);
  }
  return () => {
    state += 0x6D2B79F5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

export function deterministicUuid(value) {
  const bytes = crypto.createHash('sha1').update(`epr-data-generator:${value}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function shuffled(values, random) {
  const copy = [...values];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const target = Math.floor(random() * (index + 1));
    [copy[index], copy[target]] = [copy[target], copy[index]];
  }
  return copy;
}

function distribute(total, count) {
  const base = Math.floor(total / count);
  return Array.from({ length: count }, (_, index) => base + (index < total % count ? 1 : 0));
}

function allocateWeightedIntegers(total, ids, random) {
  const weights = ids.map(() => 0.2 + -Math.log(Math.max(random(), Number.EPSILON)));
  const weightTotal = weights.reduce((sum, value) => sum + value, 0);
  const allocated = weights.map((weight) => Math.max(1, Math.floor((total * weight) / weightTotal)));
  let remainder = total - allocated.reduce((sum, value) => sum + value, 0);
  const order = shuffled(ids.map((_, index) => index), random);
  for (let index = 0; remainder > 0; index = (index + 1) % order.length) {
    allocated[order[index]] += 1;
    remainder -= 1;
  }
  return allocated;
}

function assignMaterials(associations, materialRows, random) {
  const slots = associations.map((association) => ({ ...association, materials: new Map() }));
  for (const [material, total] of Object.entries(materialRows)) {
    if (total > slots.length) throw new Error(`Profile requests ${total} ${material} rows for only ${slots.length} producer associations.`);
    for (const slotIndex of shuffled(slots.map((_, index) => index), random).slice(0, total)) {
      slots[slotIndex].materials.set(material, 0);
    }
  }
  for (const empty of slots.filter((slot) => slot.materials.size === 0)) {
    const donor = slots.find((slot) => slot.materials.size > 1);
    if (!donor) throw new Error('Profile has insufficient POM material rows to cover every producer association.');
    const [material, weight] = donor.materials.entries().next().value;
    donor.materials.delete(material);
    empty.materials.set(material, weight);
  }
  return slots;
}

function materialiseWeights(slots, annualTonnes, random) {
  for (const [material, tonnes] of Object.entries(annualTonnes)) {
    const matching = slots.filter((slot) => slot.materials.has(material));
    // Allocate whole tonnes to each producer/material pair. The stored procedure
    // rounds each pair after aggregating H1/H2, so this preserves the baseline
    // output-tonne total exactly instead of accumulating per-row rounding drift.
    const allocations = allocateWeightedIntegers(Math.round(tonnes), matching, random);
    matching.forEach((slot, index) => slot.materials.set(material, allocations[index] * 1000));
  }
}

function createAssociations(type, submitterDefinitions, reference, runId, random) {
  const submitters = [];
  const associations = [];
  let submitterIndex = 0;
  for (const definition of submitterDefinitions) {
    for (const producerCount of distribute(definition.totalProducers, definition.submitterCount)) {
      const key = `${type}:${submitterIndex}`;
      const submitter = {
        type,
        index: submitterIndex,
        key,
        referenceNumber: reference.next(),
        externalId: deterministicUuid(`${runId}:submitter-account:${key}`),
        submitterId: type === 'ComplianceScheme'
          ? deterministicUuid(`${runId}:submitter-scheme:${key}`)
          : null,
        name: `Synthetic ${type === 'ComplianceScheme' ? 'scheme' : 'direct registrant'} ${String(submitterIndex + 1).padStart(3, '0')}`,
        producerCount,
        linkedAccount: false
      };
      if (type === 'DirectRegistrant') submitter.submitterId = submitter.externalId;
      submitters.push(submitter);
      for (let producerIndex = 0; producerIndex < producerCount; producerIndex += 1) {
        const isDirectRoot = type === 'DirectRegistrant' && producerIndex === 0;
        associations.push({
          type,
          submitter,
          producerReferenceNumber: isDirectRoot ? submitter.referenceNumber : reference.next(),
          producerExternalId: isDirectRoot ? submitter.externalId : deterministicUuid(`${runId}:producer:${key}:${producerIndex}`),
          producerName: isDirectRoot ? submitter.name : `Synthetic producer ${type === 'ComplianceScheme' ? 'CS' : 'DR'}-${submitterIndex + 1}-${producerIndex + 1}`
        });
      }
      submitterIndex += 1;
    }
  }
  return { submitters, associations: shuffled(associations, random) };
}

function createPrnCounts(submitters, total, rankedCounts, random) {
  if (rankedCounts.length > submitters.length) {
    throw new Error('Profile has more ranked PRN counts than generated submitters.');
  }

  const rankedTotal = rankedCounts.reduce((sum, count) => sum + count, 0);
  if (rankedTotal > total) {
    throw new Error('Profile ranked PRN counts exceed the status total.');
  }

  const remainingSubmitterCount = submitters.length - rankedCounts.length;
  const remainingTotal = total - rankedTotal;
  if (remainingSubmitterCount === 0) {
    if (remainingTotal !== 0) {
      throw new Error('Profile has PRNs remaining after all submitters received ranked counts.');
    }

    return rankedCounts;
  }

  return [
    ...rankedCounts,
    ...shuffled(distribute(remainingTotal, remainingSubmitterCount), random)
  ];
}

function createPrns(submitters, profile, runId, random) {
  const prns = [];
  const prnRunKey = crypto.createHash('sha1').update(runId).digest('hex').slice(0, 8);
  const materialNames = {
    AL: 'Aluminium', FC: 'Fibre', GL: 'Glass Other', GR: 'Glass Re-melt',
    PC: 'Paper/board', PL: 'Plastic', ST: 'Steel', WD: 'Wood'
  };
  const materials = Object.entries(profile.pom.annualTonnes.ComplianceScheme)
    .map(([code, tonnes]) => ({ code, tonnes }))
    .concat(Object.entries(profile.pom.annualTonnes.DirectRegistrant).map(([code, tonnes]) => ({ code, tonnes })));
  const chooseMaterial = () => {
    const total = materials.reduce((sum, item) => sum + item.tonnes, 0);
    let cursor = random() * total;
    for (const material of materials) {
      cursor -= material.tonnes;
      if (cursor <= 0) return material.code;
    }
    return materials.at(-1).code;
  };
  for (const [status, total] of Object.entries(profile.prn.statusCounts)) {
    if (total === 0) continue;

    const counts = createPrnCounts(
      submitters,
      total,
      profile.prn.rankedSubmitterCounts[status] ?? [],
      random
    );
    const rowKeys = [];
    counts.forEach((count, submitterIndex) => {
      for (let index = 0; index < count; index += 1) {
        rowKeys.push({ submitter: submitters[submitterIndex], index });
      }
    });
    const tonnes = allocateWeightedIntegers(profile.prn.statusTonnes[status], rowKeys, random);
    rowKeys.forEach((row, index) => {
      const code = chooseMaterial();
      prns.push({
        prnNumber: `DG${prnRunKey}${row.submitter.type === 'ComplianceScheme' ? 'C' : 'D'}${status === 'ACCEPTED' ? 'A' : 'W'}${String(index + 1).padStart(5, '0')}`,
        externalId: deterministicUuid(`${runId}:prn:${row.submitter.type}:${status}:${index}`),
        submitterId: row.submitter.submitterId,
        submitterName: row.submitter.name,
        status,
        materialCode: code,
        materialName: materialNames[code],
        tonnes: tonnes[index]
      });
    });
  }
  return prns;
}

export function buildPlan(profile, options) {
  const increase = normaliseIncrease(options.increase ?? 0);
  const scale = 1 + increase / 100;
  const pomYear = Number(options.year);
  if (!Number.isInteger(pomYear) || pomYear < 2025 || pomYear > 2100) {
    throw new Error('The initial generator supports reporting years from 2025 to 2100.');
  }
  const seed = options.seed ?? `${profile.name}:${pomYear}:${increase}`;
  const runId = options.runId ?? `pom${pomYear}-${crypto.createHash('sha1').update(seed).digest('hex').slice(0, 10)}`;
  const random = createRandom(seed);
  let currentReference = Number(options.referenceStart);
  const reference = { next: () => currentReference++ };
  const scaledAssociations = Object.fromEntries(Object.entries(profile.producerAssociations).map(([type, definitions]) => [
    type,
    definitions.map((definition) => ({
      submitterCount: Math.max(1, Math.round(definition.submitterCount * scale)),
      totalProducers: Math.max(1, Math.round(definition.totalProducers * scale))
    }))
  ]));
  const scheme = createAssociations('ComplianceScheme', scaledAssociations.ComplianceScheme, reference, runId, random);
  const direct = createAssociations('DirectRegistrant', scaledAssociations.DirectRegistrant, reference, runId, random);
  const submitters = [...scheme.submitters, ...direct.submitters];

  // The captured baseline has one producer associated with two schemes. Keep that
  // relationship without making its external/reference identifiers ambiguous.
  if (increase === 0 && scheme.associations.length > 1) {
    const sharedProducer = scheme.associations[0];
    const secondAssociation = scheme.associations.find((association) => association.submitter !== sharedProducer.submitter);
    Object.assign(secondAssociation, {
      producerReferenceNumber: sharedProducer.producerReferenceNumber,
      producerExternalId: sharedProducer.producerExternalId,
      producerName: sharedProducer.producerName
    });
  }

  if (options.linkLocalAccounts) {
    Object.assign(scheme.submitters[0], {
      referenceNumber: LINKED_ACCOUNTS.scheme.referenceNumber,
      externalId: LINKED_ACCOUNTS.scheme.accountExternalId,
      submitterId: LINKED_ACCOUNTS.scheme.submitterId,
      name: LINKED_ACCOUNTS.scheme.name,
      linkedAccount: true
    });
    Object.assign(direct.submitters[0], {
      referenceNumber: LINKED_ACCOUNTS.direct.referenceNumber,
      externalId: LINKED_ACCOUNTS.direct.externalId,
      submitterId: LINKED_ACCOUNTS.direct.externalId,
      name: LINKED_ACCOUNTS.direct.name,
      linkedAccount: true
    });
    const directProducer = direct.associations.find((association) => association.submitter === direct.submitters[0]);
    Object.assign(directProducer, {
      producerReferenceNumber: LINKED_ACCOUNTS.direct.referenceNumber,
      producerExternalId: LINKED_ACCOUNTS.direct.externalId,
      producerName: LINKED_ACCOUNTS.direct.name
    });
  }

  const slotSets = [];
  for (const [type, associations] of [['ComplianceScheme', scheme.associations], ['DirectRegistrant', direct.associations]]) {
    const scaledRows = Object.fromEntries(Object.entries(profile.pom.materialRows[type]).map(([material, count]) => [material, Math.max(1, Math.round(count * scale))]));
    const scaledTonnes = Object.fromEntries(Object.entries(profile.pom.annualTonnes[type]).map(([material, tonnes]) => [material, Math.max(1, Math.round(tonnes * scale))]));
    const slots = assignMaterials(associations, scaledRows, random);
    materialiseWeights(slots, scaledTonnes, random);
    slotSets.push(...slots);
  }

  const files = [];
  const pomRows = [];
  for (const submitter of submitters) {
    for (const half of ['H1', 'H2']) {
      const fileName = `data-generator/${runId}/${submitter.type}/${submitter.index}/${pomYear}-${half}.csv`;
      const fileId = deterministicUuid(`${runId}:file:${submitter.key}:${half}`);
      const submissionId = deterministicUuid(`${runId}:submission:${submitter.key}:${half}`);
      files.push({ submitter, half, fileName, fileId, submissionId });
    }
  }
  for (const slot of slotSets) {
    for (const [material, annualWeightKg] of slot.materials.entries()) {
      const h1 = Math.max(1, Math.floor(annualWeightKg * (0.42 + random() * 0.16)));
      const h2 = annualWeightKg - h1;
      for (const [half, weightKg] of [['H1', h1], ['H2', h2]]) {
        const file = files.find((candidate) => candidate.submitter === slot.submitter && candidate.half === half);
        pomRows.push({
          organisationReferenceNumber: slot.submitter.referenceNumber,
          subsidiaryReferenceNumber: slot.producerReferenceNumber === slot.submitter.referenceNumber ? null : slot.producerReferenceNumber,
          organisationSize: 'L',
          submissionPeriod: `${pomYear}-${half}`,
          packagingType: ['HH', 'NH', 'PB', 'HDC', 'NDC'][Math.floor(random() * 5)],
          packagingClass: `P${1 + Math.floor(random() * 4)}`,
          packagingMaterial: material,
          packagingMaterialWeight: weightKg,
          fileName: file.fileName
        });
      }
    }
  }
  const scaledPrnProfile = structuredClone(profile);
  for (const status of Object.keys(scaledPrnProfile.prn.statusCounts)) {
    scaledPrnProfile.prn.statusCounts[status] = Math.round(scaledPrnProfile.prn.statusCounts[status] * scale);
    scaledPrnProfile.prn.statusTonnes[status] = Math.round(scaledPrnProfile.prn.statusTonnes[status] * scale);
    scaledPrnProfile.prn.rankedSubmitterCounts[status] = scaledPrnProfile.prn.rankedSubmitterCounts[status]
      .map((count) => Math.round(count * scale));
  }
  const prns = createPrns(submitters, scaledPrnProfile, runId, random);
  return {
    runId, seed, pomYear, obligationYear: pomYear + 1, increase, linkedAccounts: Boolean(options.linkLocalAccounts),
    submitters, associations: slotSets, files, pomRows, prns,
    expected: {
      producers: new Set(slotSets.map((slot) => slot.producerExternalId)).size,
      submitters: submitters.length,
      materialRows: slotSets.reduce((sum, slot) => sum + slot.materials.size, 0),
      pomRows: pomRows.length,
      files: files.length,
      prns: prns.length,
      prnTonnes: prns.reduce((sum, prn) => sum + prn.tonnes, 0)
    }
  };
}

export { LINKED_ACCOUNTS };
