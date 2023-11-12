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

# Stage 1: Install .NET Framework
FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS dotnet-installer

SHELL ["powershell", "-Command"]

# Adding the .NET Framework installer
ADD https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe /bot/ndp48-x86-x64-allos-enu.exe

# Running the .NET Framework installer
RUN /bot/ndp48-x86-x64-allos-enu.exe /install /quiet /norestart

# Stage 2: Rest of the setup with Chocolatey
FROM mcr.microsoft.com/windows/servercore:ltsc2019

SHELL ["powershell", "-Command"]

# Set the working directory
WORKDIR /bot

# Copy necessary scripts or files
COPY /scripts/entrypoint.cmd /bot
COPY /scripts/halt_termination.ps1 /bot

# Install Chocolatey and other dependencies
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = \
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Copy required files from the dotnet-installer stage
COPY --from=dotnet-installer /bot /bot

# Install additional dependencies using Chocolatey or other means
RUN choco install openssl.light -y

# Expose ports and set entrypoint
EXPOSE $InstanceInternalPort
EXPOSE $CallSignalingPort
EXPOSE $CallSignalingPort2
ENTRYPOINT [ "entrypoint.cmd" ]