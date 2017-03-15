FROM microsoft/windowsservercore
LABEL vendor="TempWorks Software, paul@tempworks.com"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Workaround: having trouble downloading redis dist from the web, using a local zip file.
WORKDIR /temp
COPY ./Redis-x64-3.2.100.zip .

# Download and Install Redis from zip file.
RUN Expand-Archive Redis-x64-3.2.100.zip -dest 'C:\\Redis\\' ; \
    Remove-Item Redis-x64-3.2.100.zip -Force

RUN setx PATH '%PATH%;C:\\Redis\\'
WORKDIR /redis

# Change to unprotected mode and open the daemon to listen on all interfaces.
RUN Get-Content redis.windows.conf | Where { $_ -notmatch 'bind 127.0.0.1' } | Set-Content redis.openport.conf ; \
  Get-Content redis.openport.conf | Where { $_ -notmatch 'protected-mode yes' } | Set-Content redis.unprotected.conf ; \
  Add-Content redis.unprotected.conf 'protected-mode no' ; \
  Add-Content redis.unprotected.conf 'bind 0.0.0.0' ; \
  Get-Content redis.unprotected.conf

EXPOSE 6379

# Define our command to be run when launching the container
CMD .\\redis-server.exe .\\redis.unprotected.conf --port 6379 ; \
    Write-Host Redis Started... ; \
    while ($true) { Start-Sleep -Seconds 3600 }
    
# Docker healthcheck command
HEALTHCHECK CMD powershell -command \ 
    try { if((redis-cli.exe ping) -eq 'PONG') {return 0} else {return 1}; } catch {return 1}
    
