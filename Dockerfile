# https://github.com/dotnet/dotnet-docker/blob/main/samples/aspnetapp/Dockerfile

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG TARGETARCH
WORKDIR /source

COPY . .
RUN dotnet restore DevSecOpsPipelineSample.slnx -a $TARGETARCH \
    && dotnet publish src/DevSecOpsPipelineSample.Api/DevSecOpsPipelineSample.Api.csproj -c Release -a $TARGETARCH -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD [ "dotnet", "DevSecOpsPipelineSample.Api.dll", "--healthcheck" ]

USER $APP_UID
ENTRYPOINT ["dotnet", "DevSecOpsPipelineSample.Api.dll"]