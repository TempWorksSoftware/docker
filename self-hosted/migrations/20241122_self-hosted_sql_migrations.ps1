param (
    # Path to the login-server configuration directory
    [ValidateScript(
         {
             if (-Not (Test-Path -Path $_)) {
                 throw "Login Server service config directory ($_) not found!"
             }
             return $true
         })]
    [string]
    $loginServer = $(
        if (-Not (Test-Path -Path "C:\ProgramData\TempWorks\config\login-server")) {
            throw "Login Server service config directory (C:\ProgramData\TempWorks\config\login-server) not found!"
        }
        return "C:\ProgramData\TempWorks\config\login-server"
    )
)

$appsettingsPath = $loginServer+'\appsettings.production.json'

$loginServerConnectionString = (Get-Content ($appsettingsPath) -ErrorAction stop | Out-String |ConvertFrom-Json).ConnectionStrings.TwLoginServerDatabase

function Execute-SqlQuery ($connectionString, $query) {
    $connection = New-Object System.Data.SqlClient.SQLConnection "$connectionString"
     $connection.ConnectionString=$connectionString
    $connection.Open()
    $cmd = New-Object system.Data.SqlClient.SqlCommand($query, $connection)
    $ds = New-Object system.Data.DataSet
    $da = New-Object system.Data.SqlClient.SqlDataAdapter $cmd
    [void]$da.fill($ds)
    $connection.Close()
    return $ds.Tables
}

function Apply-SqlMigration ($connectionString, $description, $testQuery, $updateQuery) {
    $testResult = Execute-SqlQuery -ConnectionString $connectionString -Query $testQuery
    
    if ($testResult.Table.Column1) {
        Write-Host "'$description' already applied." -foregroundcolor green
    } else {
        Write-Host "Applying '$description'..." -NoNewline

        try {                        
            $updateQuery | ForEach-Object { Execute-SqlQuery $connectionString $_ }
            Write-Host " SUCCEEDED." -foregroundcolor green
        } catch [Exception] {
            Write-Host " FAILED." -foregroundcolor red
            Write-Error -Message "Could not apply SQL migration"
            Write-Error -Exception $_.Exception
            Write-Host "Consider applying this SQL migration manually:"
            Write-Host "----------------------------------------"
            write-host $updateQuery
            Write-Host "----------------------------------------"
            Write-Error -Message "Could not apply SQL migration"
            Write-Error -Exception $_.Exception
        }
    }
}


$loginServerUpdates = @(
    @{
        Description = "Add global GUID to Tenants. [WI 107316]";
        Test = @'
            SELECT 1 FROM sys.columns 
            WHERE Name = N'TenantGuid'
            AND Object_ID = Object_ID(N'dbo.Tenants')
'@;
        Migrate = @"
        ALTER TABLE dbo.Tenants ADD TenantGuid UNIQUEIDENTIFIER NOT NULL DEFAULT newid() WITH VALUES
	    CREATE UNIQUE NONCLUSTERED INDEX IX_TenantGuid ON dbo.Tenants(TenantGuid) 
	    WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
"@;
	},
    @{
        Description = "Add global GUID to SubTenants. [WI 107316]";
        Test = @'
            SELECT 1 FROM sys.columns 
            WHERE Name = N'SubTenantGuid'
            AND Object_ID = Object_ID(N'dbo.SubTenants')
'@;
        Migrate = @"
        ALTER TABLE dbo.SubTenants ADD SubTenantGuid UNIQUEIDENTIFIER NOT NULL DEFAULT newid() WITH VALUES
	    CREATE UNIQUE NONCLUSTERED INDEX IX_SubTenantGuid ON dbo.SubTenants(SubTenantGuid) 
	    WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
"@;
    },
        @{
        Description = "Schema updates for Login Server .Net 8 upgrade. [WI 103114]";
        Test = @"
            IF OBJECT_ID('dbo.PushedAuthorizationRequests', 'U') <> 0 SELECT  1;
"@;
        Migrate = 
        @"
-----------------------------------
-- IDENTITY SERVER MIGRATION SCRIPT FOR DOTNET 8 UPGRADE
-----------------------------------
SET NUMERIC_ROUNDABORT OFF;

SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;

SET XACT_ABORT ON;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;


-----------------------------------
-- dbo.ApiResources
-----------------------------------
PRINT 'Altering dbo.ApiResources';

ALTER TABLE [dbo].[ApiResources]
ADD CONSTRAINT [DF_ApiResources_NonEditable] DEFAULT (CONVERT(BIT, (0))) FOR [NonEditable];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[ApiResources]
SET     [NonEditable] = 0
WHERE   [NonEditable] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiResources]
ALTER COLUMN [NonEditable] BIT NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiResources]
ADD CONSTRAINT [DF_ApiResources_Created] DEFAULT (SYSDATETIME()) FOR [Created];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[ApiResources]
SET     [Created] = '0001-01-01T00:00:00.0000000'
WHERE   [Created] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiResources]
ALTER COLUMN [Created] DATETIME2 NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ApiScopeClaims
-----------------------------------
PRINT 'Altering dbo.ApiScopeClaims';

