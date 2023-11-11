FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build

ARG CallSignalingPort=9441
ARG CallSignalingPort2=9442
ARG InstanceInternalPort=8445

COPY /src /src

WORKDIR /src
RUN nuget restore

WORKDIR /src/RecordingBot.Console
RUN msbuild /p:Configuration=Release /p:OutputPath=C:\app /p:Platform=x64


FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2016

LABEL org.opencontainers.image.url="https://chocolatey.org/"
LABEL org.opencontainers.image.documentation="https://docs.chocolatey.org/"
LABEL org.opencontainers.image.source="https://github.com/chocolatey/choco"
LABEL org.opencontainers.image.vendor="Chocolatey Software, Inc"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="Chocolatey"
LABEL org.opencontainers.image.description="Chocolatey Client running on .NET"
LABEL org.opencontainers.image.authors="https://chocolatey.org/support"
LABEL org.opencontainers.image.base.name="mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2016"

COPY ./code_drop/Packages/Chocolatey C:/choco-nupkg
COPY ./docker/Install-ChocolateyInContainer.ps1 C:/choco-nupkg/Install-ChocolateyInContainer.ps1
COPY ./src/chocolatey.resources/tools/ C:/choco-nupkg/tools/

RUN PowerShell.exe "C:\choco-nupkg\Install-ChocolateyInContainer.ps1"

FROM mcr.microsoft.com/windows:1809
SHELL ["powershell", "-Command"]

ADD https://aka.ms/vs/16/release/vc_redist.x64.exe /bot/VC_redist.x64.exe

COPY /scripts/entrypoint.cmd /bot
COPY /scripts/halt_termination.ps1 /bot
COPY --from=build /app /bot

WORKDIR /bot

#RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
#    [System.Net.ServicePointManager]::SecurityProtocol = \
#        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
#        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

RUN choco install openssl.light -y

EXPOSE $InstanceInternalPort
EXPOSE $CallSignalingPort
EXPOSE $CallSignalingPort2

ENTRYPOINT [ "entrypoint.cmd" ]
