FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY WasteObligations.Api.csproj ./
RUN dotnet restore --locked-mode

COPY . ./
RUN dotnet publish WasteObligations.Api.csproj --no-restore --configuration Release --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app
COPY --from=build /app/publish ./
USER $APP_UID
ENTRYPOINT ["dotnet", "WasteObligations.Api.dll"]
