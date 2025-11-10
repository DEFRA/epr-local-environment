internal class Program
{
    public static void Main(string[] args)
    {
        var builder = DistributedApplication.CreateBuilder(args);

        builder
            .AddExecutable(name: "big-vibe-config-tool",
                command: "dotnet",
                workingDirectory: RepoPath("epr-tools-environment-variables"),
                args: "run")
            .WithUrl("http://localhost:5120/")
            .WithExplicitStart();

        builder.Build().Run();
    }

    /// <summary>
    /// This assumes that you have all the configured microservices checked out in the same folder as this project.
    /// Get the absolute path of a sibling folder (i.e. a microservice repo), optionally with a sub-path to add on.
    /// </summary>
    /// <param name="name">repo name</param>
    /// <param name="subfolder">(optional) subfolder to include in returned path</param>
    /// <returns>absolute path</returns>
    static string RepoPath(string name, string? subfolder = null)
    {
        var repoRoot = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "..")); // get back out of bin/debug etc all the way to parent directory

        var path = Path.Combine(repoRoot, name);
        if (!string.IsNullOrEmpty(subfolder))
        {
            return Path.Combine(path, subfolder);
        }

        return path;
    }
}
