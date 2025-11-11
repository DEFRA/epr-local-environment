namespace EPR.AspireAppHost;

internal static class ResourceBuilderExtensions
{
    public static IResourceBuilder<ExecutableResource> AddMicroservice(
        this IDistributedApplicationBuilder builder, string name, string repoFolder, string? workingDirectory = null)
    {
        return builder.AddExecutable(name: name,
                command: "dotnet",
                workingDirectory: PathFinder.RepoPath(repoFolder, workingDirectory),
                args: "run")
            .WithExplicitStart();
    }
}
