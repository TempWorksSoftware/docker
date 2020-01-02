| login-server\appsettings.json                       | Description                                                                                 |
|-----------------------------------------------------|---------------------------------------------------------------------------------------------|
| {                                                   |                                                                                             |
|   {                                                 |                                                                                             |
|   "AppSettings": {                                  |                                                                                             |
|     "SingleTenantName": "?????",                    | Tenant name to use in single tenant mode (must match the `Name` column in `Tenants` table). |
|     "MultiTenantEnabled": "false",                  | Enable multi-tenant mode.                                                                   |
|     "UpgradeInsecureRequest": "false"               | Apply `upgrade-insecure-requests` content security policy.                                  |
|   },                                                |                                                                                             |
|   "LdapServerOptions": {                            |                                                                                             |
|     "LdapServers": [                                | List of LDAP (DC) servers to use for authentication.                                        |
|       {                                             |                                                                                             |
|         "Host": "?????",                            |                                                                                             |
|         "Port": "389",                              |                                                                                             |
|         "AdminUsername": "?????",                   |                                                                                             |
|         "AdminPassword": "?????"                    |                                                                                             |
|       }                                             |                                                                                             |
|     ]                                               |                                                                                             |
|   },                                                |                                                                                             |
|   "Serilog": {                                      | Logging settings for Serilog logging framework (see: <https://serilog.net>).                |
|     "MinimumLevel": {                               |                                                                                             |
|       "Default": "Information",                     |                                                                                             |
|       "Override": {                                 |                                                                                             |
|         "Microsoft": "Warning",                     |                                                                                             |
|         "Microsoft.EntityFrameworkCore": "Warning", |                                                                                             |
|         "System": "Warning"                         |                                                                                             |
|       }                                             |                                                                                             |
|     }                                               |                                                                                             |
|   }                                                 |                                                                                             |
| }                                                   |                                                                                             |



| login-server\appsettings.production.json                                                  | Description                                                                                    |
|-------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| {                                                                                         |                                                                                                |
|   "ConnectionStrings": {                                                                  |                                                                                                |
|     "TwLoginServerDatabase": "Server=?????;Database=?????;User Id=?????;Password=?????;", | Login server database SQL connection string.                                                   |
|     "redis": "redis"                                                                      | Redis connection string - usually just the service name (ex: "redis") in a single-host system. |
|   },                                                                                      |                                                                                                |
|   "AppSettings": {                                                                        |                                                                                                |
|     "UpgradeInsecureRequest": "false",                                                    | Apply `upgrade-insecure-requests` content security policy.                                     |
|     "SigningCertificateFilename": "?????",                                                | Filename of PFX file in `certs/` folder.                                                       |
|     "SigningCertificatePassword": "?????"                                                 | Password used when generating PFX file.                                                        |
|   },                                                                                      |                                                                                                |
|   "Serilog": {                                                                            | Logging settings for Serilog logging framework (see: <https://serilog.net>).                   |
|     "MinimumLevel": {                                                                     |                                                                                                |
|       "Default": "Information"                                                            |                                                                                                |
|     }                                                                                     |                                                                                                |
|   }                                                                                       |                                                                                                |
| }                                                                                         |                                                                                                |
