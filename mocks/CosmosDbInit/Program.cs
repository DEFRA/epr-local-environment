using Microsoft.Azure.Cosmos;

var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
    ?? throw new InvalidOperationException("COSMOS_ENDPOINT is not configured");
var key = Environment.GetEnvironmentVariable("COSMOS_KEY")
    ?? throw new InvalidOperationException("COSMOS_KEY is not configured");
var databaseName = Environment.GetEnvironmentVariable("COSMOS_DATABASE")
    ?? throw new InvalidOperationException("COSMOS_DATABASE is not configured");

var handler = new HttpClientHandler
{
    ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator,
};

var clientOptions = new CosmosClientOptions
{
    ConnectionMode = ConnectionMode.Gateway,
    HttpClientFactory = () => new HttpClient(handler),
};

using var client = new CosmosClient(endpoint, key, clientOptions);

var database = await client.CreateDatabaseIfNotExistsAsync(databaseName);
Console.WriteLine($"Database ready: {database.Database.Id}");

// epr-pom-api-submission-status's SubmissionContext maps these containers via
// HasPartitionKey + ToJsonProperty, so the physical partition key path must match
// the renamed JSON property, not the C# property name (ValidationEventId is the
// exception - it isn't renamed, so its JSON property name is unchanged).
var containers = new (string Name, string PartitionKeyPath)[]
{
    ("Submissions", "/SubmissionId"),
    ("SubmissionEvents", "/SubmissionEventId"),
    ("ProducerValidationErrors", "/ProducerValidationErrorId"),
    ("ProducerValidationWarnings", "/ValidationEventId"),
};

foreach (var (name, partitionKeyPath) in containers)
{
    var container = await database.Database.CreateContainerIfNotExistsAsync(name, partitionKeyPath);
    Console.WriteLine($"Container ready: {container.Container.Id} (partition key {partitionKeyPath})");
}

Console.WriteLine("Cosmos DB emulator initialisation complete.");
