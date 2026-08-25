FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Rrepw.Api.csproj ./
RUN dotnet restore --locked-mode

COPY . ./
RUN dotnet publish Rrepw.Api.csproj --no-restore --configuration Release --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app
RUN apk add --no-cache icu-libs
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
COPY --from=build /app/publish ./
USER $APP_UID
ENTRYPOINT ["dotnet", "Rrepw.Api.dll"]
