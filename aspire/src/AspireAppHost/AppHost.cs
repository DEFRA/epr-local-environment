using EPR.AspireAppHost;

var builder = DistributedApplication.CreateBuilder(args);

const string eprProducerRedisName = "epr-producer";

var redis = builder.AddRedis(eprProducerRedisName)
    .WithPassword(null)
    .WithEndpoint(6379, 6379, name: "redis-tcp-endpoint", isProxied: false);

const string password = "Password1!";
var passwordParam = builder.AddParameter("sql-password", password);

var accountsDbSql = builder
    .AddSqlServer("accountsdb-sql", passwordParam)
    .WithEndpoint(1433, 1433, name: "ssms", isProxied: false)
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithEnvironment("MSSQL_SA_PASSWORD", password);

const string accountsDbConnectionString =
    "Server=127.0.0.1,1433;Initial Catalog=AccountsDb;User Id=sa;Password=Password1!;TrustServerCertificate=True;";

builder
    .AddMicroservice("big-vibe-config-tool", "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/");

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