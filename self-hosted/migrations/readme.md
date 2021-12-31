# Migration scripts

| Script                                                                               | Release    | Description                                       |
|--------------------------------------------------------------------------------------|------------|---------------------------------------------------|
| [20191101_self-hosted_sql_migration.ps1](./20191101_self-hosted_sql_migration.ps1)   | 2019-11-01 | Subtenant functionality added to login server     |
| [20191220_self-hosted_sql_migrations.ps1](./20191220_self-hosted_sql_migrations.ps1) | 2019-12-20 | Additional email schema initialization            |
| [20200306_self-hosted_sql_migrations.ps1](./20200306_self-hosted_sql_migrations.ps1) | 2020-03-06 | Add background checks ApiScope to login database  |
| [20200417_self-hosted_sql_migrations.ps1](./20200417_self-hosted_sql_migrations.ps1) | 2020-04-17 | Subtenant schema changes                          |
| [20200807_self-hosted_sql_migrations.ps1](./20200807_self-hosted_sql_migrations.ps1) | 2020-08-07 | Add assessment webhook ApiScope to login database |
| [20201016_self-hosted_sql_migrations.ps1](./20201016_self-hosted_sql_migrations.ps1) | 2020-10-16 | Add Indeed webhook ApiScope to login database     |
| [20201120_self-hosted_sql_migrations.ps1](./20201120_self-hosted_sql_migrations.ps1) | 2020-11-20 | Add Background checks ApiScopes to login database |
| [20210115_self-hosted_sql_migrations.ps1](./20210115_self-hosted_sql_migrations.ps1) | 2021-01-15 | Add Email and Sovren ApiScopes to login database  |
| [20210326_API_Readiness_Check.ps1](./20210326_API_Readiness_Check.ps1)              | 2021-03-26 | Session context readiness check                   |
| [20210507_self-hosted_sql_migrations.ps1](./20210507_self-hosted_sql_migrations.ps1) | 2021-05-07 | Add Legal and Payroll ApiScopes to login database |
| [20210618_self-hosted_sql_migrations.ps1](./20210618_self-hosted_sql_migrations.ps1) | 2021-06-18 | Add ApiScopes to login database                   |
| [20211022_self-hosted_sql_migrations.ps1](./20211022_self-hosted_sql_migrations.ps1) | 2021-10-22 | Update API rebus database                         |
| [20211203_self-hosted_sql_migrations.ps1](./20211203_self-hosted_sql_migrations.ps1) | 2021-12-03 | Add SSO schema to login server                    |
| [20211217_self-hosted_sql_migrations.ps1](./20211217_self-hosted_sql_migrations.ps1) | 2021-12-17 | SSO changes                                       |
| [20211231_self-hosted_sql_migrations.ps1](./20211231_self-hosted_sql_migrations.ps1) | 2021-12-31 | Add SSO base configuration                        |



To avoid settings and resetting execution policy, these scripts can be invoked in the following manner.  Note that if you have placed your service configuration paths follow a convention other than `C:\ProgramData\TempWorks\config\{service-name}`, you will need to manually supply a path to the service configuration folder.

```
> powershell.exe -ExecutionPolicy Bypass -File .\self-hosted_sql_migrations.ps1 
```
