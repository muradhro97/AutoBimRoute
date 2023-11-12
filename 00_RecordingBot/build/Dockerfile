FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
ARG CallSignalingPort=9441
ARG CallSignalingPort2=9442
ARG InstanceInternalPort=8445

COPY /src /src

WORKDIR /src
RUN nuget restore

WORKDIR /src/RecordingBot.Console
RUN msbuild /p:Configuration=Release /p:OutputPath=C:\app /p:Platform=x64

FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-Command"]

# Install Chocolatey version 1.4
RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) -version 1.4

RUN choco install openssl.light -y

# .NET Framework installation might be redundant if it's already in your base image
# ADD https://aka.ms/vs/16/release/vc_redist.x64.exe /bot/VC_redist.x64.exe

COPY /scripts/entrypoint.cmd /bot
COPY /scripts/halt_termination.ps1 /bot
COPY --from=build /app /bot

WORKDIR /bot

EXPOSE $InstanceInternalPort
EXPOSE $CallSignalingPort
EXPOSE $CallSignalingPort2

ENTRYPOINT [ "entrypoint.cmd" ]
