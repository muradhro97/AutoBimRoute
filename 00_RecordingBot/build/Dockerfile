# Build Stage
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build

ARG CallSignalingPort=9441
ARG CallSignalingPort2=9442
ARG InstanceInternalPort=8445

COPY /src /src

WORKDIR /src
RUN nuget restore

WORKDIR /src/RecordingBot.Console
RUN msbuild /p:Configuration=Release /p:OutputPath=C:\app /p:Platform=x64

# Intermediate Stage
FROM mcr.microsoft.com/windows:1809 AS intermediate

SHELL ["powershell", "-Command"]

ADD https://aka.ms/vs/16/release/vc_redist.x64.exe /bot/VC_redist.x64.exe

COPY /scripts/entrypoint.cmd /bot
COPY /scripts/halt_termination.ps1 /bot

WORKDIR /bot

# Move the problematic installation here to a separate stage
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = \
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Final Stage
FROM intermediate

COPY --from=build /app /bot

RUN choco install openssl.light -y

EXPOSE $InstanceInternalPort
EXPOSE $CallSignalingPort
EXPOSE $CallSignalingPort2

ENTRYPOINT [ "entrypoint.cmd" ]
