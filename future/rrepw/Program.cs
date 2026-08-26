using System.Data;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("EprPrnBackend")
    ?? throw new InvalidOperationException("ConnectionStrings:EprPrnBackend must be configured.");

var app = builder.Build();

app.MapGet("/health", () => Results.Ok());

app.MapGet("/organisations/{organisationId:guid}/prns", async (
    Guid organisationId,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    long page = 1,
    long pageSize = 100) =>
{
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
        var items = new List<PrnRow>();

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(PrnSql.Query, connection)
        {
            CommandTimeout = 320
        };
        command.Parameters.Add("@OrganisationId", SqlDbType.UniqueIdentifier).Value = organisationId;
        command.Parameters.Add("@Offset", SqlDbType.BigInt).Value = offset;
        command.Parameters.Add("@PageSize", SqlDbType.BigInt).Value = pageSize;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SequentialAccess, cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new DataException("The PRN query did not return a total count.");
        }

        var totalItems = reader.GetInt64(reader.GetOrdinal("TotalItems"));
        if (!await reader.NextResultAsync(cancellationToken))
        {
            throw new DataException("The PRN query did not return page data.");
        }

        var prnIdOrdinal = reader.GetOrdinal("PrnId");
        var prnNumberOrdinal = reader.GetOrdinal("PrnNumber");
        var organisationIdOrdinal = reader.GetOrdinal("OrganisationId");
        var statusOrdinal = reader.GetOrdinal("Status");
        var materialOrdinal = reader.GetOrdinal("Material");
        var tonnageOrdinal = reader.GetOrdinal("Tonnage");
        var issueDateOrdinal = reader.GetOrdinal("IssueDate");
        var accreditationYearOrdinal = reader.GetOrdinal("AccreditationYear");
        var obligationYearOrdinal = reader.GetOrdinal("ObligationYear");
        var decemberWasteOrdinal = reader.GetOrdinal("DecemberWaste");
        var isExportOrdinal = reader.GetOrdinal("IsExport");

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new PrnRow(
                reader.GetGuid(prnIdOrdinal),
                reader.GetString(prnNumberOrdinal),
                reader.GetGuid(organisationIdOrdinal),
                reader.GetString(statusOrdinal),
                reader.GetString(materialOrdinal),
                reader.GetInt32(tonnageOrdinal),
                reader.GetDateTime(issueDateOrdinal),
                reader.GetString(accreditationYearOrdinal),
                reader.GetString(obligationYearOrdinal),
                reader.GetBoolean(decemberWasteOrdinal),
                reader.GetBoolean(isExportOrdinal)));
        }

        return Results.Ok(new PrnPage(items, page, pageSize, totalItems));
    }
    catch (SqlException exception)
    {
        logger.LogError(exception, "Unable to retrieve PRNs for organisation {OrganisationId}", organisationId);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to retrieve PRNs.");
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Unexpected error retrieving PRNs for organisation {OrganisationId}", organisationId);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to retrieve PRNs.");
    }
});

app.MapGet("/admin/organisations/prns", async (
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    int? obligationYear = null,
    int take = 10) =>
{
    if (obligationYear is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "obligationYear must be between 2024 and 2100 when supplied." });
    }

    if (take < 1)
    {
        return Results.BadRequest(new { error = "take must be a positive integer." });
    }

    try
    {
        var items = new List<PrnOrganisationSummary>();

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(PrnSql.OrganisationDiscoveryQuery, connection)
        {
            CommandTimeout = 320
        };
        command.Parameters.Add("@ObligationYear", SqlDbType.VarChar, 4).Value = obligationYear?.ToString() ?? (object)DBNull.Value;
        command.Parameters.Add("@Take", SqlDbType.Int).Value = take;

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SequentialAccess, cancellationToken);
        var organisationIdOrdinal = reader.GetOrdinal("OrganisationId");
        var prnCountOrdinal = reader.GetOrdinal("PrnCount");
        var totalTonnageOrdinal = reader.GetOrdinal("TotalTonnage");
        var firstIssueDateOrdinal = reader.GetOrdinal("FirstIssueDate");
        var lastIssueDateOrdinal = reader.GetOrdinal("LastIssueDate");

        while (await reader.ReadAsync(cancellationToken))
        {
            items.Add(new PrnOrganisationSummary(
                reader.GetGuid(organisationIdOrdinal),
                reader.GetInt64(prnCountOrdinal),
                reader.GetInt64(totalTonnageOrdinal),
                reader.GetDateTime(firstIssueDateOrdinal),
                reader.GetDateTime(lastIssueDateOrdinal)));
        }

        return Results.Ok(new PrnOrganisationSummaryPage(obligationYear, take, items));
    }
    catch (SqlException exception)
    {
        logger.LogError(exception, "Unable to discover organisations with PRNs for obligation year {ObligationYear}", obligationYear);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to discover organisations with PRNs.");
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Unexpected error discovering organisations with PRNs for obligation year {ObligationYear}", obligationYear);
        return Results.Problem(statusCode: StatusCodes.Status500InternalServerError, title: "Unable to discover organisations with PRNs.");
    }
});

app.Run();

public sealed record PrnRow(
    Guid PrnId,
    string PrnNumber,
    Guid OrganisationId,
    string Status,
    string Material,
    int Tonnage,
    DateTime IssueDate,
    string AccreditationYear,
    string ObligationYear,
    bool DecemberWaste,
    bool IsExport);

public sealed record PrnPage(
    IReadOnlyList<PrnRow> Items,
    long Page,
    long PageSize,
    long TotalItems);

public sealed record PrnOrganisationSummary(
    Guid OrganisationId,
    long PrnCount,
    long TotalTonnage,
    DateTime FirstIssueDate,
    DateTime LastIssueDate);

public sealed record PrnOrganisationSummaryPage(
    int? ObligationYear,
    int Take,
    IReadOnlyList<PrnOrganisationSummary> Items);

internal static class PrnSql
{
    internal const string Query = """
        SET NOCOUNT ON;

        SELECT COUNT_BIG(*) AS TotalItems
        FROM dbo.Prn
        WHERE OrganisationId = @OrganisationId;

        SELECT
            prn.ExternalId AS PrnId,
            prn.PrnNumber,
            prn.OrganisationId,
            status.StatusName AS Status,
            prn.MaterialName AS Material,
            prn.TonnageValue AS Tonnage,
            prn.IssueDate,
            prn.AccreditationYear,
            prn.ObligationYear,
            prn.DecemberWaste,
            prn.IsExport
        FROM dbo.Prn AS prn
        INNER JOIN dbo.PrnStatus AS status
            ON status.Id = prn.PrnStatusId
        WHERE prn.OrganisationId = @OrganisationId
        ORDER BY prn.IssueDate DESC, prn.PrnNumber, prn.ExternalId
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
        """;

    internal const string OrganisationDiscoveryQuery = """
        SELECT TOP (@Take)
            prn.OrganisationId,
            COUNT_BIG(*) AS PrnCount,
            COALESCE(SUM(CAST(prn.TonnageValue AS bigint)), 0) AS TotalTonnage,
            MIN(prn.IssueDate) AS FirstIssueDate,
            MAX(prn.IssueDate) AS LastIssueDate
        FROM dbo.Prn AS prn
        WHERE @ObligationYear IS NULL
            OR prn.ObligationYear = @ObligationYear
        GROUP BY prn.OrganisationId
        ORDER BY PrnCount DESC, TotalTonnage DESC, prn.OrganisationId;
        """;
}
