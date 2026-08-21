using System.Data;
using System.Globalization;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("EprCommonData")
    ?? throw new InvalidOperationException("ConnectionStrings:EprCommonData must be configured.");

var app = builder.Build();

app.MapGet("/health", () => Results.Ok());

app.MapGet("/recycling-data", async (
    int year,
    Guid submitterId,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    long page = 1,
    long pageSize = 100,
    bool useLocalSqlOptimisation = true) =>
{
    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    if (page < 1 || pageSize < 1)
    {
        return Results.BadRequest(new { error = "page and pageSize must both be positive integers." });
    }

    long offset;
    try
    {
        offset = checked((page - 1) * pageSize);
    }
    catch (OverflowException)
    {
        return Results.BadRequest(new { error = "page and pageSize produce an unsupported offset." });
    }

    try
    {
        var rows = new List<RecyclingDataRow>();

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var query = useLocalSqlOptimisation
            ? RecyclingDataSql.LocalOptimisedQuery
            : RecyclingDataSql.BaselineQuery;

        await using var command = new SqlCommand(query, connection)
        {
            CommandTimeout = 320
        };

        command.Parameters.Add("@PeriodYear", SqlDbType.VarChar, 4).Value = year.ToString(CultureInfo.InvariantCulture);
        command.Parameters.Add("@SubmitterId", SqlDbType.UniqueIdentifier).Value = submitterId;
        command.Parameters.Add("@IncludePackagingTypes", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingTypes;
        command.Parameters.Add("@IncludePackagingMaterials", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingMaterials;
        command.Parameters.Add("@Offset", SqlDbType.BigInt).Value = offset;
        command.Parameters.Add("@PageSize", SqlDbType.BigInt).Value = pageSize;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SequentialAccess, cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new DataException("The recycling data query did not return a total count.");
        }

        var totalItems = reader.GetInt64(reader.GetOrdinal("TotalItems"));
        if (!await reader.NextResultAsync(cancellationToken))
        {
            throw new DataException("The recycling data query did not return page data.");
        }

        var submissionPeriodOrdinal = reader.GetOrdinal("SubmissionPeriod");
        var submitterTypeOrdinal = reader.GetOrdinal("SubmitterType");
        var submitterIdOrdinal = reader.GetOrdinal("SubmitterId");
        var organisationIdOrdinal = reader.GetOrdinal("OrganisationId");
        var packagingMaterialOrdinal = reader.GetOrdinal("PackagingMaterial");
        var packagingMaterialWeightOrdinal = reader.GetOrdinal("PackagingMaterialWeight");
        var numberOfDaysObligatedOrdinal = reader.GetOrdinal("NumberOfDaysObligated");

        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new RecyclingDataRow(
                reader.GetString(submissionPeriodOrdinal),
                reader.GetString(submitterTypeOrdinal),
                reader.GetGuid(submitterIdOrdinal),
                reader.GetGuid(organisationIdOrdinal),
                reader.GetString(packagingMaterialOrdinal),
                reader.GetInt32(packagingMaterialWeightOrdinal),
                reader.IsDBNull(numberOfDaysObligatedOrdinal)
                    ? null
                    : Convert.ToInt32(reader.GetValue(numberOfDaysObligatedOrdinal), CultureInfo.InvariantCulture)));
        }

        return Results.Ok(new RecyclingDataPage(rows, page, pageSize, totalItems, useLocalSqlOptimisation));
    }
    catch (SqlException exception)
    {
        logger.LogError(exception, "Unable to retrieve recycling data for year {Year} and submitter {SubmitterId}", year, submitterId);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to retrieve recycling data.");
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Unexpected error retrieving recycling data for year {Year} and submitter {SubmitterId}", year, submitterId);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to retrieve recycling data.");
    }
});

