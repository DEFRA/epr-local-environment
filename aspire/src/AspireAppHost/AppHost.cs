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

// epr-common-data-api [WAx415]
builder
    .AddMicroservice("common-data-api", "epr-common-data-api", "src/EPR.CommonDataService.Api")
    .WithReference(redis)
    .WithUrl("http://localhost:5001/");

// epr-pom-api-submission-status [WAx408]
builder
    .AddMicroservice("pom-api-submission-status", "epr-pom-api-submission-status", "src/EPR.SubmissionMicroservice.API")
    .WithReference(redis)
    .WithUrl("https://localhost:7206/");

// epr-prn-common-backend [WAx418]
builder
    .AddMicroservice("prn-common-backend-api", "epr-prn-common-backend", "src/EPR.PRN.Backend.API")
    .WithEnvironment("ConnectionStrings__EprConnectionString", prnDbConnectionString)
    .WaitFor(prnDbSql)
    .WithReference(redis)
    .WithUrl("http://localhost:5168/");

// epr-logging-api [WAx403]
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

// epr-backend-account-microservice [WAx407]
builder
    .AddMicroservice("backend-account", "epr-backend-account-microservice", "src/BackendAccountService.Api")
    .WithEnvironment("ConnectionStrings__AccountsDatabase", accountsDbConnectionString)
    .WaitFor(accountsDbSql)
    .WithUrl("http://localhost:5000/swagger/");

// epr-regulator-service-facade [WAx406]
builder
    .AddMicroservice("regulator-service-facade", "epr-regulator-service-facade", "src/EPR.RegulatorService.Facade.API")
    .WithUrl("https://localhost:7253/");

// epr-regulator-service [WAx411]
builder
    .AddMicroservice("regulator-frontend", "epr-regulator-service", "src/EPR.RegulatorService.Frontend.Web")
    .WithReference(redis)
    .WithEnvironment("RedisInstanceName", eprProducerRedisName)
    .WithUrl("https://localhost:7154/regulators/");

// epr-pom-api-web [WAx409]
builder
    .AddMicroservice("pom-api-web", "epr-pom-api-web", "WebApiGateway/WebApiGateway.Api/")
    .WithReference(redis)
    .WithUrl("https://localhost:7265");

// epr-obligationchecker-frontend [WAx401]
builder
    .AddMicroservice("obligationchecker-frontend", "epr-obligationchecker-frontend",
        "src/FrontendObligationChecker/")
    .WithReference(redis)
    .WithEnvironment("REDIS_INSTANCE_NAME", eprProducerRedisName)
    .WithUrl("https://localhost:7022/public-register");

// epr-packaging-frontend [WAx410]
builder
    .AddMicroservice("packaging-frontend", "epr-packaging-frontend",
        "src/FrontendSchemeRegistration.UI/")
    .WithReference(redis)
    .WithEnvironment("InstanceName", eprProducerRedisName)
    .WithUrl("https://localhost:7084/report-data");

// epr-frontend-accountcreation-microservice [WAx402]
builder
    .AddMicroservice("frontend-account-creation", "epr-frontend-accountcreation-microservice",
        "src/FrontendAccountCreation.Web/")
    .WithUrl("https://localhost:7154/");

builder
    .AddExecutable("likeC4",
        "npm",
        PathFinder.RepoPath("extended-producer-responsibility-docs"),
        "run", "serve")
    .WithUrl("http://localhost:5173/")
    .WithExplicitStart();

builder.Build().Run();