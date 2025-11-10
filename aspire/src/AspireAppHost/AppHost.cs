using EPR.AspireAppHost;

var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddMicroservice(name: "big-vibe-config-tool", repoFolder: "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/")
    .WithExplicitStart();

builder
    .AddMicroservice(name: "regulator-frontend", repoFolder: "epr-regulator-service", workingDirectory: "src/EPR.RegulatorService.Frontend.Web")
    .WithUrl("https://localhost:7154/")
    .WithExplicitStart();

builder.Build().Run();