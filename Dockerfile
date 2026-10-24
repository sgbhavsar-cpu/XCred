# Builds the React SPA and the ASP.NET Core API into a single runtime image, for local
# Docker-based testing (see docker-compose.yml). Mirrors scripts/publish.ps1's build flow.

FROM node:22-alpine AS web-build
WORKDIR /repo
# URL prefix the SPA is served under: '/' by default, '/xcred/' when it sits behind a reverse proxy
# at that path (see deploy/mobserver). Baked into the bundle by vite.config.ts.
ARG VITE_BASE_PATH=/
ENV VITE_BASE_PATH=$VITE_BASE_PATH
# VERSION is the single source of truth for the version shown on the login page / in filenames.
COPY VERSION VERSION
COPY src/XCred.Web/package.json src/XCred.Web/package-lock.json src/XCred.Web/
RUN npm ci --prefix src/XCred.Web
COPY src/XCred.Web src/XCred.Web
RUN mkdir -p src/XCred.Api && npm run build --prefix src/XCred.Web

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS api-build
WORKDIR /repo
COPY VERSION Directory.Build.props ./
COPY src/XCred.Core src/XCred.Core
COPY src/XCred.Infrastructure src/XCred.Infrastructure
COPY src/XCred.Api src/XCred.Api
COPY --from=web-build /repo/src/XCred.Api/wwwroot src/XCred.Api/wwwroot
RUN dotnet publish src/XCred.Api/XCred.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=api-build /app/publish .
# Data (SQLite + generated JWT secret) and logs live here; mount volumes on them to persist.
RUN mkdir -p /app/data /app/logs
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "XCred.Api.dll"]
