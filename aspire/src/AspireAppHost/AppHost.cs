using EPR.AspireAppHost;

var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddMicroservice(name: "big-vibe-config-tool", repoFolder: "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/");

builder
    .AddMicroservice(name: "regulator-frontend", repoFolder: "epr-regulator-service", workingDirectory: "src/EPR.RegulatorService.Frontend.Web")
    .WithUrl("https://localhost:7154/regulators/");

// todo: ports from here
builder
    .AddMicroservice(name: "regulator-service-facade", repoFolder: "epr-regulator-service-facade", workingDirectory: "src/EPR.RegulatorService.Facade.API")
    .WithUrl("https://localhost:7253/");

builder
    .AddMicroservice(name: "backend-account", repoFolder: "epr-backend-account-microservice", workingDirectory: "src/BackendAccountService.Api")
    .WithUrl("http://localhost:5000/swagger/");

builder
    .AddMicroservice(name: "frontend-account-creation", repoFolder: "epr-frontend-accountcreation-microservice", workingDirectory: "src/FrontendAccountCreation.Web/")
    .WithUrl("https://localhost:7154/");

builder
    .AddExecutable(name: "likeC4",
        command: "npm",
        workingDirectory: PathFinder.RepoPath("extended-producer-responsibility-docs"),
        "run", "serve")
    .WithUrl("http://localhost:5173/")
    .WithExplicitStart();

builder.Build().Run();