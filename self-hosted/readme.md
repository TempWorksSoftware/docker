## Things you need before starting tasks in this document.
* Prepared Windows Server 1709 installation
Run Powershell command ```(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId```, result should be ```1709```

* Functioning Windows Docker environment.
Run from Powershell ```docker --version```, you should see ```Docker version 17.06.2-ee-5``` or later.
Run from Powershell ```docker ps```, it should return a non-error.

* Docker Hub account with access to the TempWorks private repository: https://hub.docker.com/u/tempworks

## Create directories for persisted data on Docker host

* Create persisted paths for container configs and logs, example:
```
    PS> md c:/ProgramData/TempWorks/auth/config
    PS> md c:/ProgramData/TempWorks/auth/logs
    PS> md c:/ProgramData/TempWorks/api-server/config
    PS> md c:/ProgramData/TempWorks/api-server/logs
```    

* Install and update config files

## Install and Configure OpenSSL
```text
OpenSSL note:

1. Download and install OpenSSL Light for Windows at: http://slproweb.com/products/Win32OpenSSL.html
2. Modify openssl.cnf
   Look for the section starting with “req_attributes”, remove “unstructuredName”, and save the file.
   
      Original:
        [ req_attributes ]
        challengePassword = A challenge password
        challengePassword_min = 4
        challengePassword_max = 20
        unstructuredName = An optional company name

      Modified:
        [ req_attributes ]
        challengePassword = A challenge password
        challengePassword_min = 4
        challengePassword_max = 20
```

## Create certificates for TW Auth service
```
PS> openssl req -x509 -newkey rsa:4096 -days 10950 -nodes -subj "/C=US/O=YourOrg/CN=YourFqdn" -keyout key.pem -out cert.pem -config .\openssl.cfg
PS> openssl pkcs12 -name "TempWorks Auth Signing" -export -in cert.pem -inkey key.pem -out auth-signing.pfx -password pass:YourPassword
```
Place pfx file in your `auth` `%config_root%\certs` folder.

Update `auth` appsettings.json `SigningCertificateFilename` and `SigningCertificatePassword` keys to their proper values

## Create certificates for External Services credential store
```
PS> openssl req -x509 -newkey rsa:4096 -days 10950 -nodes -subj "/C=US/O=YourOrg/CN=YourFqdn" -keyout key.pem -out cert.pem -config .\openssl.cfg
```
Place cert.pem and key.pem in your `api-server` `%config_root%\certs\ExternalServices` folder

##### !!! TIP: Keep your pem & pfx files, and password in a secure place in case you need them in the future.

## 

## Run docker-compose to install TempWorks API stack:
In the same directory as your docker-compose yml file run the following commands. Replace placeholders with the versions of the Auth and Api3 services you wish to install. Use ```latest``` if want to use the latest versions.

```
    PS> $env:AUTH_VERSION = "XXXXX";
    PS> $env:API3_VERSION = "XXXXX";
    PS> docker-compose -f docker-compose.yml -p "twapi" up -d --build;
```   

An example docker-compose yml file can be found here:  
https://github.com/tempworks/docker/blob/master/self-hosted/docker-compose.yml  
This example yml file installs all services needed by TW API, it is for demostration purposes only.


