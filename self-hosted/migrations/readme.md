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
| [20210326_API_Readiness_Check.ps1](./20210326_API_Readiness_Check.ps1)               | 2021-03-26 | Session context readiness check                   |
| [20210507_self-hosted_sql_migrations.ps1](./20210507_self-hosted_sql_migrations.ps1) | 2021-05-07 | Add Legal and Payroll ApiScopes to login database |
| [20210618_self-hosted_sql_migrations.ps1](./20210618_self-hosted_sql_migrations.ps1) | 2021-06-18 | Add ApiScopes to login database                   |
| [20211022_self-hosted_sql_migrations.ps1](./20211022_self-hosted_sql_migrations.ps1) | 2021-10-22 | Update API rebus database                         |
| [20211203_self-hosted_sql_migrations.ps1](./20211203_self-hosted_sql_migrations.ps1) | 2021-12-03 | Add SSO schema to login server                    |
| [20211217_self-hosted_sql_migrations.ps1](./20211217_self-hosted_sql_migrations.ps1) | 2021-12-17 | SSO changes                                       |
| [20211231_self-hosted_sql_migrations.ps1](./20211231_self-hosted_sql_migrations.ps1) | 2021-12-31 | Add SSO base configuration                        |
| [20220311_self-hosted_sql_migrations.ps1](./20220311_self-hosted_sql_migrations.ps1) | 2022-03-11 | Additional SSO changes                            |
| [20220325_self-hosted_sql_migrations.ps1](./20220325_self-hosted_sql_migrations.ps1) | 2022-03-25 | Additional SSO changes                            |
| [20220617_self-hosted_sql_migrations.ps1](./20220617_self-hosted_sql_migrations.ps1) | 2022-06-17 | Enforce tenant naming constraints                 |
| [20221021_self-hosted_sql_migrations.ps1](./20221021_self-hosted_sql_migrations.ps1) | 2022-10-21 | Email schema change                               |
| [20230113_self-hosted_sql_migrations.ps1](./20230113_self-hosted_sql_migrations.ps1) | 2022-01-13 | Additional identity provider schema               |
| [20230210_self-hosted_sql_migrations.ps1](./20230210_self-hosted_sql_migrations.ps1) | 2023-02-10 | Email Server product type                         |
| [20230421_self-hosted_sql_migrations.ps1](./20230421_self-hosted_sql_migrations.ps1) | 2023-04-21 | Email Server schema change                        |
| [20230825_self-hosted_sql_migrations.ps1](./20230825_self-hosted_sql_migrations.ps1) | 2023-08-25 | Duende login server schema changes                |
| [20230908_self-hosted_sql_migrations.ps1](./20230908_self-hosted_sql_migrations.ps1) | 2023-09-03 | Rate-limiting changes                             |
| [20231006_self-hosted_sql_migrations.ps1](./20231006_self-hosted_sql_migrations.ps1) | 2023-10-06 | Duende login server schema changes                |
| [20231229_self-hosted_sql_migrations.ps1](./20231229_self-hosted_sql_migrations.ps1) | 2023-12-29 | Login server schema changes                       |
| [20240322_self-hosted_sql_migrations.ps1](./20240322_self-hosted_sql_migrations.ps1) | 2024-03-22 | Login server client changes                       |
| [20240503_self-hosted_sql_migrations.ps1](./20240503_self-hosted_sql_migrations.ps1) | 2024-05-03 | Default client rate limits                        |
| [20241122_self-hosted_sql_migrations.ps1](./20241122_self-hosted_sql_migrations.ps1) | 2024-11-22 | New tenant identifiers and Dotnet 8 upgrade       |

To avoid settings and resetting execution policy, these scripts can be invoked in the following manner.  Note that if you have placed your service configuration paths follow a convention other than `C:\ProgramData\TempWorks\config\{service-name}`, you will need to manually supply a path to the service configuration folder.

```
> powershell.exe -ExecutionPolicy Bypass -File .\self-hosted_sql_migrations.ps1 
```
