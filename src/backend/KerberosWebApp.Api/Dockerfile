FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["src/backend/KerberosWebApp.Api/KerberosWebApp.Api.csproj", "src/backend/KerberosWebApp.Api/"]
RUN dotnet restore "src/backend/KerberosWebApp.Api/KerberosWebApp.Api.csproj"

COPY . .
WORKDIR /src/src/backend/KerberosWebApp.Api
RUN dotnet publish "KerberosWebApp.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        krb5-user \
        libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_URLS=http://+:8080 \
    KRB5_CONFIG=/etc/krb5.conf \
    KRB5_KTNAME=/etc/security/keytabs/app.keytab

EXPOSE 8080

COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "KerberosWebApp.Api.dll"]
