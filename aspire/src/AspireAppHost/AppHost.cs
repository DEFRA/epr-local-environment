using EPR.AspireAppHost;

var builder = DistributedApplication.CreateBuilder(args);

var redis = builder.AddRedis("epr-redis")
    .WithPassword(null)
    .WithHostPort(6379);

builder
    .AddMicroservice("big-vibe-config-tool", "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/");

builder
    .AddMicroservice("regulator-frontend", "epr-regulator-service", "src/EPR.RegulatorService.Frontend.Web")
    .WithReference(redis)
    .WithEnvironment("RedisInstanceName", "epr-redis")
    .WithUrl("https://localhost:7154/regulators/");

// todo: ports from here
builder
    .AddMicroservice("regulator-service-facade", "epr-regulator-service-facade", "src/EPR.RegulatorService.Facade.API")
    .WithUrl("https://localhost:7253/");

builder
    .AddMicroservice("backend-account", "epr-backend-account-microservice", "src/BackendAccountService.Api")
    .WithUrl("http://localhost:5000/swagger/");

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