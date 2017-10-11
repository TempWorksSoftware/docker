
* Create persisted paths for container configs and logs, example:
```
    PS> md c:/ProgramData/TempWorks/auth/config
    PS> md c:/ProgramData/TempWorks/auth/logs
    PS> md c:/ProgramData/TempWorks/api-server/config
    PS> md c:/ProgramData/TempWorks/api-server/logs
```    

* Install and update config files


* Create certificates for Auth server and External Services


* Docker-compose example:
```
    PS> $env:AUTH_VERSION = "XXXXX"
    PS> $env:API3_VERSION = "XXXXX"
    PS> docker-compose -f docker-compose.yml -p "TwAPI V3" up -d --build
```   



