using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.WebUtilities;

const string recyclingDataClientName = "recycling-data";

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("calculation-reference-data.json", optional: false, reloadOnChange: false);

var recyclingDataBaseUrl = builder.Configuration["RecyclingData:BaseUrl"]
    ?? throw new InvalidOperationException("RecyclingData:BaseUrl must be configured.");
var referenceData = builder.Configuration.GetSection("Calculation").Get<CalculationReferenceData>()
    ?? throw new InvalidOperationException("Calculation reference data must be configured.");

builder.Services.AddHttpClient(recyclingDataClientName, client =>
{
    client.BaseAddress = CreateBaseAddress(recyclingDataBaseUrl);
    client.Timeout = TimeSpan.FromMinutes(10);
});
builder.Services.AddSingleton(new ObligationCalculator(referenceData));

var app = builder.Build();

app.MapGet("/health", () => Results.Ok());

app.MapPost("/organisations/{organisationId:guid}/calculate-obligations", async (
    Guid organisationId,
    int year,
    IHttpClientFactory httpClientFactory,
    ObligationCalculator obligationCalculator,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    long? page = null,
    long? pageSize = null) =>
{
    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    if (page is < 1 || pageSize is < 1)
    {
        return Results.BadRequest(new { error = "page and pageSize must both be positive integers when supplied." });
    }

    IReadOnlyList<RecyclingDataRow> recyclingData;
    try
    {
        recyclingData = await GetAllRecyclingData(
            httpClientFactory.CreateClient(recyclingDataClientName),
            organisationId,
            year,
            page,
            pageSize,
            cancellationToken);
    }
    catch (DownstreamException exception)
    {
        logger.LogError(
            exception,
            "Unable to retrieve recycling data for organisation {OrganisationId} and year {Year}",
            organisationId,
            year);

        return Results.Problem(
            statusCode: StatusCodes.Status502BadGateway,
            title: "Unable to retrieve recycling data from the downstream service.");
    }

    if (recyclingData.Count == 0)
    {
        return Results.NotFound(new { error = "No approved recycling data was found for the organisation and year." });
    }

    if (recyclingData.Any(row => row.SubmitterId != organisationId))
    {
        logger.LogError(
            "Recycling data for organisation {OrganisationId} included rows for another submitter.",
            organisationId);

        return Results.Problem(
            statusCode: StatusCodes.Status502BadGateway,
            title: "The downstream recycling data did not match the requested organisation.");
    }

    try
    {
        return Results.Ok(obligationCalculator.Calculate(recyclingData));
    }
    catch (CalculationException exception)
    {
        logger.LogError(
            exception,
            "Unable to calculate obligations for organisation {OrganisationId} and year {Year}",
            organisationId,
            year);

        return Results.Problem(
            statusCode: StatusCodes.Status500InternalServerError,
            title: "Unable to calculate obligations from the configured reference data.");
    }
});

app.Run();

static async Task<IReadOnlyList<RecyclingDataRow>> GetAllRecyclingData(
    HttpClient recyclingDataClient,
    Guid organisationId,
    int year,
    long? requestedPage,
    long? requestedPageSize,
    CancellationToken cancellationToken)
{
    var firstPage = await GetRecyclingDataPage(
        recyclingDataClient,
        organisationId,
        year,
        requestedPage,
        requestedPageSize,
        cancellationToken);

    if (firstPage.Page < 1 || firstPage.PageSize < 1 || firstPage.TotalItems < 0)
    {
        throw new DownstreamException("The recycling data service returned invalid pagination metadata.");
    }

    var pages = new Dictionary<long, RecyclingDataPage> { [firstPage.Page] = firstPage };
    var pageCount = firstPage.TotalItems / firstPage.PageSize;
    if (firstPage.TotalItems % firstPage.PageSize != 0)
    {
        pageCount++;
    }

    for (var currentPage = 1L; currentPage <= pageCount; currentPage++)
    {
        if (!pages.ContainsKey(currentPage))
        {
            pages[currentPage] = await GetRecyclingDataPage(
                recyclingDataClient,
                organisationId,
                year,
                currentPage,
                firstPage.PageSize,
                cancellationToken);
        }
    }

    return pages
        .OrderBy(pair => pair.Key)
        .SelectMany(pair => pair.Value.Items)
        .ToList();
}

static async Task<RecyclingDataPage> GetRecyclingDataPage(
    HttpClient recyclingDataClient,
    Guid organisationId,
    int year,
    long? page,
    long? pageSize,
    CancellationToken cancellationToken)
{
    var query = new Dictionary<string, string?>
    {
        ["year"] = year.ToString(),
        ["submitterId"] = organisationId.ToString()
    };

    if (page.HasValue)
    {
        query["page"] = page.Value.ToString();
    }

    if (pageSize.HasValue)
    {
        query["pageSize"] = pageSize.Value.ToString();
    }

    using var response = await recyclingDataClient.GetAsync(
        QueryHelpers.AddQueryString("recycling-data", query),
        cancellationToken);
    if (!response.IsSuccessStatusCode)
    {
        throw new DownstreamException(
            $"The recycling data service returned {(int)response.StatusCode} ({response.StatusCode}).");
    }

    try
    {
        return await response.Content.ReadFromJsonAsync<RecyclingDataPage>(cancellationToken: cancellationToken)
            ?? throw new DownstreamException("The recycling data service returned an empty response.");
    }
    catch (JsonException exception)
    {
        throw new DownstreamException("The recycling data service returned an invalid response.", exception);
    }
}

