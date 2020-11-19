# Migration scripts

| Script                                    |    Release | Description                                   |
| ----------------------------------------- | ----------- | ----------------------------------------------|
| [20191101_self-hosted_sql_migration.ps1](./20191101_self-hosted_sql_migration.ps1)  | 2019-11-01 | Subtenant functionality added to login server |
| [20191220_self-hosted_sql_migrations.ps1](./20191220_self-hosted_sql_migrations.ps1) | 2019-12-20 | Additional email schema initialization |
| [20200306_self-hosted_sql_migrations.ps1](./20200306_self-hosted_sql_migrations.ps1) | 2020-03-06 | Add background checks ApiScope to login database |
| [20200417_self-hosted_sql_migrations.ps1](./20200417_self-hosted_sql_migrations.ps1) | 2020-04-17 | Subtenant schema changes |
| [20200807_self-hosted_sql_migrations.ps1](./20200807_self-hosted_sql_migrations.ps1) | 2020-08-07 | Add assessment webhook ApiScope to login database |
| [20201016_self-hosted_sql_migrations.ps1](./20201016_self-hosted_sql_migrations.ps1) | 2020-10-16 | Add Indeed webhook ApiScope to login database |
| [20201120_self-hosted_sql_migrations.ps1](./20201120_self-hosted_sql_migrations.ps1) | 2020-11-20 | Add background checks ApiScopes to login database |

To avoid settings and resetting execution policy, these scripts can be invoked in the following manner.  Note that if you have placed your service configuration paths follow a convention other than `C:\ProgramData\TempWorks\config\{service-name}`, you will need to manually supply a path to the service configuration folder.

```
> powershell.exe -ExecutionPolicy Bypass -File .\self-hosted_sql_migrations.ps1 
```
