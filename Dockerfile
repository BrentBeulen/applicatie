
# asp.net SDK versie 5.0
FROM mcr.microsoft.com/dotnet/aspnet:5.0 As base
WORKDIR /app
EXPOSE 80
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:80

# Copy csproj and restore as distinct layers
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /
COPY ./Applicatie/SportStore.sln ./
COPY ./Applicatie/src/Domain/Domain.csproj ./src/Domain/
COPY ./Applicatie/src/Services/Services.csproj ./src/Services/
COPY ./Applicatie/src/Server/Server.csproj ./src/Server/
COPY ./Applicatie/src/Shared/Shared.csproj ./src/Shared/
COPY ./Applicatie/src/Client/Client.csproj ./src/Client/
COPY ./Applicatie/src/Persistence/Persistence.csproj ./src/Persistence/
RUN dotnet restore

# Copy everything else and build app
COPY ./Applicatie/ ./
COPY ./Applicatie/src/Domain/ ./src/Domain/
COPY ./Applicatie/src/Services/ ./src/Services/
COPY ./Applicatie/src/Server/ ./src/Server/
COPY ./Applicatie/src/Shared/ ./src/Shared/
COPY ./Applicatie/src/Client/ ./src/Client/
COPY ./Applicatie/src/Persistence/ ./src/Persistence/

WORKDIR "/src/Server"
RUN dotnet build "Server.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Server.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Server.dll"]