app.MapGet("/admin/submitters", async (
    int year,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    int take = 10,
    string? submitterType = null) =>
{
    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    if (take < 1)
    {
        return Results.BadRequest(new { error = "take must be a positive integer." });
    }

    if (submitterType is not null
        && !string.Equals(submitterType, "ComplianceScheme", StringComparison.Ordinal)
        && !string.Equals(submitterType, "DirectRegistrant", StringComparison.Ordinal))
    {
        return Results.BadRequest(new { error = "submitterType must be ComplianceScheme or DirectRegistrant when supplied." });
    }

    try
    {
        var items = new List<RecyclingSubmitterSummary>();

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(RecyclingDataSql.SubmitterDiscoveryQuery, connection)
        {
            CommandTimeout = 320
        };
        command.Parameters.Add("@PeriodYear", SqlDbType.VarChar, 4).Value = year.ToString(CultureInfo.InvariantCulture);
        command.Parameters.Add("@Take", SqlDbType.Int).Value = take;
        command.Parameters.Add("@SubmitterType", SqlDbType.VarChar, 32).Value = submitterType ?? (object)DBNull.Value;
        command.Parameters.Add("@IncludePackagingTypes", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingTypes;
        command.Parameters.Add("@IncludePackagingMaterials", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingMaterials;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SequentialAccess, cancellationToken);
        var submitterIdOrdinal = reader.GetOrdinal("SubmitterId");
        var submitterTypeOrdinal = reader.GetOrdinal("SubmitterType");
        var generatedPomRowCountOrdinal = reader.GetOrdinal("GeneratedPomRowCount");
        var producerCountOrdinal = reader.GetOrdinal("ProducerCount");
        var packagingMaterialCountOrdinal = reader.GetOrdinal("PackagingMaterialCount");

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new RecyclingSubmitterSummary(
                reader.GetGuid(submitterIdOrdinal),
                reader.GetString(submitterTypeOrdinal),
                reader.GetInt64(generatedPomRowCountOrdinal),
                reader.GetInt64(producerCountOrdinal),
                reader.GetInt64(packagingMaterialCountOrdinal)));
        }

        return Results.Ok(new RecyclingSubmitterSummaryPage(year, take, submitterType, items));
    }
    catch (SqlException exception)
    {
        logger.LogError(exception, "Unable to discover recycling submitters for year {Year}", year);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to discover recycling submitters.");
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Unexpected error discovering recycling submitters for year {Year}", year);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to discover recycling submitters.");
    }
});

app.Run();

public sealed record RecyclingDataRow(
    string SubmissionPeriod,
    string SubmitterType,
    Guid SubmitterId,
    Guid OrganisationId,
    string PackagingMaterial,
    int PackagingMaterialWeight,
    int? NumberOfDaysObligated);

public sealed record RecyclingDataPage(
    IReadOnlyList<RecyclingDataRow> Items,
    long Page,
    long PageSize,
    long TotalItems,
    bool UseLocalSqlOptimisation);

public sealed record RecyclingSubmitterSummary(
    Guid SubmitterId,
    string SubmitterType,
    long GeneratedPomRowCount,
    long ProducerCount,
    long PackagingMaterialCount);

public sealed record RecyclingSubmitterSummaryPage(
    int Year,
    int Take,
    string? SubmitterType,
    IReadOnlyList<RecyclingSubmitterSummary> Items);

internal static class RecyclingDataSql
{
    // These lists are deliberately part of the service contract, not request parameters.
    internal const string IncludedPackagingTypes = "HH,NH,PB,HDC,NDC";
    internal const string IncludedPackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";