DROP INDEX [IX_ApiScopeClaims_ApiScopeId]
ON [dbo].[ApiScopeClaims];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiScopeClaims]
DROP CONSTRAINT [FK_ApiScopeClaims_ApiScopes_ApiScopeId];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiScopeClaims]
DROP CONSTRAINT [FK_ApiScopeClaims_ApiScopes_ScopeId];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiScopeClaims]
ADD CONSTRAINT [FK_ApiScopeClaims_ApiScopes_ScopeId] FOREIGN KEY
                                                     (
                                                         [ScopeId]
                                                     ) REFERENCES [dbo].[ApiScopes]
                                                     (
                                                         [Id]
                                                     ) ON DELETE CASCADE;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ApiScopes
-----------------------------------
PRINT 'Altering dbo.ApiScopes';

DROP INDEX [IX_ApiScopes_ApiResourceId]
ON [dbo].[ApiScopes];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiScopes]
DROP CONSTRAINT [FK_ApiScopes_ApiResources_ApiResourceId];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ApiScopes]
DROP COLUMN [ApiResourceId];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientClaims
-----------------------------------
PRINT 'Altering dbo.ClientClaims';

DROP INDEX [IX_ClientClaims_ClientId]
ON [dbo].[ClientClaims];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientCorsOrigins
-----------------------------------
PRINT 'Altering dbo.ClientCorsOrigins';

DROP INDEX [IX_ClientCorsOrigins_ClientId]
ON [dbo].[ClientCorsOrigins];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientGrantTypes
-----------------------------------
PRINT 'Altering dbo.ClientGrantTypes';

DROP INDEX [IX_ClientGrantTypes_ClientId]
ON [dbo].[ClientGrantTypes];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientIdPRestrictions
-----------------------------------
PRINT 'Altering dbo.ClientIdPRestrictions';

DROP INDEX [IX_ClientIdPRestrictions_ClientId]
ON [dbo].[ClientIdPRestrictions];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientPostLogoutRedirectUris
-----------------------------------
PRINT 'Altering dbo.ClientPostLogoutRedirectUris';

DROP INDEX [IX_ClientPostLogoutRedirectUris_ClientId]
ON [dbo].[ClientPostLogoutRedirectUris];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientProperties
-----------------------------------
PRINT 'Altering dbo.ClientProperties';

DROP INDEX [IX_ClientProperties_ClientId]
ON [dbo].[ClientProperties];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientRedirectUris
-----------------------------------
PRINT 'Altering dbo.ClientRedirectUris';

DROP INDEX [IX_ClientRedirectUris_ClientId]
ON [dbo].[ClientRedirectUris];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

WITH [RedirectUriDupes] AS
(
    SELECT  [cri].[Id],
            ROW_NUMBER() OVER (PARTITION BY [cri].[ClientId],
                                            [cri].[RedirectUri]
                               ORDER BY [cri].[Id]
                              ) AS [RowId]
    FROM    [dbo].[ClientRedirectUris] AS [cri]
)
DELETE [cri]
FROM    [dbo].[ClientRedirectUris] AS [cri]
        INNER JOIN [RedirectUriDupes] AS [dupes] ON [cri].[Id] = [dupes].[Id]
WHERE   [dupes].[RowId] <> 1;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientRedirectUris_ClientId_RedirectUri]
ON [dbo].[ClientRedirectUris]
(
    [ClientId],
    [RedirectUri]
);
IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.Clients
-----------------------------------
PRINT 'Altering dbo.Clients';

ALTER TABLE [dbo].[Clients]
ADD CONSTRAINT [DF_Clients_DeviceCodeLifetime] DEFAULT (CONVERT(INT, (0))) FOR [DeviceCodeLifetime];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[Clients]
SET     [DeviceCodeLifetime] = 0
WHERE   [DeviceCodeLifetime] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ALTER COLUMN [DeviceCodeLifetime] INT NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ADD CONSTRAINT [DF_Clients_Created] DEFAULT (SYSDATETIME()) FOR [Created];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[Clients]
SET     [Created] = '0001-01-01T00:00:00.0000000'
WHERE   [Created] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ALTER COLUMN [Created] DATETIME2 NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ADD CONSTRAINT [DF_Clients_NonEditable] DEFAULT (CONVERT(BIT, (0))) FOR [NonEditable];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[Clients]
SET     [NonEditable] = 0
WHERE   [NonEditable] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ALTER COLUMN [NonEditable] BIT NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ADD [PushedAuthorizationLifetime] INT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[Clients]
ADD [RequirePushedAuthorization] BIT NOT NULL DEFAULT (CONVERT(BIT, (0)));

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientScopes
-----------------------------------
PRINT 'Altering dbo.ClientScopes';

