using Aspire.Hosting.Azure;
using EPR.AspireAppHost;


var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddMicroservice("big-vibe-config-tool", "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/");

const string eprProducerRedisName = "epr-producer";
const string password = "Password1!";
const string accountsDbConnectionString =
    $"Server=127.0.0.1,1433;Initial Catalog=AccountsDb;User Id=sa;Password={password};TrustServerCertificate=True;";
const string prnDbConnectionString =
    $"Server=127.0.0.1,1434;Initial Catalog=PrnDb;User Id=sa;Password={password};TrustServerCertificate=True;";

var serviceBusQueueName = builder.Configuration["ServiceBus:QueueName"] ?? "epr.queue";
var serviceBusName = builder.Configuration["ServiceBus:Name"] ?? "service-bus";
var serviceBusConnectionString = builder.Configuration["ServiceBus:ConnectionString"];
var useServiceBusEmulator = string.IsNullOrWhiteSpace(serviceBusConnectionString);
var passwordParam = builder.AddParameter("sql-password", password);

// Currently we cant use a single SQL Server instance for multiple 'microservices' as they have been implemented using differing versions of EntityFramework
var accountsDbSql = builder
    .AddSqlServer("accounts-db", passwordParam)
    .WithEndpoint(1433, 1433, name: "ssms", isProxied: false)
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithEnvironment("MSSQL_SA_PASSWORD", password);

var prnDbSql = builder
    .AddSqlServer("prn-db", passwordParam)
    .WithEndpoint(1434, 1433, name: "prn-ssms", isProxied: false)
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithEnvironment("MSSQL_SA_PASSWORD", password);

var redis = builder.AddRedis(eprProducerRedisName)
    .WithPassword(null)
    .WithEndpoint(6379, 6379, name: "redis-tcp-endpoint", isProxied: false);

IResourceBuilder<AzureServiceBusResource>? serviceBus = null;
if (useServiceBusEmulator)
{
    serviceBus = builder.AddAzureServiceBus(serviceBusName)
        .RunAsEmulator();

    serviceBus.AddServiceBusQueue(
        "epr-queue",
        serviceBusQueueName
    );
}

builder
    .AddMicroservice("common-data-api", "epr-common-data-api", "src/EPR.CommonDataService.Api")
    .WithReference(redis)
    .WithUrl("http://localhost:5001/");

builder
    .AddMicroservice("pom-api-submission-status", "epr-pom-api-submission-status", "src/EPR.SubmissionMicroservice.API")
    .WithReference(redis)
    .WithUrl("https://localhost:7206/");

builder
    .AddMicroservice("prn-common-backend-api", "epr-prn-common-backend", "src/EPR.PRN.Backend.API")
    .WithEnvironment("ConnectionStrings__EprConnectionString", prnDbConnectionString)
    .WaitFor(prnDbSql)
    .WithReference(redis)
    .WithUrl("http://localhost:5168/");

var loggingApi = builder
    .AddMicroservice("logging-api", "epr-logging-api", "LoggingMicroservice/LoggingMicroservice.API")
    .WithReference(redis)
    .WithEnvironment("ServiceBus__QueueName", serviceBusQueueName)
    .WithUrl("https://localhost:7266/");

// Set connection string: use provided connection string for Azure, or service bus reference for emulator
if (useServiceBusEmulator)
{
    loggingApi.WithReference(serviceBus!);
    loggingApi.WithEnvironment("ServiceBus__ConnectionString", serviceBus!);
}
else
{
    loggingApi.WithEnvironment("ServiceBus__ConnectionString", serviceBusConnectionString);
}

builder
    .AddMicroservice("regulator-frontend", "epr-regulator-service", "src/EPR.RegulatorService.Frontend.Web")
    .WithReference(redis)
    .WithEnvironment("RedisInstanceName", eprProducerRedisName)
    .WithUrl("https://localhost:7154/regulators/");

// todo: ports from here
builder
    .AddMicroservice("regulator-service-facade", "epr-regulator-service-facade", "src/EPR.RegulatorService.Facade.API")
    .WithUrl("https://localhost:7253/");

builder
    .AddMicroservice("backend-account", "epr-backend-account-microservice", "src/BackendAccountService.Api")
    .WithEnvironment("ConnectionStrings__AccountsDatabase", accountsDbConnectionString)
    .WaitFor(accountsDbSql)
    .WithUrl("http://localhost:5000/swagger/");

builder
    .AddMicroservice("frontend-account-creation", "epr-frontend-accountcreation-microservice",
        "src/FrontendAccountCreation.Web/")
    .WithUrl("https://localhost:7154/");

builder
    .AddMicroservice("obligationchecker-frontend", "epr-obligationchecker-frontend",
        "src/FrontendObligationChecker/")
    .WithReference(redis)
    .WithEnvironment("REDIS_INSTANCE_NAME", eprProducerRedisName)
    .WithUrl("https://localhost:7022/public-register");

builder
    .AddExecutable("likeC4",
        "npm",
        PathFinder.RepoPath("extended-producer-responsibility-docs"),
        "run", "serve")
    .WithUrl("http://localhost:5173/")
    .WithExplicitStart();

builder.Build().Run();