    // Derived from dbo.sp_GetApprovedSubmissionsMyc. It is application SQL so this service has no
    // runtime dependency on that stored procedure. dbo.udf_DQ_SubmissionPeriod remains an upstream
    // data-quality helper function and is restored with the Common Data database.
    //
    // This is a separate command text rather than a SQL mode parameter. Therefore it has its own
    // execution plan and can be compared directly with BaselineQuery.
    internal const string LocalOptimisedQuery = """
        SET NOCOUNT ON;

        DECLARE @RelevantYear varchar(4) = CAST(CAST(@PeriodYear AS int) + 1 AS varchar(4));

        WITH
        P1P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P1') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        P2P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P2') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        P3P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P3') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        H1H2Table AS (
            SELECT CONCAT(@PeriodYear, '-H1') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-H2') AS period
        ),
        AllPeriodsTable AS (
            SELECT * FROM P1P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM P2P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM P3P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM H1H2Table WHERE @PeriodYear > '2024'
        ),
        TargetFileMetadata AS (
            -- LOCAL SQL SERVER OPTIMISATION: split the copied COALESCE submitter
            -- condition into its scheme and direct-registrant cases. This lets the
            -- local metadata submitter index identify a scheme's files before POM
            -- rows are joined. UNION ALL preserves the original row cardinality.
            SELECT
                cfm.LocalFileName,
                cfm.FileName,
                cfm.LocalFileId,
                cfm.FileId,
                cfm.LocalComplianceSchemeId,
                cfm.ComplianceSchemeId,
                cfm.SubmissionPeriod
            FROM rpd.cosmos_file_metadata AS cfm
            WHERE cfm.LocalComplianceSchemeId = CAST(@SubmitterId AS nvarchar(255))
                AND cfm.ComplianceSchemeId = CAST(@SubmitterId AS varchar(36))

            UNION ALL

            SELECT
                cfm.LocalFileName,
                cfm.FileName,
                cfm.LocalFileId,
                cfm.FileId,
                cfm.LocalComplianceSchemeId,
                cfm.ComplianceSchemeId,
                cfm.SubmissionPeriod
            FROM rpd.cosmos_file_metadata AS cfm
            -- Direct registrations have no submitter field in file metadata.
            -- Their original organisation-based predicate remains below.
            WHERE cfm.LocalComplianceSchemeId IS NULL
                AND cfm.ComplianceSchemeId IS NULL
        ),
        LatestAcceptedPomFiles AS (
            -- LOCAL SQL SERVER OPTIMISATION BEGIN
            -- The Local* values are bounded persisted projections installed only in the
            -- local SQL Server replica. The original stored-procedure predicates remain
            -- alongside them to preserve full-value semantics.
            SELECT FileId, SourceFileId, SubmissionId, SourceCreated AS Created
            FROM (
                SELECT
                    LocalFileId AS FileId,
                    FileId AS SourceFileId,
                    LocalSubmissionId AS SubmissionId,
                    Created AS SourceCreated,
                    ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY LocalCreated DESC, Created DESC) AS rn
                FROM rpd.SubmissionEvents
                WHERE LocalType = 'RegulatorPoMDecision'
                    AND LocalDecision = 'Accepted'
                    AND LocalFileId IS NOT NULL
                    -- Original stored-procedure predicates retained for correctness.
                    AND Type = 'RegulatorPoMDecision'
                    AND Decision = 'Accepted'
                    AND FileId IS NOT NULL
            ) accepted
            WHERE rn = 1
        ),
        LatestAcceptedPoms AS (
            SELECT *
            FROM (
                SELECT DISTINCT
                    latest.SubmissionId,
                    latest.FileId,
                    cfm.LocalFileName,
                    cfm.FileName,
                    cfm.SubmissionPeriod AS submission_period_desc,
                    latest.Created,
                    ROW_NUMBER() OVER (
                        PARTITION BY
                            pom.organisation_id,
                            NULLIF(TRIM(pom.subsidiary_id), ''),
                            pom.submission_period,
                            COALESCE(cfm.ComplianceSchemeId, organisation.ExternalId)
                        ORDER BY latest.Created DESC
                    ) AS rn,
                    pom.organisation_id,
                    NULLIF(TRIM(pom.LocalSubsidiaryId), '') AS local_subsidiary_id,
                    NULLIF(TRIM(pom.subsidiary_id), '') AS subsidiary_id,
                    pom.submission_period,
                    RIGHT(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod), 4) AS submission_period_year,
                    COALESCE(cfm.LocalComplianceSchemeId, organisation.LocalExternalId) AS local_submitter_id,
                    COALESCE(cfm.ComplianceSchemeId, organisation.ExternalId) AS submitter_id,
                    COALESCE(NULLIF(TRIM(pom.subsidiary_id), ''), CAST(pom.organisation_id AS nvarchar(50))) AS producer_id,
                    CASE
                        WHEN NULLIF(TRIM(cfm.ComplianceSchemeId), '') IS NULL THEN 'DirectRegistrant'
                        ELSE 'ComplianceScheme'
                    END AS submitter_type
                FROM rpd.Pom AS pom
                INNER JOIN rpd.Organisations AS organisation
                    -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access key.
                    ON organisation.LocalReferenceNumber = CONVERT(nvarchar(255), pom.organisation_id)
                    -- Original stored-procedure join retained for full-value semantics.
                    AND organisation.ReferenceNumber = pom.organisation_id
                    AND organisation.IsDeleted = 0
                INNER JOIN TargetFileMetadata AS cfm
                    -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access key.
                    ON cfm.LocalFileName = pom.LocalFileName
                    -- Original stored-procedure join retained for full-value semantics.
                    AND cfm.FileName = pom.FileName
                INNER JOIN LatestAcceptedPomFiles AS latest
                    -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access key.
                    ON latest.FileId = cfm.LocalFileId
                    -- Original stored-procedure join retained for full-value semantics.
                    AND latest.SourceFileId = cfm.FileId
                WHERE pom.LocalSubmissionPeriod IN (SELECT period FROM AllPeriodsTable)
                    AND pom.LocalOrganisationSize = 'L'
                    -- Original stored-procedure predicates retained for full-value semantics.
                    AND pom.submission_period IN (SELECT period FROM AllPeriodsTable)
                    AND pom.organisation_size = 'L'
                    -- LOCAL SQL SERVER OPTIMISATION: this early submitter predicate is intentionally
                    -- added to the SQL copied from dbo.sp_GetApprovedSubmissionsMyc. It limits the
                    -- local API query before the later period-pairing and aggregation work.
                    AND COALESCE(cfm.LocalComplianceSchemeId, organisation.LocalExternalId) = CAST(@SubmitterId AS nvarchar(255))
                    AND COALESCE(cfm.ComplianceSchemeId, organisation.ExternalId) = CAST(@SubmitterId AS varchar(36))
            ) accepted
            WHERE rn = 1
        ),
        OrgsWithBothP1P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P1P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P1P4Table)
        ),
        OrgsWithBothP2P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P2P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P2P4Table)
        ),
        OrgsWithBothP3P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P3P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P3P4Table)
        ),
        OrgsWithBothH1H2 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM H1H2Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM H1H2Table)
        ),
        OrgsWith2Periods AS (
            SELECT producer_id, submitter_id FROM OrgsWithBothP1P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothP2P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothP3P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothH1H2 WHERE @PeriodYear > '2024'
        ),
        LatestAcceptedPomsWith2Periods AS (
            SELECT pom.*
            FROM LatestAcceptedPoms AS pom
            INNER JOIN OrgsWith2Periods AS periods
                ON pom.producer_id = periods.producer_id
                AND pom.submitter_id = periods.submitter_id
        )
        SELECT * INTO #LatestAcceptedPomsWith2Periods
        FROM LatestAcceptedPomsWith2Periods;

        WITH
        IncludePackagingMaterialsTable AS (
            SELECT value AS PackagingMaterial FROM STRING_SPLIT(@IncludePackagingMaterials, ',')
        ),
        IncludePackagingTypesTable AS (
            SELECT value AS PackagingType FROM STRING_SPLIT(@IncludePackagingTypes, ',')
        ),
        RegistrationsWithObligations AS (
            SELECT
                organisation_id,
                subsidiary_id,
                LocalSubsidiaryId,
                submitter_id,
                LocalSubmitterId,
                obligation_status,
                num_days_obligated
            FROM dbo.t_producer_obligation_determination
            WHERE submission_period_year = @RelevantYear
        ),
        LatestAcceptedPomEntries AS (
            SELECT
                lap.organisation_id,
                lap.LocalFileName,
                lap.subsidiary_id,
                lap.local_subsidiary_id,
                lap.submitter_id,
                lap.local_submitter_id,
                lap.producer_id,
                producerOrganisation.ExternalId AS external_producer_id,
                lap.submitter_type,
                lap.submission_period,
                lap.submission_period_year,
                pom.packaging_type,
                pom.packaging_material,
                CASE
                    WHEN pom.submission_period = '2023-P2' THEN CAST(pom.packaging_material_weight * 1.50 AS decimal(16, 2))
                    WHEN pom.submission_period = '2024-P2' THEN CAST(pom.packaging_material_weight * 2 AS decimal(16, 2))
                    WHEN pom.submission_period = '2024-P3' THEN CAST(pom.packaging_material_weight * 182.0 / 61 AS decimal(16, 2))
                    ELSE pom.packaging_material_weight
                END AS packaging_material_weight,
                pom.transitional_packaging_units
            FROM #LatestAcceptedPomsWith2Periods AS lap
            INNER JOIN rpd.Organisations AS producerOrganisation
                -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access key.
                ON producerOrganisation.LocalReferenceNumber = lap.producer_id
                -- Original stored-procedure join retained for full-value semantics.
                AND producerOrganisation.ReferenceNumber = lap.producer_id
            INNER JOIN rpd.Pom AS pom
                -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access keys.
                ON pom.LocalFileName = lap.LocalFileName
                AND COALESCE(NULLIF(TRIM(pom.LocalSubsidiaryId), ''), '') = COALESCE(lap.local_subsidiary_id, '')
                -- Original stored-procedure joins retained for full-value semantics.
                AND pom.FileName = lap.FileName
                AND COALESCE(NULLIF(TRIM(pom.subsidiary_id), ''), '') = COALESCE(lap.subsidiary_id, '')
                AND pom.organisation_id = lap.organisation_id
        )
        SELECT
            pom.submission_period_year AS SubmissionPeriod,
            pom.submitter_type AS SubmitterType,
            CAST(pom.submitter_id AS uniqueidentifier) AS SubmitterId,
            CAST(pom.external_producer_id AS uniqueidentifier) AS OrganisationId,
            pom.packaging_material AS PackagingMaterial,
            CAST(ROUND((SUM(pom.packaging_material_weight) - COALESCE(SUM(pom.transitional_packaging_units), 0)) / 1000.0, 0) AS int) AS PackagingMaterialWeight,
            obligations.num_days_obligated AS NumberOfDaysObligated
        INTO #ApprovedRecyclingData
        FROM LatestAcceptedPomEntries AS pom
        INNER JOIN #LatestAcceptedPomsWith2Periods AS accepted
            ON accepted.submission_period = pom.submission_period
            AND accepted.organisation_id = pom.organisation_id
            AND COALESCE(accepted.subsidiary_id, '') = COALESCE(pom.subsidiary_id, '')
            AND accepted.submitter_id = pom.submitter_id
        LEFT JOIN RegistrationsWithObligations AS obligations
            ON pom.organisation_id = obligations.organisation_id
            -- LOCAL SQL SERVER OPTIMISATION: indexed bounded access keys.
            AND COALESCE(pom.local_subsidiary_id, '') = COALESCE(obligations.LocalSubsidiaryId, '')
            AND pom.local_submitter_id = obligations.LocalSubmitterId
            -- Original stored-procedure joins retained for full-value semantics.
            AND COALESCE(pom.subsidiary_id, '') = COALESCE(obligations.subsidiary_id, '')
            AND pom.submitter_id = obligations.submitter_id
            AND obligations.obligation_status = 'O'
        WHERE pom.local_submitter_id = CAST(@SubmitterId AS nvarchar(255))
            AND pom.submitter_id = CAST(@SubmitterId AS varchar(36))
            AND pom.packaging_material IN (SELECT PackagingMaterial FROM IncludePackagingMaterialsTable)
            AND pom.packaging_type IN (SELECT PackagingType FROM IncludePackagingTypesTable)
        GROUP BY
            pom.submission_period_year,
            pom.submitter_id,
            pom.submitter_type,
            pom.external_producer_id,
            pom.packaging_material,
            obligations.num_days_obligated;

        SELECT COUNT_BIG(*) AS TotalItems
        FROM #ApprovedRecyclingData;

        SELECT
            SubmissionPeriod,
            SubmitterType,
            SubmitterId,
            OrganisationId,
            PackagingMaterial,
            PackagingMaterialWeight,
            NumberOfDaysObligated
        FROM #ApprovedRecyclingData
        ORDER BY OrganisationId, PackagingMaterial, NumberOfDaysObligated
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
        -- LOCAL SQL SERVER OPTIMISATION END
        """;