DROP INDEX [IX_ClientScopes_ClientId]
ON [dbo].[ClientScopes];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ClientSecrets
-----------------------------------
PRINT 'Altering dbo.ClientSecrets';

ALTER TABLE [dbo].[ClientSecrets]
ADD CONSTRAINT [DF_ClientSecrets_Created] DEFAULT (SYSDATETIME()) FOR [Created];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[ClientSecrets]
SET     [Created] = '0001-01-01T00:00:00.0000000'
WHERE   [Created] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ClientSecrets]
ALTER COLUMN [Created] DATETIME2 NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

-----------------------------------
-- dbo.DeviceCodes
-----------------------------------
PRINT 'Altering dbo.DeviceCodes';

DROP INDEX [IX_DeviceCodes_UserCode]
ON [dbo].[DeviceCodes];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

-----------------------------------
-- dbo.IdentityResources
-----------------------------------
PRINT 'Altering dbo.IdentityResources';

ALTER TABLE [dbo].[IdentityResources]
ADD CONSTRAINT [DF_IdentityResources_Created] DEFAULT (SYSDATETIME()) FOR [Created];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[IdentityResources]
SET     [Created] = '0001-01-01T00:00:00.0000000'
WHERE   [Created] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[IdentityResources]
ALTER COLUMN [Created] DATETIME2 NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[IdentityResources]
ADD CONSTRAINT [DF_IdentityResources_NonEditable] DEFAULT (CONVERT(BIT, (0))) FOR [NonEditable];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

UPDATE  [dbo].[IdentityResources]
SET     [NonEditable] = 0
WHERE   [NonEditable] IS NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[IdentityResources]
ALTER COLUMN [NonEditable] BIT NOT NULL;

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.ServerSideSessions
-----------------------------------
PRINT 'Altering dbo.ServerSideSessions';

DROP TABLE [dbo].[ServerSideSessions];

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE TABLE [dbo].[ServerSideSessions]
(
    [Id]          [BIGINT]        NOT NULL IDENTITY(1, 1),
    [Key]         [NVARCHAR](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    [Scheme]      [NVARCHAR](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    [SubjectId]   [NVARCHAR](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    [SessionId]   [NVARCHAR](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
    [DisplayName] [NVARCHAR](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
    [Created]     [DATETIME2]     NOT NULL,
    [Renewed]     [DATETIME2]     NOT NULL,
    [Expires]     [DATETIME2]     NULL,
    [Data]        [NVARCHAR](MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[ServerSideSessions]
ADD CONSTRAINT [PK_ServerSideSessions] PRIMARY KEY CLUSTERED
    (
        [Id]
    );

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_DisplayName]
ON [dbo].[ServerSideSessions]
(
    [DisplayName]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_Expires]
ON [dbo].[ServerSideSessions]
(
    [Expires]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE UNIQUE NONCLUSTERED INDEX [IX_ServerSideSessions_Key]
ON [dbo].[ServerSideSessions]
(
    [Key]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_SessionId]
ON [dbo].[ServerSideSessions]
(
    [SessionId]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_SubjectId]
ON [dbo].[ServerSideSessions]
(
    [SubjectId]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- dbo.PushedAuthorizationRequests
-----------------------------------
PRINT 'Creating dbo.PushedAuthorizationRequests';

CREATE TABLE [dbo].[PushedAuthorizationRequests]
(
    [Id]                 [BIGINT]        NOT NULL IDENTITY(1, 1),
    [ReferenceValueHash] [NVARCHAR](64)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
    [ExpiresAtUtc]       [DATETIME2]     NOT NULL,
    [Parameters]         [NVARCHAR](MAX) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

ALTER TABLE [dbo].[PushedAuthorizationRequests]
ADD CONSTRAINT [PK_PushedAuthorizationRequests] PRIMARY KEY CLUSTERED
    (
        [Id]
    );

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE NONCLUSTERED INDEX [IX_PushedAuthorizationRequests_ExpiresAtUtc]
ON [dbo].[PushedAuthorizationRequests]
(
    [ExpiresAtUtc]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;

CREATE UNIQUE NONCLUSTERED INDEX [IX_PushedAuthorizationRequests_ReferenceValueHash]
ON [dbo].[PushedAuthorizationRequests]
(
    [ReferenceValueHash]
);

IF @@ERROR <> 0
BEGIN
    SET NOEXEC ON;
END;


-----------------------------------
-- Done
-----------------------------------
COMMIT TRANSACTION;

DECLARE @Success AS BIT;
SET @Success = 1;
SET NOEXEC OFF;
IF @Success = 1
BEGIN
    PRINT 'The Login Server database update succeeded';
END;
ELSE
BEGIN
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;
    PRINT 'The Login Server database update failed';
END;

"@;
	}
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
