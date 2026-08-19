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
    CancellationToken cancellationToken) =>
{
    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    try
    {
        var rows = new List<RecyclingDataRow>();

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(RecyclingDataSql.Query, connection)
        {
            CommandTimeout = 320
        };

        command.Parameters.Add("@PeriodYear", SqlDbType.VarChar, 4).Value = year.ToString(CultureInfo.InvariantCulture);
        command.Parameters.Add("@SubmitterId", SqlDbType.UniqueIdentifier).Value = submitterId;
        command.Parameters.Add("@IncludePackagingTypes", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingTypes;
        command.Parameters.Add("@IncludePackagingMaterials", SqlDbType.VarChar, -1).Value = RecyclingDataSql.IncludedPackagingMaterials;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SequentialAccess, cancellationToken);
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

        return rows.Count == 0 ? Results.NoContent() : Results.Ok(rows);
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

app.Run();

public sealed record RecyclingDataRow(
    string SubmissionPeriod,
    string SubmitterType,
    Guid SubmitterId,
    Guid OrganisationId,
    string PackagingMaterial,
    int PackagingMaterialWeight,
    int? NumberOfDaysObligated);

internal static class RecyclingDataSql
{
    // These lists are deliberately part of the service contract, not request parameters.
    internal const string IncludedPackagingTypes = "HH,NH,PB,HDC,NDC";
    internal const string IncludedPackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";

    // Derived from dbo.sp_GetApprovedSubmissionsMyc. It is application SQL so this service has no
    // runtime dependency on that stored procedure. dbo.udf_DQ_SubmissionPeriod remains an upstream
    // data-quality helper function and is restored with the Common Data database.
    internal const string Query = """
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
        """;
}
