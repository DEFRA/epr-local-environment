import sql from 'mssql';

function connectionConfig(prefix, environment) {
  return {
    server: environment[`${prefix}_HOST`],
    port: Number(environment[`${prefix}_PORT`] ?? 1433),
    user: environment.SQL_USER,
    password: environment.SQL_PASSWORD,
    database: environment[`${prefix}_DATABASE`],
    options: { encrypt: false, trustServerCertificate: true },
    pool: { max: 4, min: 0, idleTimeoutMillis: 30000 }
  };
}

export async function openDatabases(environment) {
  const synapse = await new sql.ConnectionPool(connectionConfig('SYNAPSE', environment)).connect();
  const prn = await new sql.ConnectionPool(connectionConfig('PRN', environment)).connect();
  return { synapse, prn };
}

export async function closeDatabases(databases) {
  await Promise.all(Object.values(databases).map((pool) => pool?.close()));
}

export async function referenceStart(pool) {
  const result = await pool.request().query(`
    SELECT ISNULL(MAX(TRY_CONVERT(int, ReferenceNumber)), 899999999) + 1 AS ReferenceStart
    FROM rpd.Organisations;
  `);
  return Math.max(900000000, Number(result.recordset[0].ReferenceStart));
}

export async function assertPrerequisites(pool) {
  const result = await pool.request().query(`
    SELECT
      OBJECT_ID(N'rpd.Organisations') AS Organisations,
      OBJECT_ID(N'rpd.Pom') AS Pom,
      OBJECT_ID(N'rpd.cosmos_file_metadata') AS Metadata,
      OBJECT_ID(N'rpd.SubmissionEvents') AS SubmissionEvents,
      OBJECT_ID(N'dbo.sp_GetApprovedSubmissionsMyc') AS ApprovedSubmissionsProcedure;
  `);
  const missing = Object.entries(result.recordset[0]).filter(([, value]) => value === null).map(([name]) => name);
  if (missing.length > 0) throw new Error(`EprCommonData is missing required objects: ${missing.join(', ')}.`);
}

export async function assertRunDoesNotExist(pool, runId) {
  const result = await pool.request()
    .input('prefix', sql.NVarChar(4000), `data-generator/${runId}/%`)
    .query('SELECT COUNT(*) AS ExistingRows FROM rpd.cosmos_file_metadata WHERE FileName LIKE @prefix;');
  if (Number(result.recordset[0].ExistingRows) > 0) {
    throw new Error(`Run '${runId}' already exists in EprCommonData. Choose --run-id or remove that run explicitly before retrying.`);
  }
}

export async function assertLinkedAccountAnchors(environment, synapsePool, pomYear) {
  const accounts = await new sql.ConnectionPool(connectionConfig('ACCOUNTS', environment)).connect();
  try {
    const accountResult = await accounts.request().query(`
      SELECT LOWER(CONVERT(varchar(36), ExternalId)) AS ExternalId
      FROM Organisations
      WHERE LOWER(CONVERT(varchar(36), ExternalId)) IN (
        '0bb650b9-125e-4d64-b1d0-06b9e167b2d4',
        'e2316c5e-d434-41da-8274-494dc0762d20'
      );
    `);
    if (accountResult.recordset.length !== 2) {
      throw new Error('--link-local-accounts requires the seeded Northbridge and Pop Quest account organisations.');
    }
    const existingPom = await synapsePool.request()
      .input('h1', sql.NVarChar(20), `${pomYear}-H1`)
      .input('h2', sql.NVarChar(20), `${pomYear}-H2`)
      .query(`
        SELECT COUNT(*) AS ExistingRows
        FROM rpd.Pom
        WHERE organisation_id IN (110000, 165282)
          AND submission_period IN (@h1, @h2);
      `);
    if (Number(existingPom.recordset[0].ExistingRows) > 0) {
      throw new Error(`--link-local-accounts cannot use ${pomYear}: the seeded Northbridge or Pop Quest account already has POM rows for that year. Choose an unused year to avoid mixing generated and fixture submissions.`);
    }
  } finally {
    await accounts.close();
  }
}

function table(schema, name, columns) {
  const result = new sql.Table(name);
  result.schema = schema;
  result.create = false;
  for (const [columnName, type, nullable = true] of columns) result.columns.add(columnName, type, { nullable });
  return result;
}

