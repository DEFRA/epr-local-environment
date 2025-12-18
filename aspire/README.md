# epr-aspire

Run Defra EPR microservices locally under .NET Aspire for debugging.

https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview

## Problem

EPR consists of .NET microservices that:
- Read configuration from user-secrets and environment variables
- Depend on each other over HTTP
- Need to be debuggable locally (Rider/VS), ruling out Docker-only solutions
- Sometimes need specific dependencies pointed at Azure dev/test instances

Current state:
- Basic Aspire AppHost launches services but does not configure them
- An internal tool copies config from Azure into user-secrets — it works but is coupled to Azure dev environments
- Changing which dependencies are local vs Azure requires editing config/secrets across multiple services
- The dependency graph is implicit, spread across env vars and user-secrets

## Why not canonical Aspire?

The standard Aspire approach adds project references from AppHost to each service and requires services to call `builder.AddServiceDefaults()`. This doesn't fit here:

- **Multi-repo**: each microservice lives in its own git repo — adding project references creates fragile cross-repo dependencies
- **Version mismatches**: Aspire package versions must align across all referenced projects; different repos evolve independently
- **Production code changes**: `AddServiceDefaults()` and Aspire NuGet packages would need adding to each service
- **Entanglement**: the Aspire solution becomes coupled to specific commits/branches of every service repo

Instead, we treat Aspire as an external orchestrator that launches and configures services without requiring them to know about Aspire.

## Design

Use Aspire as the wiring source of truth without modifying production service code.

### 1. Model all services in AppHost

- Local microservices: `AddProject(...)`
- Azure-hosted dependencies: `AddExternalService(...)` — makes them first-class Aspire resources
- All dependencies wired via `WithReference(...)` so Aspire knows the full graph

### 2. Per-dependency local/Azure switches

- Define Aspire parameters: `OrgApiMode`, `PaymentsApiMode`, etc. with values `local` or `azure`
- AppHost selects which resource (local project or external endpoint) to reference based on parameter value
- Parameters can be prompted in the dashboard and persisted to user-secrets

### 3. Dashboard as control panel

- Aspire dashboard prompts for parameter values on launch
- To switch a dependency: change the parameter value, restart affected services
- No need to edit env vars or user-secrets manually

### 4. Visible dependency graph

- Aspire's Graph/Resources view shows all services and their dependencies
- Both local and external services appear in the graph
- Topology is visible, not hidden in scattered config

## Microservice configuration
You can use the EPR Developer Big Tool to configure each project/service
https://dev.azure.com/defragovuk/RWD-CPR-EPR4P-ADO/_git/epr-tools-environment-variables

## Redis
Local Redis support is provided via Docker.

## SQL Databases
Local SQL Server instance of accountsdb. The database is accesible via Microsoft SQL Server Management Studio via 127.0.0.1 port 1433

Local SQL Server instance of prndb. The database is accesible via Microsoft SQL Server Management Studio via 127.0.0.1 port 1434 (note the port number)

## Azure ServiceBus
You can enable either a local ServiceBus or use a remote Azure ServiceBus.
### appsetting.json
  
 ```
 "ServiceBus": {
   /* queue name - required */
    "QueueName": "epr.queue",

    /* name used for local servicebus */
    "Name": "service-bus",

    /* A remote Azure ServiceBus will be used if a connectionstring is provided */
    "ConnectionString": "Endpoint=sb://#####;SharedAccessKeyName=#####;SharedAccessKey=#####"
  }

