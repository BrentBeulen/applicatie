#!/bin/bash
# BUILD JOB COMMANDO
# bash ./jenkinsApplicatie.sh

set -euo pipefail

mkdir -p tempdir
mkdir -p tempdir/src
mkdir -p /home/vagrant/https

cp SportStore.sln tempdir/.
cp -r src/* tempdir/src/.

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /home/vagrant/https/https.key -out /home/vagrant/https/https.crt -subj "/C=BE/ST=Vlaams-Brabant/L=VHalle/O=DevOps/OU=Operations/CN=localhost"
openssl pkcs12 -export -out /home/vagrant/https/https.pfx -inkey /home/vagrant/https/https.key -in /home/vagrant/https/https.crt -password pass:password

cat > tempdir/Dockerfile << _EOF_

# asp.net SDK versie 5.0
FROM mcr.microsoft.com/dotnet/aspnet:5.0 As base
WORKDIR /app
EXPOSE 80
EXPOSE 443
ENV ASPNETCORE_URLS="https://+;http://+"
ENV ASPNETCORE_HTTPS_PORT=443
ENV ASPNETCORE_Kestrel__Certificates__Default__Password="password"
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=/https/https.pfx

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
