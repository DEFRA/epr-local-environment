# epr-aspire

Experimental attempt to run Defra EPR repos locally under dotnet aspire

https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview

## Micorservice configuration
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

