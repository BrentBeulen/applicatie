#!/bin/bash
set -euo pipefail

mkdir -p tempdir
mkdir -p tempdir/src

cp SportStore.sln tempdir/.
cp -r src/* tempdir/src/.

cat > tempdir/Dockerfile << _EOF_

# asp.net SDK versie 5.0
FROM mcr.microsoft.com/dotnet/aspnet:5.0 As base
WORKDIR /app
EXPOSE 80
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:80

# Copy csproj and restore as distinct layers
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /
COPY ./SportStore.sln ./
COPY ./src/Domain/Domain.csproj ./src/Domain/
COPY ./src/Services/Services.csproj ./src/Services/
COPY ./src/Server/Server.csproj ./src/Server/
COPY ./src/Shared/Shared.csproj ./src/Shared/
COPY ./src/Client/Client.csproj ./src/Client/
COPY ./src/Persistence/Persistence.csproj ./src/Persistence/
RUN dotnet restore

# Copy everything else and build app
COPY ./ ./
COPY ./src/Domain/ ./src/Domain/
COPY ./src/Services/ ./src/Services/
COPY ./src/Server/ ./src/Server/
COPY ./src/Shared/ ./src/Shared/
COPY ./src/Client/ ./src/Client/
COPY ./src/Persistence/ ./src/Persistence/

WORKDIR "/src/Server"
RUN dotnet build "Server.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Server.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Server.dll"]

_EOF_

cd tempdir || exit
docker build -t sportstore .
docker run -t -d -p 80:80 --name SportStoreApp sportstore
docker ps -a 