static Uri CreateBaseAddress(string value) =>
    new(value.EndsWith('/') ? value : $"{value}/", UriKind.Absolute);

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
    long TotalItems);

public sealed record CalculatedObligation(
    Guid OrganisationId,
    Guid SubmitterId,
    string SubmitterType,
    string MaterialCode,
    string Material,
    int MaterialObligationValue,
    int Year,
    int Tonnage,
    DateTime CalculatedOn);

public sealed class ObligationCalculator(CalculationReferenceData referenceData)
{
    private readonly Dictionary<string, string> _materialNamesByCode =
        new(referenceData.MaterialCodes, StringComparer.OrdinalIgnoreCase);

    private readonly Dictionary<int, Dictionary<string, decimal>> _targetsByYear = referenceData.RecyclingTargets
        .ToDictionary(
            entry => entry.Key,
            entry => new Dictionary<string, decimal>(entry.Value, StringComparer.OrdinalIgnoreCase));

    public IReadOnlyList<CalculatedObligation> Calculate(IReadOnlyList<RecyclingDataRow> recyclingData)
    {
        var calculations = new List<CalculatedObligation>();

        foreach (var row in recyclingData)
        {
            if (!int.TryParse(row.SubmissionPeriod, out var submissionYear))
            {
                continue;
            }

            if (!_materialNamesByCode.TryGetValue(row.PackagingMaterial, out var material))
            {
                continue;
            }

            var complianceYear = submissionYear + 1;
            if (!_targetsByYear.TryGetValue(complianceYear, out var targets))
            {
                throw new CalculationException($"No recycling targets are configured for compliance year {complianceYear}.");
            }

            if (string.Equals(material, "Glass", StringComparison.OrdinalIgnoreCase))
            {
                AddGlassCalculations(calculations, row, complianceYear, targets);
                continue;
            }

            var target = GetTarget(targets, material, complianceYear);
            calculations.Add(new CalculatedObligation(
                row.OrganisationId,
                row.SubmitterId,
                row.SubmitterType,
                row.PackagingMaterial,
                material,
                Calculate(target, row.PackagingMaterialWeight, row.NumberOfDaysObligated, complianceYear),
                complianceYear,
                row.PackagingMaterialWeight,
                DateTime.UtcNow));
        }

        if (calculations.Count == 0)
        {
            throw new CalculationException("No valid recycling data rows could be calculated.");
        }

        return calculations;
    }

    private static decimal GetTarget(
        IReadOnlyDictionary<string, decimal> targets,
        string material,
        int complianceYear) => targets.TryGetValue(material, out var target)
            ? target
            : throw new CalculationException(
                $"No recycling target is configured for material {material} in compliance year {complianceYear}.");

    private static int Calculate(decimal target, int tonnage, int? numberOfDaysObligated, int complianceYear)
    {
        var scale = GetObligationScale(numberOfDaysObligated, complianceYear);
        var result = (int)Math.Ceiling(target * tonnage);

        return (int)Math.Ceiling(result * scale);
    }

    private static void AddGlassCalculations(
        ICollection<CalculatedObligation> calculations,
        RecyclingDataRow row,
        int complianceYear,
        IReadOnlyDictionary<string, decimal> targets)
    {
        var glassTarget = GetTarget(targets, "Glass", complianceYear);
        var glassRemeltTarget = GetTarget(targets, "GlassRemelt", complianceYear);
        var scale = GetObligationScale(row.NumberOfDaysObligated, complianceYear);
        var initialTarget = glassTarget * row.PackagingMaterialWeight;
        var remelt = (int)Math.Ceiling(glassRemeltTarget * initialTarget);
        var total = (int)Math.Ceiling(initialTarget);
        var remainder = total - remelt;
        var calculatedOn = DateTime.UtcNow;

        calculations.Add(CreateGlassCalculation("GL", "Glass", remainder));
        calculations.Add(CreateGlassCalculation("GR", "GlassRemelt", remelt));

        CalculatedObligation CreateGlassCalculation(string materialCode, string material, int obligation) => new(
            row.OrganisationId,
            row.SubmitterId,
            row.SubmitterType,
            materialCode,
            material,
            (int)Math.Ceiling(obligation * scale),
            complianceYear,
            row.PackagingMaterialWeight,
            calculatedOn);
    }

    private static decimal GetObligationScale(int? numberOfDaysObligated, int complianceYear) =>
        numberOfDaysObligated is null
            ? 1m
            : (decimal)numberOfDaysObligated.Value / (DateTime.IsLeapYear(complianceYear) ? 366 : 365);
}

public sealed class CalculationReferenceData
{
    public Dictionary<string, string> MaterialCodes { get; init; } = [];

    public Dictionary<int, Dictionary<string, decimal>> RecyclingTargets { get; init; } = [];
}

public sealed class CalculationException(string message) : Exception(message);

public sealed class DownstreamException : Exception
{
    public DownstreamException(string message)
        : base(message)
    {
    }

    public DownstreamException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
