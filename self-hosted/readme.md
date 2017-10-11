
* Create persisted paths for container configs and logs, example:
```
    PS> md c:/ProgramData/TempWorks/auth/config
    PS> md c:/ProgramData/TempWorks/auth/logs
    PS> md c:/ProgramData/TempWorks/api-server/config
    PS> md c:/ProgramData/TempWorks/api-server/logs
```    

* Install and update config files

#### Create certificates
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

##### Create certificates for TW Auth service
```
PS> openssl req -x509 -newkey rsa:4096 -days 10950 -nodes -subj "/C=US/O=YourOrg/CN=YourFqdn" -keyout key.pem -out cert.pem -config .\openssl.cfg
PS> openssl pkcs12 -name "TempWorks Auth Signing" -export -in cert.pem -inkey key.pem -out auth-signing.pfx -password pass:YourPassword
```
Place pfx file in your `auth` `%config_root%\certs` folder.

Update `auth` appsettings.json `SigningCertificateFilename` and `SigningCertificatePassword` keys to their proper values

##### Create certificates for External Services credential store
```
PS> openssl req -x509 -newkey rsa:4096 -days 10950 -nodes -subj "/C=US/O=YourOrg/CN=YourFqdn" -keyout key.pem -out cert.pem -config .\openssl.cfg
```
Place cert.pem and key.pem in your `api-server` `%config_root%\certs\ExternalServices` folder

###### !!! TIP: Keep your pem & pfx files, and password in a secure place in case you need them in the future.

#### Docker-compose example:
```
    PS> $env:AUTH_VERSION = "XXXXX"
    PS> $env:API3_VERSION = "XXXXX"
    PS> docker-compose -f docker-compose.yml -p "TwAPI V3" up -d --build
```   



