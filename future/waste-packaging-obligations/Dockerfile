FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY WastePackagingObligations.Api.csproj ./
RUN dotnet restore --locked-mode

COPY . ./
RUN dotnet publish WastePackagingObligations.Api.csproj --no-restore --configuration Release --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app
COPY --from=build /app/publish ./
USER $APP_UID
ENTRYPOINT ["dotnet", "WastePackagingObligations.Api.dll"]
