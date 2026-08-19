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
}
