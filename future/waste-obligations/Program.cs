using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.WebUtilities;

const string recyclingDataClientName = "recycling-data";
const string reexClientName = "reex";
const int maximumPageConcurrency = 8;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("calculation-reference-data.json", optional: false, reloadOnChange: false);

var recyclingDataBaseUrl = builder.Configuration["RecyclingData:BaseUrl"]
    ?? throw new InvalidOperationException("RecyclingData:BaseUrl must be configured.");
var reexBaseUrl = builder.Configuration["Reex:BaseUrl"]
    ?? throw new InvalidOperationException("Reex:BaseUrl must be configured.");
var referenceData = builder.Configuration.GetSection("Calculation").Get<CalculationReferenceData>()
    ?? throw new InvalidOperationException("Calculation reference data must be configured.");

builder.Services.AddHttpClient(recyclingDataClientName, client =>
{
    client.BaseAddress = CreateBaseAddress(recyclingDataBaseUrl);
    client.Timeout = TimeSpan.FromMinutes(10);
});
builder.Services.AddHttpClient(reexClientName, client =>
{
    client.BaseAddress = CreateBaseAddress(reexBaseUrl);
    client.Timeout = TimeSpan.FromMinutes(10);
});
builder.Services.AddSingleton(new ObligationCalculator(referenceData));

var app = builder.Build();

app.MapGet("/health", () => Results.Ok());

