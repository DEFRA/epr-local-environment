using EPR.AspireAppHost;

var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddMicroservice(name: "big-vibe-config-tool", repoFolder: "epr-tools-environment-variables")
    .WithUrl("http://localhost:5120/")
    .WithExplicitStart();

builder.Build().Run();