    // The unoptimised, application-owned equivalent of the stored-procedure query. It deliberately
    // does not reference Local* columns or indexes, so it remains an independent comparison path.
    // The final submitter predicate is part of this API's contract and is present in both paths.
    internal const string BaselineQuery = """
        SET NOCOUNT ON;

        DECLARE @RelevantYear varchar(4) = CAST(CAST(@PeriodYear AS int) + 1 AS varchar(4));

        WITH
        P1P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P1') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        P2P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P2') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        P3P4Table AS (
            SELECT CONCAT(@PeriodYear, '-P3') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-P4') AS period
        ),
        H1H2Table AS (
            SELECT CONCAT(@PeriodYear, '-H1') AS period
            UNION
            SELECT CONCAT(@PeriodYear, '-H2') AS period
        ),
        AllPeriodsTable AS (
            SELECT * FROM P1P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM P2P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM P3P4Table WHERE @PeriodYear = '2024'
            UNION
            SELECT * FROM H1H2Table WHERE @PeriodYear > '2024'
        ),
        LatestAcceptedPomFiles AS (
            SELECT FileId, SubmissionId, Created
            FROM (
                SELECT FileId, SubmissionId, Created,
                    ROW_NUMBER() OVER (PARTITION BY SubmissionId ORDER BY Created DESC) AS rn
                FROM rpd.SubmissionEvents
                WHERE Type = 'RegulatorPoMDecision'
                    AND Decision = 'Accepted'
                    AND FileId IS NOT NULL
            ) accepted
            WHERE rn = 1
        ),
        LatestAcceptedPoms AS (
            SELECT *
            FROM (
                SELECT DISTINCT
                    latest.SubmissionId,
                    latest.FileId,
                    cfm.FileName,
                    cfm.SubmissionPeriod AS submission_period_desc,
                    latest.Created,
                    ROW_NUMBER() OVER (
                        PARTITION BY
                            pom.organisation_id,
                            NULLIF(TRIM(pom.subsidiary_id), ''),
                            pom.submission_period,
                            COALESCE(cfm.ComplianceSchemeId, organisation.ExternalId)
                        ORDER BY latest.Created DESC
                    ) AS rn,
                    pom.organisation_id,
                    NULLIF(TRIM(pom.subsidiary_id), '') AS subsidiary_id,
                    pom.submission_period,
                    RIGHT(dbo.udf_DQ_SubmissionPeriod(cfm.SubmissionPeriod), 4) AS submission_period_year,
                    COALESCE(cfm.ComplianceSchemeId, organisation.ExternalId) AS submitter_id,
                    COALESCE(NULLIF(TRIM(pom.subsidiary_id), ''), CAST(pom.organisation_id AS nvarchar(50))) AS producer_id,
                    CASE
                        WHEN NULLIF(TRIM(cfm.ComplianceSchemeId), '') IS NULL THEN 'DirectRegistrant'
                        ELSE 'ComplianceScheme'
                    END AS submitter_type
                FROM rpd.Pom AS pom
                INNER JOIN rpd.Organisations AS organisation
                    ON organisation.ReferenceNumber = pom.organisation_id
                    AND organisation.IsDeleted = 0
                INNER JOIN rpd.cosmos_file_metadata AS cfm
                    ON cfm.FileName = pom.FileName
                INNER JOIN LatestAcceptedPomFiles AS latest
                    ON latest.FileId = cfm.FileId
                WHERE pom.submission_period IN (SELECT period FROM AllPeriodsTable)
                    AND pom.organisation_size = 'L'
            ) accepted
            WHERE rn = 1
        ),
        OrgsWithBothP1P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P1P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P1P4Table)
        ),
        OrgsWithBothP2P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P2P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P2P4Table)
        ),
        OrgsWithBothP3P4 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM P3P4Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM P3P4Table)
        ),
        OrgsWithBothH1H2 AS (
            SELECT producer_id, submitter_id
            FROM LatestAcceptedPoms
            WHERE submission_period IN (SELECT period FROM H1H2Table)
            GROUP BY producer_id, submitter_id
            HAVING COUNT(DISTINCT submission_period) = (SELECT COUNT(*) FROM H1H2Table)
        ),
        OrgsWith2Periods AS (
            SELECT producer_id, submitter_id FROM OrgsWithBothP1P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothP2P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothP3P4 WHERE @PeriodYear = '2024'
            UNION
            SELECT producer_id, submitter_id FROM OrgsWithBothH1H2 WHERE @PeriodYear > '2024'
        ),
        LatestAcceptedPomsWith2Periods AS (
            SELECT pom.*
            FROM LatestAcceptedPoms AS pom
            INNER JOIN OrgsWith2Periods AS periods
                ON pom.producer_id = periods.producer_id
                AND pom.submitter_id = periods.submitter_id
        )
        SELECT * INTO #LatestAcceptedPomsWith2Periods
        FROM LatestAcceptedPomsWith2Periods;

        WITH
        IncludePackagingMaterialsTable AS (
            SELECT value AS PackagingMaterial FROM STRING_SPLIT(@IncludePackagingMaterials, ',')
        ),
        IncludePackagingTypesTable AS (
            SELECT value AS PackagingType FROM STRING_SPLIT(@IncludePackagingTypes, ',')
        ),
        RegistrationsWithObligations AS (
            SELECT
                organisation_id,
                subsidiary_id,
                submitter_id,
                obligation_status,
                num_days_obligated
            FROM dbo.t_producer_obligation_determination
            WHERE submission_period_year = @RelevantYear
        ),
        LatestAcceptedPomEntries AS (
            SELECT
                lap.organisation_id,
                lap.subsidiary_id,
                lap.submitter_id,
                lap.producer_id,
                producerOrganisation.ExternalId AS external_producer_id,
                lap.submitter_type,
                lap.submission_period,
                lap.submission_period_year,
                pom.packaging_type,
                pom.packaging_material,
                CASE
                    WHEN pom.submission_period = '2023-P2' THEN CAST(pom.packaging_material_weight * 1.50 AS decimal(16, 2))
                    WHEN pom.submission_period = '2024-P2' THEN CAST(pom.packaging_material_weight * 2 AS decimal(16, 2))
                    WHEN pom.submission_period = '2024-P3' THEN CAST(pom.packaging_material_weight * 182.0 / 61 AS decimal(16, 2))
                    ELSE pom.packaging_material_weight
                END AS packaging_material_weight,
                pom.transitional_packaging_units
            FROM #LatestAcceptedPomsWith2Periods AS lap
            INNER JOIN rpd.Organisations AS producerOrganisation
                ON producerOrganisation.ReferenceNumber = lap.producer_id
            INNER JOIN rpd.Pom AS pom
                ON pom.FileName = lap.FileName
                AND COALESCE(NULLIF(TRIM(pom.subsidiary_id), ''), '') = COALESCE(lap.subsidiary_id, '')
                AND pom.organisation_id = lap.organisation_id
        )
        SELECT
            pom.submission_period_year AS SubmissionPeriod,
            pom.submitter_type AS SubmitterType,
            CAST(pom.submitter_id AS uniqueidentifier) AS SubmitterId,
            CAST(pom.external_producer_id AS uniqueidentifier) AS OrganisationId,
            pom.packaging_material AS PackagingMaterial,
            CAST(ROUND((SUM(pom.packaging_material_weight) - COALESCE(SUM(pom.transitional_packaging_units), 0)) / 1000.0, 0) AS int) AS PackagingMaterialWeight,
            obligations.num_days_obligated AS NumberOfDaysObligated
        INTO #ApprovedRecyclingData
        FROM LatestAcceptedPomEntries AS pom
        INNER JOIN #LatestAcceptedPomsWith2Periods AS accepted
            ON accepted.submission_period = pom.submission_period
            AND accepted.organisation_id = pom.organisation_id
            AND COALESCE(accepted.subsidiary_id, '') = COALESCE(pom.subsidiary_id, '')
            AND accepted.submitter_id = pom.submitter_id
        LEFT JOIN RegistrationsWithObligations AS obligations
            ON pom.organisation_id = obligations.organisation_id
            AND COALESCE(pom.subsidiary_id, '') = COALESCE(obligations.subsidiary_id, '')
            AND pom.submitter_id = obligations.submitter_id
            AND obligations.obligation_status = 'O'
        WHERE pom.submitter_id = CAST(@SubmitterId AS varchar(36))
            AND pom.packaging_material IN (SELECT PackagingMaterial FROM IncludePackagingMaterialsTable)
            AND pom.packaging_type IN (SELECT PackagingType FROM IncludePackagingTypesTable)
        GROUP BY
            pom.submission_period_year,
            pom.submitter_id,
            pom.submitter_type,
            pom.external_producer_id,
            pom.packaging_material,
            obligations.num_days_obligated;

        SELECT COUNT_BIG(*) AS TotalItems
        FROM #ApprovedRecyclingData;

        SELECT
            SubmissionPeriod,
            SubmitterType,
            SubmitterId,
            OrganisationId,
            PackagingMaterial,
            PackagingMaterialWeight,
            NumberOfDaysObligated
        FROM #ApprovedRecyclingData
        ORDER BY OrganisationId, PackagingMaterial, NumberOfDaysObligated
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
        """;

