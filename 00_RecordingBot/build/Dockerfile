# Build Stage
#FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
#
#ARG CallSignalingPort=9441
#ARG CallSignalingPort2=9442
#ARG InstanceInternalPort=8445
#
#COPY /src /src
#
#WORKDIR /src
#RUN nuget restore
#
#WORKDIR /src/RecordingBot.Console
#RUN msbuild /p:Configuration=Release /p:OutputPath=C:\app /p:Platform=x64

# Intermediate Stage
FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS intermediate

SHELL ["powershell", "-Command"]

# Adding the redistributable file
ADD https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe /bot/ndp48-x86-x64-allos-enu.exe

# Running the redistributable file
RUN /bot/ndp48-x86-x64-allos-enu.exe /install /quiet /norestart || IF %ERRORLEVEL% EQU 3010 (shutdown /r /t 0)

# Final Stage
FROM intermediate

COPY /scripts/entrypoint.cmd /bot
COPY /scripts/halt_termination.ps1 /bot

WORKDIR /bot

# Move the problematic installation here to a separate stage
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = \
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) \

COPY --from=build /app /bot

RUN choco install openssl.light -y

EXPOSE $InstanceInternalPort
EXPOSE $CallSignalingPort
EXPOSE $CallSignalingPort2

ENTRYPOINT [ "entrypoint.cmd" ]