app.MapGet("/organisations/{organisationId:guid}/calculate-obligations", async (
    Guid organisationId,
    int year,
    HttpContext httpContext,
    IHttpClientFactory httpClientFactory,
    ObligationCalculator obligationCalculator,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    long? page = null,
    long? pageSize = null,
    int? maxConcurrency = null) =>
{
    // Calculations are read-only but depend on the latest downstream source data.
    // Do not let browsers, proxies, or other intermediaries reuse a previous result.
    httpContext.Response.Headers.CacheControl = "no-store";

    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    if (page is < 1 || pageSize is < 1)
    {
        return Results.BadRequest(new { error = "page and pageSize must both be positive integers when supplied." });
    }

    if (maxConcurrency is < 1 or > maximumPageConcurrency)
    {
        return Results.BadRequest(new { error = $"maxConcurrency must be between 1 and {maximumPageConcurrency} when supplied." });
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
            maxConcurrency ?? 1,
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

app.MapGet("/organisations/{organisationId:guid}/calculate-obligations-with-prns", async (
    Guid organisationId,
    int year,
    HttpContext httpContext,
    IHttpClientFactory httpClientFactory,
    ObligationCalculator obligationCalculator,
    ILogger<Program> logger,
    CancellationToken cancellationToken,
    long? page = null,
    long? pageSize = null,
    int? maxConcurrency = null) =>
{
    // Calculations are read-only but depend on the latest downstream source data.
    // Do not let browsers, proxies, or other intermediaries reuse a previous result.
    httpContext.Response.Headers.CacheControl = "no-store";

    if (year is < 2024 or > 2100)
    {
        return Results.BadRequest(new { error = "year must be between 2024 and 2100." });
    }

    if (page is < 1 || pageSize is < 1)
    {
        return Results.BadRequest(new { error = "page and pageSize must both be positive integers when supplied." });
    }

    if (maxConcurrency is < 1 or > maximumPageConcurrency)
    {
        return Results.BadRequest(new { error = $"maxConcurrency must be between 1 and {maximumPageConcurrency} when supplied." });
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
            maxConcurrency ?? 1,
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

    IReadOnlyList<PrnRow> prns;
    try
    {
        prns = await GetAllPrns(
            httpClientFactory.CreateClient(reexClientName),
            organisationId,
            page,
            pageSize,
            maxConcurrency ?? 1,
            cancellationToken);
    }
    catch (DownstreamException exception)
    {
        logger.LogError(
            exception,
            "Unable to retrieve PRNs for organisation {OrganisationId}",
            organisationId);

        return Results.Problem(
            statusCode: StatusCodes.Status502BadGateway,
            title: "Unable to retrieve PRNs from the downstream service.");
    }

    if (prns.Any(prn => prn.OrganisationId != organisationId))
    {
        logger.LogError(
            "PRNs for organisation {OrganisationId} included rows for another organisation.",
            organisationId);

        return Results.Problem(
            statusCode: StatusCodes.Status502BadGateway,
            title: "The downstream PRNs did not match the requested organisation.");
    }

    try
    {
        var calculations = obligationCalculator.Calculate(recyclingData);
        return Results.Ok(obligationCalculator.AssessWithPrns(calculations, prns, organisationId, year + 1));
    }
    catch (CalculationException exception)
    {
        logger.LogError(
            exception,
            "Unable to calculate obligations with PRNs for organisation {OrganisationId} and year {Year}",
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
    int maxConcurrency,
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

    await GetRemainingPages(
        pages,
        pageCount,
        firstPage.Page,
        maxConcurrency,
        (currentPage, token) => GetRecyclingDataPage(
            recyclingDataClient,
            organisationId,
            year,
            currentPage,
            firstPage.PageSize,
            token),
        cancellationToken);

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

static async Task<IReadOnlyList<PrnRow>> GetAllPrns(
    HttpClient reexClient,
    Guid organisationId,
    long? requestedPage,
    long? requestedPageSize,
    int maxConcurrency,
    CancellationToken cancellationToken)
{
    var firstPage = await GetPrnPage(
        reexClient,
        organisationId,
        requestedPage,
        requestedPageSize,
        cancellationToken);

    if (firstPage.Page < 1 || firstPage.PageSize < 1 || firstPage.TotalItems < 0)
    {
        throw new DownstreamException("The ReEx service returned invalid pagination metadata.");
    }

    var pages = new Dictionary<long, PrnPage> { [firstPage.Page] = firstPage };
    var pageCount = firstPage.TotalItems / firstPage.PageSize;
    if (firstPage.TotalItems % firstPage.PageSize != 0)
    {
        pageCount++;
    }

    await GetRemainingPages(
        pages,
        pageCount,
        firstPage.Page,
        maxConcurrency,
        (currentPage, token) => GetPrnPage(
            reexClient,
            organisationId,
            currentPage,
            firstPage.PageSize,
            token),
        cancellationToken);

    return pages
        .OrderBy(pair => pair.Key)
        .SelectMany(pair => pair.Value.Items)
        .ToList();
}

static async Task GetRemainingPages<TPage>(
    IDictionary<long, TPage> pages,
    long pageCount,
    long firstPageNumber,
    int maxConcurrency,
    Func<long, CancellationToken, Task<TPage>> getPage,
    CancellationToken cancellationToken)
{
    var remainingPages = PageNumbers(pageCount, firstPageNumber);
    if (maxConcurrency == 1)
    {
        foreach (var currentPage in remainingPages)
        {
            pages.Add(currentPage, await getPage(currentPage, cancellationToken));
        }

        return;
    }

    foreach (var batch in remainingPages.Chunk(maxConcurrency))
    {
        var downloadedPages = await Task.WhenAll(batch.Select(async currentPage =>
            new KeyValuePair<long, TPage>(
                currentPage,
                await getPage(currentPage, cancellationToken))));

        foreach (var downloadedPage in downloadedPages)
        {
            pages.Add(downloadedPage.Key, downloadedPage.Value);
        }
    }
}

static IEnumerable<long> PageNumbers(long pageCount, long firstPageNumber)
{
    for (var currentPage = 1L; currentPage <= pageCount; currentPage++)
    {
        if (currentPage != firstPageNumber)
        {
            yield return currentPage;
        }
    }
}

static async Task<PrnPage> GetPrnPage(
    HttpClient reexClient,
    Guid organisationId,
    long? page,
    long? pageSize,
    CancellationToken cancellationToken)
{
    var query = new Dictionary<string, string?>();
    if (page.HasValue)
    {
        query["page"] = page.Value.ToString();
    }

    if (pageSize.HasValue)
    {
        query["pageSize"] = pageSize.Value.ToString();
    }

    var path = $"organisations/{organisationId}/prns";
    using var response = await reexClient.GetAsync(
        QueryHelpers.AddQueryString(path, query),
        cancellationToken);
    if (!response.IsSuccessStatusCode)
    {
        throw new DownstreamException(
            $"The ReEx service returned {(int)response.StatusCode} ({response.StatusCode}).");
    }

    try
    {
        return await response.Content.ReadFromJsonAsync<PrnPage>(cancellationToken: cancellationToken)
            ?? throw new DownstreamException("The ReEx service returned an empty response.");
    }
    catch (JsonException exception)
    {
        throw new DownstreamException("The ReEx service returned an invalid response.", exception);
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

public sealed record ObligationModel(
    IReadOnlyList<ObligationData> ObligationData,
    int NumberOfPrnsAwaitingAcceptance);

public sealed record ObligationData(
    Guid OrganisationId,
    string MaterialName,
    int Tonnage,
    double MaterialTarget,
    int? ObligationToMeet,
    int TonnageAwaitingAcceptance,
    int TonnageAccepted,
    int? TonnageOutstanding,
    string Status);

public sealed class ObligationCalculator(CalculationReferenceData referenceData)
{
    private readonly Dictionary<string, string> _materialNamesByCode =
        new(referenceData.MaterialCodes, StringComparer.OrdinalIgnoreCase);

    private readonly Dictionary<int, Dictionary<string, decimal>> _targetsByYear = referenceData.RecyclingTargets
        .ToDictionary(
            entry => entry.Key,
            entry => new Dictionary<string, decimal>(entry.Value, StringComparer.OrdinalIgnoreCase));

    private static readonly IReadOnlyDictionary<string, string[]> PrnMaterialNamesByMaterial =
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            ["Aluminium"] = ["Aluminium"],
            ["FibreComposite"] = ["Fibre"],
            ["Glass"] = ["Glass Other"],
            ["GlassRemelt"] = ["Glass Re-melt"],
            ["Paper"] = ["Paper/board", "Paper Composting"],
            ["Plastic"] = ["Plastic"],
            ["Steel"] = ["Steel"],
            ["Wood"] = ["Wood", "Wood Composting"]
        };

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

    public ObligationModel AssessWithPrns(
        IReadOnlyList<CalculatedObligation> calculations,
        IReadOnlyList<PrnRow> prns,
        Guid organisationId,
        int complianceYear)
    {
        var relevantPrns = prns.Where(prn => IsRelevantPrn(prn, complianceYear)).ToList();
        var acceptedTonnageByMaterial = GetTonnageByMaterial(relevantPrns, "ACCEPTED");
        var awaitingTonnageByMaterial = GetTonnageByMaterial(relevantPrns, "AWAITINGACCEPTANCE");

        var obligationData = new List<ObligationData>();
        var paperAndFibreData = new List<ObligationData>();
        foreach (var material in _materialNamesByCode.Values.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var data = CreateObligationData(
                material,
                organisationId,
                calculations,
                acceptedTonnageByMaterial,
                awaitingTonnageByMaterial,
                complianceYear);

            if (material is "Paper" or "FibreComposite")
            {
                paperAndFibreData.Add(data);
            }
            else
            {
                obligationData.Add(data);
            }
        }

        if (paperAndFibreData.Count > 0)
        {
            obligationData.Add(CombinePaperAndFibre(paperAndFibreData));
        }

        AdjustTonnageOutstandingForGlass(obligationData);
        return new ObligationModel(
            obligationData,
            relevantPrns.Count(prn => string.Equals(prn.Status, "AWAITINGACCEPTANCE", StringComparison.OrdinalIgnoreCase)));
    }

    private ObligationData CreateObligationData(
        string material,
        Guid organisationId,
        IReadOnlyList<CalculatedObligation> calculations,
        IReadOnlyDictionary<string, int> acceptedTonnageByMaterial,
        IReadOnlyDictionary<string, int> awaitingTonnageByMaterial,
        int complianceYear)
    {
        var materialCalculations = calculations
            .Where(calculation => string.Equals(calculation.Material, material, StringComparison.OrdinalIgnoreCase))
            .ToList();
        var acceptedTonnage = GetTonnage(material, acceptedTonnageByMaterial);
        var awaitingTonnage = GetTonnage(material, awaitingTonnageByMaterial);
        int? obligationToMeet = materialCalculations.Count == 0
            ? null
            : materialCalculations.Sum(calculation => calculation.MaterialObligationValue);

        return new ObligationData(
            organisationId,
            material,
            materialCalculations.Sum(calculation => calculation.Tonnage),
            (double)GetTarget(_targetsByYear[complianceYear], material, complianceYear),
            obligationToMeet,
            awaitingTonnage,
            acceptedTonnage,
            obligationToMeet is null ? null : obligationToMeet - acceptedTonnage,
            GetStatus(obligationToMeet, acceptedTonnage));
    }

    private static ObligationData CombinePaperAndFibre(IReadOnlyList<ObligationData> paperAndFibreData)
    {
        int? obligationToMeet = paperAndFibreData.Any(data => data.ObligationToMeet.HasValue)
            ? paperAndFibreData.Sum(data => data.ObligationToMeet ?? 0)
            : null;
        var acceptedTonnage = paperAndFibreData.Sum(data => data.TonnageAccepted);

        return new ObligationData(
            paperAndFibreData[0].OrganisationId,
            "Paper",
            paperAndFibreData.Sum(data => data.Tonnage),
            paperAndFibreData[0].MaterialTarget,
            obligationToMeet,
            paperAndFibreData.Sum(data => data.TonnageAwaitingAcceptance),
            acceptedTonnage,
            paperAndFibreData.Any(data => data.TonnageOutstanding.HasValue)
                ? paperAndFibreData.Sum(data => data.TonnageOutstanding ?? 0)
                : (int?)null,
            GetStatus(obligationToMeet, acceptedTonnage));
    }

    private static bool IsRelevantPrn(PrnRow prn, int complianceYear)
    {
        if (string.Equals(prn.Status, "ACCEPTED", StringComparison.OrdinalIgnoreCase))
        {
            return string.Equals(prn.ObligationYear, complianceYear.ToString(), StringComparison.Ordinal);
        }

        return string.Equals(prn.Status, "AWAITINGACCEPTANCE", StringComparison.OrdinalIgnoreCase)
            && (string.Equals(prn.ObligationYear, complianceYear.ToString(), StringComparison.Ordinal)
                || (string.Equals(prn.AccreditationYear, (complianceYear - 1).ToString(), StringComparison.Ordinal)
                    && prn.DecemberWaste));
    }

    private static IReadOnlyDictionary<string, int> GetTonnageByMaterial(
        IReadOnlyList<PrnRow> prns,
        string status) => prns
        .Where(prn => string.Equals(prn.Status, status, StringComparison.OrdinalIgnoreCase))
        .GroupBy(prn => prn.Material, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(group => group.Key, group => group.Sum(prn => prn.Tonnage), StringComparer.OrdinalIgnoreCase);

    private static int GetTonnage(string material, IReadOnlyDictionary<string, int> tonnageByMaterial) =>
        PrnMaterialNamesByMaterial[material]
            .Where(tonnageByMaterial.ContainsKey)
            .Sum(prnMaterialName => tonnageByMaterial[prnMaterialName]);

    private static string GetStatus(int? obligationToMeet, int tonnageAccepted)
    {
        if (!obligationToMeet.HasValue)
        {
            return "NoDataYet";
        }

        return tonnageAccepted >= obligationToMeet ? "Met" : "NotMet";
    }

    private static void AdjustTonnageOutstandingForGlass(List<ObligationData> obligationData)
    {
        var glassRemelt = obligationData.Find(data => data.MaterialName == "GlassRemelt"
            && data.TonnageOutstanding is < 0);
        var glass = obligationData.Find(data => data.MaterialName == "Glass"
            && data.TonnageOutstanding is > 0);

        if (glassRemelt is not null && glass is not null)
        {
            var adjustedOutstanding = glass.TonnageOutstanding + glassRemelt.TonnageOutstanding;
            var adjustedAcceptedTonnage = glass.TonnageAccepted + -glassRemelt.TonnageOutstanding.GetValueOrDefault();
            var glassIndex = obligationData.IndexOf(glass);
            obligationData[glassIndex] = glass with
            {
                TonnageOutstanding = adjustedOutstanding,
                Status = GetStatus(glass.ObligationToMeet, adjustedAcceptedTonnage)
            };
        }

        for (var index = 0; index < obligationData.Count; index++)
        {
            if (obligationData[index].TonnageOutstanding is < 0)
            {
                obligationData[index] = obligationData[index] with { TonnageOutstanding = 0 };
            }
        }
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