    // Local generated data is identified by the data generator's file-name contract. This avoids
    // recalculating every submitter's full result set merely to choose a useful test target. The
    // benchmark performs the exact endpoint query and reports the final record count afterwards.
    internal const string SubmitterDiscoveryQuery = """
        SET NOCOUNT ON;

        WITH
        IncludePackagingMaterialsTable AS (
            SELECT value AS PackagingMaterial FROM STRING_SPLIT(@IncludePackagingMaterials, ',')
        ),
        IncludePackagingTypesTable AS (
            SELECT value AS PackagingType FROM STRING_SPLIT(@IncludePackagingTypes, ',')
        ),
        GeneratedFiles AS (
            SELECT
                cfm.LocalFileName,
                cfm.FileName,
                cfm.LocalComplianceSchemeId,
                cfm.ComplianceSchemeId,
                cfm.OrganisationId
            FROM rpd.cosmos_file_metadata AS cfm
            WHERE cfm.FileName LIKE CONCAT('data-generator/%/', @PeriodYear, '-H%.csv')
        ),
        SubmitterPomRows AS (
            SELECT
                TRY_CAST(COALESCE(files.ComplianceSchemeId, files.OrganisationId) AS uniqueidentifier) AS SubmitterId,
                CASE
                    WHEN NULLIF(TRIM(files.ComplianceSchemeId), '') IS NULL THEN 'DirectRegistrant'
                    ELSE 'ComplianceScheme'
                END AS SubmitterType,
                COALESCE(NULLIF(TRIM(pom.subsidiary_id), ''), CAST(pom.organisation_id AS nvarchar(50))) AS ProducerReference,
                pom.packaging_material
            FROM GeneratedFiles AS files
            INNER JOIN rpd.Pom AS pom
                -- LOCAL SQL SERVER OPTIMISATION: start with generated file metadata then use the
                -- bounded file-name projection to seek the local POM file index.
                ON pom.LocalFileName = files.LocalFileName
                AND pom.FileName = files.FileName
            WHERE pom.LocalSubmissionPeriod IN (CONCAT(@PeriodYear, '-H1'), CONCAT(@PeriodYear, '-H2'))
                AND pom.LocalOrganisationSize = 'L'
                AND pom.submission_period IN (CONCAT(@PeriodYear, '-H1'), CONCAT(@PeriodYear, '-H2'))
                AND pom.organisation_size = 'L'
                AND pom.packaging_material IN (SELECT PackagingMaterial FROM IncludePackagingMaterialsTable)
                AND pom.packaging_type IN (SELECT PackagingType FROM IncludePackagingTypesTable)
        ),
        SubmitterSummaries AS (
            SELECT
                SubmitterId,
                SubmitterType,
                COUNT_BIG(*) AS GeneratedPomRowCount,
                COUNT_BIG(DISTINCT ProducerReference) AS ProducerCount,
                COUNT_BIG(DISTINCT packaging_material) AS PackagingMaterialCount
            FROM SubmitterPomRows
            WHERE SubmitterId IS NOT NULL
            GROUP BY SubmitterId, SubmitterType
        )
        SELECT TOP (@Take)
            SubmitterId,
            SubmitterType,
            GeneratedPomRowCount,
            ProducerCount,
            PackagingMaterialCount
        FROM SubmitterSummaries
        WHERE @SubmitterType IS NULL OR SubmitterType = @SubmitterType
        ORDER BY GeneratedPomRowCount DESC, ProducerCount DESC, SubmitterId;
        """;
}
