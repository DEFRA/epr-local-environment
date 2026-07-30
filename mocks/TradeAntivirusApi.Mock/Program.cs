using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Messaging.ServiceBus;

var builder = WebApplication.CreateBuilder(args);

var serviceBusConnectionString = builder.Configuration["ServiceBus:ConnectionString"]
    ?? throw new InvalidOperationException("ServiceBus:ConnectionString is not configured");
var topicName = builder.Configuration["ServiceBus:TopicName"]
    ?? throw new InvalidOperationException("ServiceBus:TopicName is not configured");
var virusFilenamePattern = builder.Configuration["VirusFilenamePattern"] ?? "virus";
var scanDelaySeconds = double.TryParse(builder.Configuration["ScanDelaySeconds"], out var configuredDelay) ? configuredDelay : 1;

var jsonOptions = new JsonSerializerOptions();
jsonOptions.Converters.Add(new JsonStringEnumConverter());

builder.Services.AddSingleton(new ServiceBusClient(serviceBusConnectionString));
builder.Services.AddSingleton<FileStore>();

var app = builder.Build();

var serviceBusClient = app.Services.GetRequiredService<ServiceBusClient>();
var serviceBusSender = serviceBusClient.CreateSender(topicName);
var fileStore = app.Services.GetRequiredService<FileStore>();
var logger = app.Services.GetRequiredService<ILogger<Program>>();

app.MapGet("/health", () => Results.Ok("Healthy"));

// Fire-and-forget submit: mirrors WebApiGateway.Api.Clients.AntivirusClient.SendFileAsync.
app.MapPut("/files/stream/{collection}/{key}", async (string collection, Guid key, HttpRequest request) =>
{
    if (!request.HasFormContentType)
    {
        return Results.BadRequest("Expected multipart/form-data content");
    }

    var form = await request.ReadFormAsync();
    var file = form.Files["fileStream"];
    if (file is null)
    {
        return Results.BadRequest("Missing fileStream part");
    }

    using var memoryStream = new MemoryStream();
    await file.CopyToAsync(memoryStream);

    fileStore.Save(collection, key, file.FileName, memoryStream.ToArray());

    var isVirus = file.FileName.Contains(virusFilenamePattern, StringComparison.OrdinalIgnoreCase);
    var status = isVirus ? ScanResult.Quarantined : ScanResult.Success;

    logger.LogInformation(
        "Accepted file '{FileName}' for collection '{Collection}'/{Key}, scheduling scan result {Status} in {Delay}s",
        file.FileName, collection, key, status, scanDelaySeconds);

    _ = PublishScanResultAsync(collection, key, status);

    return Results.Created($"/files/stream/{collection}/{key}", null);
});

// Retrieval: mirrors EPR.Antivirus.Application.Clients.TradeAntivirusApiClient.GetFileAsync,
// called by the antivirus function once a scan comes back clean.
app.MapGet("/files/stream/{collection}/{key}", (string collection, Guid key) =>
{
    var stored = fileStore.Get(collection, key);
    return stored is null
        ? Results.NotFound()
        : Results.File(stored.Content, "application/octet-stream", stored.FileName);
});

// Optional sync path: mirrors WebApiGateway.Api.Clients.AntivirusClient.SendFileAndScanAsync,
// used by the facade's file-download re-scan. Not on the upload path.
app.MapPut("/SyncAV/{collection}/{key}", async (string collection, Guid key, HttpRequest request) =>
{
    using var reader = new StreamReader(request.Body);
    var body = await reader.ReadToEndAsync();

    string fileName;
    try
    {
        using var document = JsonDocument.Parse(body);
        fileName = document.RootElement.TryGetProperty("fileName", out var fileNameProperty)
            ? fileNameProperty.GetString() ?? string.Empty
            : string.Empty;
    }
    catch (JsonException)
    {
        fileName = string.Empty;
    }

    var isVirus = fileName.Contains(virusFilenamePattern, StringComparison.OrdinalIgnoreCase);

    // WebApiGateway.Api.Constants.ContentScan compares this response verbatim against
    // "Content-Scan: Clean" (see FileDownloadController/SubmissionService) - it does not
    // accept the "Success"/"Quarantined" ScanResult names used on the async upload path.
    return Results.Text(isVirus ? "Content-Scan: Malicious" : "Content-Scan: Clean", "text/plain");
});

app.Run();

return;

async Task PublishScanResultAsync(string collection, Guid key, ScanResult status)
{
    try
    {
        await Task.Delay(TimeSpan.FromSeconds(scanDelaySeconds));

        var result = new TradeAntivirusQueueResult(key, collection, status);
        var json = JsonSerializer.Serialize(result, jsonOptions);
        var message = new ServiceBusMessage(Encoding.UTF8.GetBytes(json));

        await serviceBusSender.SendMessageAsync(message);

        logger.LogInformation("Published scan result {Status} for {Collection}/{Key}", status, collection, key);
    }
    catch (Exception exception)
    {
        logger.LogError(exception, "Failed to publish scan result for {Collection}/{Key}", collection, key);
    }
}

// Mirrors EPR.Antivirus.Data.DTOs.TradeAntivirusQueue.TradeAntivirusQueueResult.
internal record TradeAntivirusQueueResult(Guid Key, string Collection, ScanResult Status);

// Mirrors EPR.Antivirus.Data.Enums.ScanResult.
internal enum ScanResult
{
    AwaitingProcessing = 1,
    Success = 2,
    FileInaccessible = 3,
    Quarantined = 4,
    FailedToVirusScan = 5,
}

internal sealed class StoredFile(string fileName, byte[] content)
{
    public string FileName { get; } = fileName;

    public byte[] Content { get; } = content;
}

internal sealed class FileStore
{
    private readonly ConcurrentDictionary<string, StoredFile> _files = new();

    public void Save(string collection, Guid key, string fileName, byte[] content) =>
        _files[Key(collection, key)] = new StoredFile(fileName, content);

    public StoredFile? Get(string collection, Guid key) =>
        _files.GetValueOrDefault(Key(collection, key));

    private static string Key(string collection, Guid key) => $"{collection}/{key}";
}