async function bulk(pool, transaction, sqlTable) {
  const request = new sql.Request(transaction ?? pool);
  await request.bulk(sqlTable);
}

function uniqueBy(values, key) {
  return [...new Map(values.map((value) => [key(value), value])).values()];
}

export async function insertSynapseData(pool, plan) {
  const transaction = new sql.Transaction(pool);
  await transaction.begin();
  try {
    const now = new Date();
    const nowString = now.toISOString();
    const organisationValues = [];
    for (const submitter of plan.submitters.filter((value) => !value.linkedAccount)) {
      organisationValues.push({
        id: submitter.referenceNumber, type: 1, name: submitter.name, reference: submitter.referenceNumber,
        externalId: submitter.externalId, isScheme: submitter.type === 'ComplianceScheme'
      });
    }
    for (const association of plan.associations) {
      if (association.producerReferenceNumber === association.submitter.referenceNumber) continue;
      organisationValues.push({
        id: association.producerReferenceNumber, type: 1, name: association.producerName,
        reference: association.producerReferenceNumber, externalId: association.producerExternalId, isScheme: false
      });
    }
    const organisations = uniqueBy(organisationValues, (value) => value.reference);
    const organisationTable = table('rpd', 'Organisations', [
      ['Id', sql.Int], ['OrganisationTypeId', sql.Int], ['CompaniesHouseNumber', sql.NVarChar(4000)],
      ['Name', sql.NVarChar(4000)], ['TradingName', sql.NVarChar(4000)], ['ReferenceNumber', sql.NVarChar(4000)],
      ['ValidatedWithCompaniesHouse', sql.Bit], ['IsComplianceScheme', sql.Bit], ['NationId', sql.Int],
      ['ExternalId', sql.NVarChar(4000)], ['CreatedOn', sql.NVarChar(4000)], ['LastUpdatedOn', sql.NVarChar(4000)],
      ['IsDeleted', sql.Bit], ['ProducerTypeId', sql.Int], ['load_ts', sql.DateTime2]
    ]);
    organisations.forEach((value) => organisationTable.rows.add(
      value.id, value.type, `DG${value.reference}`, value.name, '', String(value.reference), true,
      value.isScheme, 1, value.externalId, nowString, nowString, false, 0, now
    ));
    await bulk(pool, transaction, organisationTable);

    const schemeTable = table('rpd', 'ComplianceSchemes', [
      ['Id', sql.Int], ['Name', sql.NVarChar(4000)], ['ExternalId', sql.NVarChar(4000)], ['CreatedOn', sql.NVarChar(4000)],
      ['LastUpdatedOn', sql.NVarChar(4000)], ['IsDeleted', sql.Bit], ['CompaniesHouseNumber', sql.NVarChar(4000)],
      ['NationId', sql.Int], ['load_ts', sql.DateTime2]
    ]);
    plan.submitters.filter((value) => value.type === 'ComplianceScheme' && !value.linkedAccount).forEach((value) => {
      schemeTable.rows.add(value.referenceNumber, value.name, value.submitterId, nowString, nowString, false, `DG${value.referenceNumber}`, 1, now);
    });
    await bulk(pool, transaction, schemeTable);

    const metadataTable = table('rpd', 'cosmos_file_metadata', [
      ['SubmissionId', sql.NVarChar(4000)], ['FileId', sql.NVarChar(4000)], ['UserId', sql.NVarChar(4000)],
      ['BlobName', sql.NVarChar(4000)], ['BlobContainerName', sql.NVarChar(4000)], ['FileType', sql.NVarChar(4000)],
      ['Created', sql.NVarChar(4000)], ['OriginalFileName', sql.NVarChar(4000)], ['OrganisationId', sql.NVarChar(4000)],
      ['DataSourceType', sql.NVarChar(4000)], ['SubmissionPeriod', sql.NVarChar(4000)], ['IsSubmitted', sql.Bit],
      ['SubmissionType', sql.NVarChar(4000)], ['ComplianceSchemeId', sql.NVarChar(4000)], ['FileName', sql.NVarChar(4000)], ['load_ts', sql.DateTime2]
    ]);
    plan.files.forEach((file) => metadataTable.rows.add(
      file.submissionId, file.fileId, deterministicUserId(plan.runId), file.fileId, 'epr-antivirus-pom', 'Pom', nowString,
      file.fileName.split('/').at(-1), file.submitter.externalId, 'File', file.half === 'H1' ? `January to June ${plan.pomYear}` : `July to December ${plan.pomYear}`,
      true, 'Producer', file.submitter.type === 'ComplianceScheme' ? file.submitter.submitterId : null, file.fileName, now
    ));
    await bulk(pool, transaction, metadataTable);

    const eventTable = table('rpd', 'SubmissionEvents', [
      ['Created', sql.NVarChar(4000)], ['SubmissionEventId', sql.NVarChar(4000)], ['SubmissionId', sql.NVarChar(4000)],
      ['Decision', sql.NVarChar(4000)], ['FileId', sql.NVarChar(4000)], ['id', sql.NVarChar(4000)],
      ['Type', sql.NVarChar(4000)], ['load_ts', sql.DateTime2]
    ]);
    plan.files.forEach((file) => {
      const eventId = deterministicUuid(`${plan.runId}:accepted:${file.fileId}`);
      eventTable.rows.add(nowString, eventId, file.submissionId, 'Accepted', file.fileId, `RegulatorPoMDecision|${eventId}`, 'RegulatorPoMDecision', now);
    });
    await bulk(pool, transaction, eventTable);

    const pomTable = table('rpd', 'Pom', [
      ['organisation_id', sql.Int], ['subsidiary_id', sql.NVarChar(4000)], ['organisation_size', sql.NVarChar(4000)],
      ['submission_period', sql.NVarChar(4000)], ['packaging_activity', sql.NVarChar(4000)], ['packaging_type', sql.NVarChar(4000)],
      ['packaging_class', sql.NVarChar(4000)], ['packaging_material', sql.NVarChar(4000)], ['packaging_material_subtype', sql.NVarChar(4000)],
      ['from_country', sql.NVarChar(4000)], ['to_country', sql.NVarChar(4000)], ['packaging_material_weight', sql.Float],
      ['packaging_material_units', sql.Float], ['transitional_packaging_units', sql.Float], ['ram_rag_rating', sql.NVarChar(4000)],
      ['load_ts', sql.DateTime2, false], ['FileName', sql.NVarChar(4000)]
    ]);
    plan.pomRows.forEach((row) => pomTable.rows.add(
      row.organisationReferenceNumber, row.subsidiaryReferenceNumber === null ? null : String(row.subsidiaryReferenceNumber),
      row.organisationSize, row.submissionPeriod, 'SO', row.packagingType, row.packagingClass, row.packagingMaterial,
      null, null, null, row.packagingMaterialWeight, null, null, 'G', now, row.fileName
    ));
    await bulk(pool, transaction, pomTable);
    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

function deterministicUserId(runId) {
  return `00000000-0000-0000-0000-${runId.replace(/[^a-f0-9]/gi, '').padEnd(12, '0').slice(0, 12)}`;
}

export async function insertPrns(pool, plan) {
  const statuses = await pool.request().query(`SELECT Id, StatusName FROM PrnStatus WHERE StatusName IN ('ACCEPTED', 'AWAITINGACCEPTANCE');`);
  const statusIds = new Map(statuses.recordset.map((row) => [row.StatusName, row.Id]));
  if (statusIds.size !== 2) throw new Error('EprPrnBackend is missing ACCEPTED or AWAITINGACCEPTANCE PRN status lookup data.');
  const transaction = new sql.Transaction(pool);
  await transaction.begin();
  try {
    const now = new Date();
    const prnTable = table('dbo', 'Prn', [
      ['PrnNumber', sql.NVarChar(100)], ['OrganisationId', sql.UniqueIdentifier], ['OrganisationName', sql.NVarChar(500)],
      ['ProducerAgency', sql.NVarChar(500)], ['ReprocessorExporterAgency', sql.NVarChar(500)], ['PrnStatusId', sql.Int],
      ['TonnageValue', sql.Int], ['MaterialName', sql.NVarChar(200)], ['IssuerReference', sql.NVarChar(200)],
      ['IssueDate', sql.DateTime2], ['DecemberWaste', sql.Bit], ['IssuedByOrg', sql.NVarChar(500)],
      ['AccreditationNumber', sql.NVarChar(200)], ['AccreditationYear', sql.NVarChar(10)], ['ObligationYear', sql.NVarChar(10)],
      ['PackagingProducer', sql.NVarChar(500)], ['CreatedOn', sql.DateTime2], ['LastUpdatedBy', sql.UniqueIdentifier],
      ['ExternalId', sql.UniqueIdentifier], ['IsExport', sql.Bit], ['LastUpdatedDate', sql.DateTime2], ['SourceSystemId', sql.NVarChar(100)]
    ]);
    plan.prns.forEach((prn, index) => prnTable.rows.add(
      prn.prnNumber, prn.submitterId, prn.submitterName, 'Synthetic producer agency', 'Synthetic reprocessor', statusIds.get(prn.status),
      prn.tonnes, prn.materialName, `DG-${plan.runId}`, new Date(Date.UTC(plan.obligationYear, index % 12, 1 + (index % 27))), false,
      'Synthetic issuing organisation', `DG-${plan.obligationYear}`, String(plan.obligationYear), String(plan.obligationYear),
      prn.submitterName, now, '00000000-0000-0000-0000-000000000000', prn.externalId, false, now, 'data-generator'
    ));
    await bulk(pool, transaction, prnTable);
    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

/**
 * Removes only the material obligations data for one requested POM/calculation
 * year. Account organisations, lookup data, recycling targets and data for all
 * other years are deliberately retained. The two database operations cannot be
 * atomic together, so this must be an explicit CLI option.
 */
export async function removeExistingYear(synapse, prn, pomYear) {
  const obligationYear = pomYear + 1;
  const synapseResult = await synapse.request()
    .input('h1', sql.NVarChar(20), `${pomYear}-H1`)
    .input('h2', sql.NVarChar(20), `${pomYear}-H2`)
    .input('obligationYear', sql.Int, obligationYear)
    .query(`
      SET XACT_ABORT ON;
      BEGIN TRANSACTION;

      CREATE TABLE #PomFiles (FileId nvarchar(4000) NULL, SubmissionId nvarchar(4000) NULL, FileName nvarchar(4000) NULL);
      INSERT INTO #PomFiles (FileId, SubmissionId, FileName)
      SELECT DISTINCT metadata.FileId, metadata.SubmissionId, metadata.FileName
      FROM rpd.cosmos_file_metadata metadata
      INNER JOIN rpd.Pom pom ON pom.FileName = metadata.FileName
      WHERE pom.submission_period IN (@h1, @h2);

      DECLARE @PomRows int = (SELECT COUNT(*) FROM rpd.Pom WHERE submission_period IN (@h1, @h2));
      DECLARE @MetadataRows int = (SELECT COUNT(*) FROM #PomFiles);
      DECLARE @EventRows int = (
        SELECT COUNT(*) FROM rpd.SubmissionEvents eventRow
        INNER JOIN #PomFiles fileRow ON fileRow.FileId = eventRow.FileId
      );
      DECLARE @SubmissionRows int = (
        SELECT COUNT(*) FROM rpd.Submissions submission
        INNER JOIN #PomFiles fileRow ON fileRow.FileId = submission.FileId
      );
      DECLARE @DeterminationRows int = (
        SELECT COUNT(*) FROM dbo.t_producer_obligation_determination
        WHERE submission_period_year = @obligationYear
      );

      DELETE eventRow
      FROM rpd.SubmissionEvents eventRow
      INNER JOIN #PomFiles fileRow ON fileRow.FileId = eventRow.FileId;

      DELETE submission
      FROM rpd.Submissions submission
      INNER JOIN #PomFiles fileRow ON fileRow.FileId = submission.FileId;

      DELETE metadata
      FROM rpd.cosmos_file_metadata metadata
      INNER JOIN #PomFiles fileRow ON fileRow.FileName = metadata.FileName;

      DELETE FROM rpd.Pom WHERE submission_period IN (@h1, @h2);
      DELETE FROM dbo.t_producer_obligation_determination WHERE submission_period_year = @obligationYear;

      COMMIT TRANSACTION;
      SELECT @PomRows AS PomRows, @MetadataRows AS MetadataRows, @EventRows AS EventRows,
             @SubmissionRows AS SubmissionRows, @DeterminationRows AS DeterminationRows;
    `);
  const prnResult = await prn.request()
    .input('obligationYear', sql.NVarChar(10), String(obligationYear))
    .input('calculationYear', sql.Int, obligationYear)
    .query(`
      SET XACT_ABORT ON;
      BEGIN TRANSACTION;

      DECLARE @PrnRows int = (SELECT COUNT(*) FROM Prn WHERE ObligationYear = @obligationYear);
      DECLARE @PrnHistoryRows int = (
        SELECT COUNT(*) FROM PrnStatusHistory history
        INNER JOIN Prn prn ON prn.Id = history.PrnIdFk
        WHERE prn.ObligationYear = @obligationYear
      );
      DECLARE @CalculationRows int = (SELECT COUNT(*) FROM ObligationCalculations WHERE Year = @calculationYear);

      DELETE history
      FROM PrnStatusHistory history
      INNER JOIN Prn prn ON prn.Id = history.PrnIdFk
      WHERE prn.ObligationYear = @obligationYear;

      DELETE FROM Prn WHERE ObligationYear = @obligationYear;
      DELETE FROM ObligationCalculations WHERE Year = @calculationYear;

      COMMIT TRANSACTION;
      SELECT @PrnRows AS PrnRows, @PrnHistoryRows AS PrnHistoryRows, @CalculationRows AS CalculationRows;
    `);
  return { synapse: synapseResult.recordset[0], prn: prnResult.recordset[0] };
}

export async function approvedSubmissions(pool, pomYear) {
  const result = await pool.request()
    .input('PeriodYear', sql.VarChar(4), String(pomYear))
    .input('IncludePackagingTypes', sql.VarChar(sql.MAX), 'HH,NH,PB,HDC,NDC')
    .input('IncludePackagingMaterials', sql.VarChar(sql.MAX), 'AL,FC,GL,PC,PL,ST,WD')
    .execute('dbo.sp_GetApprovedSubmissionsMyc');
  return result.recordset;
}

export async function validateDatabaseShape(synapse, prn, manifest) {
  const prefix = `data-generator/${manifest.runId}/%`;
  const [synapseRows, prnRows, calculations] = await Promise.all([
    synapse.request().input('prefix', sql.NVarChar(4000), prefix).query(`
      SELECT
        (SELECT COUNT(*) FROM rpd.Pom WHERE FileName LIKE @prefix) AS PomRows,
        (SELECT COUNT(*) FROM rpd.cosmos_file_metadata WHERE FileName LIKE @prefix) AS MetadataRows,
        (SELECT COUNT(*) FROM rpd.SubmissionEvents eventRow INNER JOIN rpd.cosmos_file_metadata metadata ON metadata.FileId = eventRow.FileId WHERE metadata.FileName LIKE @prefix AND eventRow.Type = 'RegulatorPoMDecision' AND eventRow.Decision = 'Accepted') AS AcceptedDecisionRows;
    `),
    prn.request().input('prefix', sql.NVarChar(100), `DG-${manifest.runId}-%`).query(`
      SELECT COUNT(*) AS PrnRows, ISNULL(SUM(TonnageValue), 0) AS PrnTonnes FROM Prn WHERE PrnNumber LIKE @prefix;
    `),
    prn.request().input('year', sql.Int, manifest.obligationYear).query(`
      SELECT LOWER(CONVERT(varchar(36), SubmitterId)) AS SubmitterId, COUNT(*) AS CalculationRows
      FROM ObligationCalculations
      WHERE Year = @year AND IsDeleted = 0
      GROUP BY SubmitterId;
    `)
  ]);
  const submitterIds = new Set(manifest.submitters.map((submitter) => submitter.submitterId.toLowerCase()));
  const calculationRows = calculations.recordset
    .filter((row) => submitterIds.has(row.SubmitterId.toLowerCase()))
    .reduce((sum, row) => sum + Number(row.CalculationRows), 0);
  return { ...synapseRows.recordset[0], ...prnRows.recordset[0], CalculationRows: calculationRows };
}
