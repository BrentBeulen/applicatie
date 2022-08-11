#!/bin/bash
# bash ./jenkinsApplicatie.sh

#    node {
#        stage('Preparation') {
#            catchError(buildResult: 'SUCCESS') {
#                sh 'docker stop SportStoreApp'
#                sh 'docker rm SportStoreApp'
#            }
#        }
#        stage('Build') {
#            build 'BuildSampleApp'
#        }
#    }

set -euo pipefail

mkdir -p tempdir
mkdir -p tempdir/src
mkdir -p /var/jenkins_home/https

cp SportStore.sln tempdir/.
cp -r src/* tempdir/src/.

cat > /var/jenkins_home/https/https.config << _EOF_

[ req ]
default_bits       = 2048
default_md         = sha256
default_keyfile    = key.pem
prompt             = no
encrypt_key        = no

distinguished_name = req_distinguished_name
req_extensions     = v3_req
x509_extensions    = v3_req

[ req_distinguished_name ]
commonName             = "localhost"

[ v3_req ]
subjectAltName      = DNS:localhost
basicConstraints    = critical, CA:false
keyUsage            = critical, keyEncipherment
extendedKeyUsage    = critical, 1.3.6.1.5.5.7.3.1

_EOF_

openssl req -config /var/jenkins_home/https/https.config -new -out /var/jenkins_home/https/csr.pem
openssl x509 -req -days 365 -extfile /var/jenkins_home/https/https.config -extensions v3_req -in /var/jenkins_home/https/csr.pem -signkey key.pem -out /var/jenkins_home/https/https.crt
openssl pkcs12 -export -out /var/jenkins_home/https/https.pfx -inkey key.pem -in /var/jenkins_home/https/https.crt -password pass:password

cat > tempdir/Dockerfile << _EOF_

# asp.net SDK versie 5.0
FROM mcr.microsoft.com/dotnet/aspnet:5.0 As base
WORKDIR /app
EXPOSE 80;443
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
docker run -t -p 80:80 -p 443:443 --network vagrant_default -v /var/jenkins_home/https/:/https/ --name SportStoreApp sportstore
docker ps -a 
