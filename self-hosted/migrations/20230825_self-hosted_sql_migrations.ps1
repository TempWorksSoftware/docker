[CmdletBinding(SupportsShouldProcess)]
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
    
    if ($testResult.Table) {
        Write-Host "'$description' already applied." -foregroundcolor green
    } else {
        Write-Host "Applying '$description'..." -NoNewline

        if ($PSCmdlet.ShouldProcess($description)) {
            try {
                Execute-SqlQuery $connectionString $updateQuery
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
        } else {

        }
    }
}

$loginServerUpdates = @(
    @{
        Description = "Update Login Server database schema to accommodate Duende Identity Server upgrade";
        #The script is set to Serializable transaction, if one table from the script exists, then the whole Migration ran without issue.
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ApiResourceClaims]') AND type in (N'U')
"@;
        Migrate = @"
/*
Script created by SQL Compare version 14.4.4.16824 from Red Gate Software Ltd at 6/22/2023 12:44:00 PM

*/
SET NUMERIC_ROUNDABORT OFF;

SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;

SET XACT_ABORT ON;

SET TRANSACTION ISOLATION LEVEL Serializable;

BEGIN TRANSACTION;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Dropping constraints from [dbo].[PersistedGrants]';

ALTER TABLE [dbo].[PersistedGrants] DROP CONSTRAINT [PK_PersistedGrants];

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ApiResources]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ApiResources] ADD
[AllowedAccessTokenSigningAlgorithms] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RequireResourceIndicator] [bit] NOT NULL CONSTRAINT [DF__ApiResour__Requi__2B0A656D] DEFAULT (CONVERT([bit],(0))),
[ShowInDiscoveryDocument] [bit] NOT NULL CONSTRAINT [DF__ApiResour__ShowI__2BFE89A6] DEFAULT (CONVERT([bit],(0)));

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ApiResourceClaims]';

CREATE TABLE [dbo].[ApiResourceClaims]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[ApiResourceId] [int] NOT NULL,
[Type] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ApiResourceClaims] on [dbo].[ApiResourceClaims]';

ALTER TABLE [dbo].[ApiResourceClaims] ADD CONSTRAINT [PK_ApiResourceClaims] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiResourceClaims_ApiResourceId_Type] on [dbo].[ApiResourceClaims]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ApiResourceClaims_ApiResourceId_Type] ON [dbo].[ApiResourceClaims] ([ApiResourceId], [Type]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ApiResourceProperties]';

CREATE TABLE [dbo].[ApiResourceProperties]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[ApiResourceId] [int] NOT NULL,
[Key] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ApiResourceProperties] on [dbo].[ApiResourceProperties]';

ALTER TABLE [dbo].[ApiResourceProperties] ADD CONSTRAINT [PK_ApiResourceProperties] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiResourceProperties_ApiResourceId_Key] on [dbo].[ApiResourceProperties]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ApiResourceProperties_ApiResourceId_Key] ON [dbo].[ApiResourceProperties] ([ApiResourceId], [Key]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ApiResourceScopes]';

CREATE TABLE [dbo].[ApiResourceScopes]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[Scope] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ApiResourceId] [int] NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ApiResourceScopes] on [dbo].[ApiResourceScopes]';

ALTER TABLE [dbo].[ApiResourceScopes] ADD CONSTRAINT [PK_ApiResourceScopes] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiResourceScopes_ApiResourceId_Scope] on [dbo].[ApiResourceScopes]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ApiResourceScopes_ApiResourceId_Scope] ON [dbo].[ApiResourceScopes] ([ApiResourceId], [Scope]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ApiResourceSecrets]';

CREATE TABLE [dbo].[ApiResourceSecrets]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[ApiResourceId] [int] NOT NULL,
[Description] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Value] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Expiration] [datetime2] NULL,
[Type] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Created] [datetime2] NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ApiResourceSecrets] on [dbo].[ApiResourceSecrets]';

ALTER TABLE [dbo].[ApiResourceSecrets] ADD CONSTRAINT [PK_ApiResourceSecrets] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiResourceSecrets_ApiResourceId] on [dbo].[ApiResourceSecrets]';

CREATE NONCLUSTERED INDEX [IX_ApiResourceSecrets_ApiResourceId] ON [dbo].[ApiResourceSecrets] ([ApiResourceId]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ApiScopes]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ApiScopes] ADD
[Created] [datetime2] NOT NULL CONSTRAINT [DF__ApiScopes__Creat__282DF8C2] DEFAULT ('0001-01-01T00:00:00.0000000'),
[Enabled] [bit] NOT NULL CONSTRAINT [DF__ApiScopes__Enabl__29221CFB] DEFAULT (CONVERT([bit],(1))),
[LastAccessed] [datetime2] NULL,
[NonEditable] [bit] NOT NULL CONSTRAINT [DF__ApiScopes__NonEd__2A164134] DEFAULT (CONVERT([bit],(0))),
[Updated] [datetime2] NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ApiScopeClaims]';

IF @@ERROR <> 0 SET NOEXEC ON;

EXEC sp_rename N'[dbo].[ApiScopeClaims].[ApiScopeId]', N'ScopeId', N'COLUMN';

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Recreating ApiScopeId column for backwards compatability';

ALTER TABLE [dbo].[ApiScopeClaims] ADD [ApiScopeId] INT NULL
IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiScopeClaims_ScopeId_Type] on [dbo].[ApiScopeClaims]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ApiScopeClaims_ScopeId_Type] ON [dbo].[ApiScopeClaims] ([ScopeId], [Type]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ApiScopeProperties]';

CREATE TABLE [dbo].[ApiScopeProperties]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[ScopeId] [int] NOT NULL,
[Key] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ApiScopeProperties] on [dbo].[ApiScopeProperties]';

ALTER TABLE [dbo].[ApiScopeProperties] ADD CONSTRAINT [PK_ApiScopeProperties] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ApiScopeProperties_ScopeId_Key] on [dbo].[ApiScopeProperties]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ApiScopeProperties_ScopeId_Key] ON [dbo].[ApiScopeProperties] ([ScopeId], [Key]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[Clients]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[Clients] ADD
[AllowedIdentityTokenSigningAlgorithms] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CibaLifetime] [int] NULL,
[CoordinateLifetimeWithUserSession] [bit] NULL,
[DPoPClockSkew] [time] NOT NULL CONSTRAINT [DF__Clients__DPoPClo__245D67DE] DEFAULT ('00:00:00'),
[DPoPValidationMode] [int] NOT NULL CONSTRAINT [DF__Clients__DPoPVal__25518C17] DEFAULT ((0)),
[InitiateLoginUri] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PollingInterval] [int] NULL,
[RequireDPoP] [bit] NOT NULL CONSTRAINT [DF__Clients__Require__2645B050] DEFAULT (CONVERT([bit],(0))),
[RequireRequestObject] [bit] NOT NULL CONSTRAINT [DF__Clients__Require__2739D489] DEFAULT (CONVERT([bit],(0)));

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ClientPostLogoutRedirectUris]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ClientPostLogoutRedirectUris] ALTER COLUMN [PostLogoutRedirectUri] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientPostLogoutRedirectUris_ClientId_PostLogoutRedirectUri] on [dbo].[ClientPostLogoutRedirectUris]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientPostLogoutRedirectUris_ClientId_PostLogoutRedirectUri] ON [dbo].[ClientPostLogoutRedirectUris] ([ClientId], [PostLogoutRedirectUri]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ClientRedirectUris]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ClientRedirectUris] ALTER COLUMN [RedirectUri] [nvarchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ClientSecrets]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ClientSecrets] ALTER COLUMN [Type] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[ClientSecrets] ALTER COLUMN [Value] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding constraints to [dbo].[ClientSecrets]';

ALTER TABLE [dbo].[ClientSecrets] ADD CONSTRAINT [DF__ClientSecr__Type__47A6A41B] DEFAULT (N'') FOR [Type];

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[ClientSecrets]';

UPDATE [dbo].[ClientSecrets] SET [Type]=DEFAULT WHERE [Type] IS NULL;

ALTER TABLE [dbo].[ClientSecrets] ALTER COLUMN [Type] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[IdentityResourceClaims]';

CREATE TABLE [dbo].[IdentityResourceClaims]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[IdentityResourceId] [int] NOT NULL,
[Type] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_IdentityResourceClaims] on [dbo].[IdentityResourceClaims]';

ALTER TABLE [dbo].[IdentityResourceClaims] ADD CONSTRAINT [PK_IdentityResourceClaims] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_IdentityResourceClaims_IdentityResourceId_Type] on [dbo].[IdentityResourceClaims]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_IdentityResourceClaims_IdentityResourceId_Type] ON [dbo].[IdentityResourceClaims] ([IdentityResourceId], [Type]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[IdentityResourceProperties]';

CREATE TABLE [dbo].[IdentityResourceProperties]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[IdentityResourceId] [int] NOT NULL,
[Key] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Value] [nvarchar] (2000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_IdentityResourceProperties] on [dbo].[IdentityResourceProperties]';

ALTER TABLE [dbo].[IdentityResourceProperties] ADD CONSTRAINT [PK_IdentityResourceProperties] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_IdentityResourceProperties_IdentityResourceId_Key] on [dbo].[IdentityResourceProperties]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_IdentityResourceProperties_IdentityResourceId_Key] ON [dbo].[IdentityResourceProperties] ([IdentityResourceId], [Key]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[PersistedGrants]';

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[PersistedGrants] ADD
[Id] [bigint] NOT NULL IDENTITY(1, 1);

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[PersistedGrants] ADD
[ConsumedTime] [datetime2] NULL,
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SessionId] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

ALTER TABLE [dbo].[PersistedGrants] ALTER COLUMN [Key] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_PersistedGrants] on [dbo].[PersistedGrants]';

ALTER TABLE [dbo].[PersistedGrants] ADD CONSTRAINT [PK_PersistedGrants] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_PersistedGrants_Key] on [dbo].[PersistedGrants]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_PersistedGrants_Key] ON [dbo].[PersistedGrants] ([Key]) WHERE ([Key] IS NOT NULL);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_PersistedGrants_ConsumedTime] on [dbo].[PersistedGrants]';

CREATE NONCLUSTERED INDEX [IX_PersistedGrants_ConsumedTime] ON [dbo].[PersistedGrants] ([ConsumedTime]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_PersistedGrants_Expiration] on [dbo].[PersistedGrants]';

CREATE NONCLUSTERED INDEX [IX_PersistedGrants_Expiration] ON [dbo].[PersistedGrants] ([Expiration]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_PersistedGrants_SubjectId_SessionId_Type] on [dbo].[PersistedGrants]';

CREATE NONCLUSTERED INDEX [IX_PersistedGrants_SubjectId_SessionId_Type] ON [dbo].[PersistedGrants] ([SubjectId], [SessionId], [Type]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[IdentityProviders]';

CREATE TABLE [dbo].[IdentityProviders]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[Scheme] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DisplayName] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Enabled] [bit] NOT NULL,
[Type] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Properties] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Created] [datetime2] NOT NULL,
[Updated] [datetime2] NULL,
[LastAccessed] [datetime2] NULL,
[NonEditable] [bit] NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_IdentityProviders] on [dbo].[IdentityProviders]';

ALTER TABLE [dbo].[IdentityProviders] ADD CONSTRAINT [PK_IdentityProviders] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_IdentityProviders_Scheme] on [dbo].[IdentityProviders]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_IdentityProviders_Scheme] ON [dbo].[IdentityProviders] ([Scheme]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[Keys]';

CREATE TABLE [dbo].[Keys]
(
[Id] [nvarchar] (450) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Version] [int] NOT NULL,
[Created] [datetime2] NOT NULL,
[Use] [nvarchar] (450) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Algorithm] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsX509Certificate] [bit] NOT NULL,
[DataProtected] [bit] NOT NULL,
[Data] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_Keys] on [dbo].[Keys]';

ALTER TABLE [dbo].[Keys] ADD CONSTRAINT [PK_Keys] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_Keys_Use] on [dbo].[Keys]';

CREATE NONCLUSTERED INDEX [IX_Keys_Use] ON [dbo].[Keys] ([Use]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating [dbo].[ServerSideSessions]';

CREATE TABLE [dbo].[ServerSideSessions]
(
[Id] [int] NOT NULL IDENTITY(1, 1),
[Key] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Scheme] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SubjectId] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SessionId] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DisplayName] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Created] [datetime2] NOT NULL,
[Renewed] [datetime2] NOT NULL,
[Expires] [datetime2] NULL,
[Data] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating primary key [PK_ServerSideSessions] on [dbo].[ServerSideSessions]';

ALTER TABLE [dbo].[ServerSideSessions] ADD CONSTRAINT [PK_ServerSideSessions] PRIMARY KEY CLUSTERED  ([Id]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ServerSideSessions_DisplayName] on [dbo].[ServerSideSessions]';

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_DisplayName] ON [dbo].[ServerSideSessions] ([DisplayName]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ServerSideSessions_Expires] on [dbo].[ServerSideSessions]';

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_Expires] ON [dbo].[ServerSideSessions] ([Expires]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ServerSideSessions_Key] on [dbo].[ServerSideSessions]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ServerSideSessions_Key] ON [dbo].[ServerSideSessions] ([Key]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ServerSideSessions_SessionId] on [dbo].[ServerSideSessions]';

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_SessionId] ON [dbo].[ServerSideSessions] ([SessionId]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ServerSideSessions_SubjectId] on [dbo].[ServerSideSessions]';

CREATE NONCLUSTERED INDEX [IX_ServerSideSessions_SubjectId] ON [dbo].[ServerSideSessions] ([SubjectId]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientClaims_ClientId_Type_Value] on [dbo].[ClientClaims]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientClaims_ClientId_Type_Value] ON [dbo].[ClientClaims] ([ClientId], [Type], [Value]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientCorsOrigins_ClientId_Origin] on [dbo].[ClientCorsOrigins]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientCorsOrigins_ClientId_Origin] ON [dbo].[ClientCorsOrigins] ([ClientId], [Origin]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientGrantTypes_ClientId_GrantType] on [dbo].[ClientGrantTypes]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientGrantTypes_ClientId_GrantType] ON [dbo].[ClientGrantTypes] ([ClientId], [GrantType]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientIdPRestrictions_ClientId_Provider] on [dbo].[ClientIdPRestrictions]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientIdPRestrictions_ClientId_Provider] ON [dbo].[ClientIdPRestrictions] ([ClientId], [Provider]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientProperties_ClientId_Key] on [dbo].[ClientProperties]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientProperties_ClientId_Key] ON [dbo].[ClientProperties] ([ClientId], [Key]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_ClientScopes_ClientId_Scope] on [dbo].[ClientScopes]';

CREATE UNIQUE NONCLUSTERED INDEX [IX_ClientScopes_ClientId_Scope] ON [dbo].[ClientScopes] ([ClientId], [Scope]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Altering [dbo].[DeviceCodes]';

ALTER TABLE [dbo].[DeviceCodes] ADD
[Description] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SessionId] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Creating index [IX_DeviceCodes_Expiration] on [dbo].[DeviceCodes]';

CREATE NONCLUSTERED INDEX [IX_DeviceCodes_Expiration] ON [dbo].[DeviceCodes] ([Expiration]);

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiResourceClaims]';

ALTER TABLE [dbo].[ApiResourceClaims] ADD CONSTRAINT [FK_ApiResourceClaims_ApiResources_ApiResourceId] FOREIGN KEY ([ApiResourceId]) REFERENCES [dbo].[ApiResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiResourceProperties]';

ALTER TABLE [dbo].[ApiResourceProperties] ADD CONSTRAINT [FK_ApiResourceProperties_ApiResources_ApiResourceId] FOREIGN KEY ([ApiResourceId]) REFERENCES [dbo].[ApiResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiResourceScopes]';

ALTER TABLE [dbo].[ApiResourceScopes] ADD CONSTRAINT [FK_ApiResourceScopes_ApiResources_ApiResourceId] FOREIGN KEY ([ApiResourceId]) REFERENCES [dbo].[ApiResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiResourceSecrets]';

ALTER TABLE [dbo].[ApiResourceSecrets] ADD CONSTRAINT [FK_ApiResourceSecrets_ApiResources_ApiResourceId] FOREIGN KEY ([ApiResourceId]) REFERENCES [dbo].[ApiResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiScopeClaims]';

ALTER TABLE [dbo].[ApiScopeClaims] ADD CONSTRAINT [FK_ApiScopeClaims_ApiScopes_ScopeId] FOREIGN KEY ([ScopeId]) REFERENCES [dbo].[ApiScopes] ([Id]) ON DELETE NO ACTION;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[ApiScopeProperties]';

ALTER TABLE [dbo].[ApiScopeProperties] ADD CONSTRAINT [FK_ApiScopeProperties_ApiScopes_ScopeId] FOREIGN KEY ([ScopeId]) REFERENCES [dbo].[ApiScopes] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[IdentityResourceClaims]';

ALTER TABLE [dbo].[IdentityResourceClaims] ADD CONSTRAINT [FK_IdentityResourceClaims_IdentityResources_IdentityResourceId] FOREIGN KEY ([IdentityResourceId]) REFERENCES [dbo].[IdentityResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Adding foreign keys to [dbo].[IdentityResourceProperties]';

ALTER TABLE [dbo].[IdentityResourceProperties] ADD CONSTRAINT [FK_IdentityResourceProperties_IdentityResources_IdentityResourceId] FOREIGN KEY ([IdentityResourceId]) REFERENCES [dbo].[IdentityResources] ([Id]) ON DELETE CASCADE;

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Copying ApiSecrets into ApiResourceSecrets';

INSERT INTO [dbo].[ApiResourceSecrets] ([ApiResourceId], [Description], [Value], [Expiration], [Type], [Created])
SELECT [ApiResourceId], [Description], [Value], [Expiration], [Type], [Created] FROM [dbo].[ApiSecrets];

IF @@ERROR <> 0 SET NOEXEC ON;

PRINT N'Copying ApiScopes into ApiResourceScopes';

INSERT INTO [dbo].[ApiResourceScopes] ([Scope], [ApiResourceId])
SELECT [Name], [ApiResourceId] FROM [dbo].[ApiScopes];

IF @@ERROR <> 0 SET NOEXEC ON;

COMMIT TRANSACTION;

IF @@ERROR <> 0 SET NOEXEC ON;

DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END;

"@;
    },
    @{
        Description = "Create ClientAdditionalInfo table and insert flags for existing products";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientAdditionalInfo]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE dbo.ClientAdditionalInfo
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ClientId INT NOT NULL UNIQUE, 
    IsTWProduct BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_ClientAdditionalInfo_ClientId_ref_Clients_Id FOREIGN KEY (ClientId) REFERENCES dbo.Clients(Id)
);

INSERT INTO dbo.ClientAdditionalInfo (ClientId, IsTWProduct)
SELECT Id, 1 AS IsTWProduct
FROM dbo.Clients;
"@;
    },
    @{
        Description = "Create allowlist table for Clients and User Types";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientUserTypeMapping]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE dbo.ClientUserTypeMapping
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ClientId INT NOT NULL, 
    AllowUserType NVARCHAR(250) NOT NULL,
    CONSTRAINT FK_ClientUserTypeMapping_ClientId_ref_Clients_Id FOREIGN KEY (ClientId) REFERENCES dbo.Clients(Id),
    CONSTRAINT UX_ClientUserTypeMapping_ClientId_AllowUserType UNIQUE (ClientId, AllowUserType)
);
"@;
    },
    @{
        Description = "Create allowlist table for Clients and Tenants/SubTenants";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientTenantMapping]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE dbo.ClientTenantMapping
(
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ClientId INT NOT NULL, 
    AllowTenantId INT NOT NULL,
    AllowSubTenantId INT NULL,
	AllowProductInstanceId UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_ClientTenantMapping_ClientId_ref_Clients_Id FOREIGN KEY (ClientId) REFERENCES dbo.Clients(Id),
    CONSTRAINT FK_ClientTenantMapping_AllowTenantId_ref_Tenants_TenantId FOREIGN KEY (AllowTenantId) REFERENCES dbo.Tenants(TenantId),
    CONSTRAINT FK_ClientTenantMapping_AllowSubTenantId_ref_SubTenants_SubTenantId FOREIGN KEY (AllowSubTenantId) REFERENCES dbo.SubTenants(SubTenantId),
);

CREATE UNIQUE NONCLUSTERED INDEX [UX_ClientTenantMapping_ClientId_AllowTenantId_AllowSubTenantId_AllowProductInstaceId]
ON [dbo].[ClientTenantMapping] (ClientId, AllowTenantId, AllowSubTenantId, AllowProductInstanceId);
;
"@;
    },
    @{
        Description = "Create RepName function for logging";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RepName]') AND type in (N'FN')
"@;
        Migrate = @"
CREATE FUNCTION dbo.RepName() RETURNS VARCHAR(20) AS
BEGIN
    RETURN ISNULL(CONVERT(VARCHAR(20), SESSION_CONTEXT(N'Repname')), CONVERT(VARCHAR(20), STUFF(SYSTEM_USER, 1, CHARINDEX('\', SYSTEM_USER), '')));
END;
"@;
    },
    @{
        Description = "Create logging table Clients";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[ClientId]       INT                                              NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL
    CONSTRAINT [PK_ClientsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table Clients";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_Clients_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_Clients_IUD]
ON [dbo].[Clients]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        ClientId,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientAdditionalInfo";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientAdditionalInfoLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientAdditionalInfoLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL
    CONSTRAINT [PK_ClientAdditionalInfoLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientAdditionalInfo";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientAdditionalInfo_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientAdditionalInfo_IUD]
ON [dbo].[ClientAdditionalInfo]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientAdditionalInfoLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientScopes";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientScopesLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientScopesLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientScopesLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientScopes";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientScopes_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientScopes_IUD]
ON [dbo].[ClientScopes]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientScopesLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientTenantMapping";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientTenantMappingLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientTenantMappingLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientTenantMappingLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientTenantMapping";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientTenantMapping_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientTenantMapping_IUD]
ON [dbo].[ClientTenantMapping]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientTenantMappingLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientUserTypeMapping";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientUserTypeMappingLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientUserTypeMappingLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientUserTypeMappingLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientUserTypeMapping";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientUserTypeMapping_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientUserTypeMapping_IUD]
ON [dbo].[ClientUserTypeMapping]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientUserTypeMappingLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientGrantTypes";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientGrantTypesLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientGrantTypesLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientGrantTypesLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientGrantTypes";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientGrantTypes_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientGrantTypes_IUD]
ON [dbo].[ClientGrantTypes]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientGrantTypesLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientRedirectUris";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientRedirectUrisLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientRedirectUrisLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientRedirectUrisLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientRedirectUris";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientRedirectUris_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientRedirectUris_IUD]
ON [dbo].[ClientRedirectUris]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientRedirectUrisLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientSecrets";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientSecretsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientSecretsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientSecretsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientSecrets";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientSecrets_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientSecrets_IUD]
ON [dbo].[ClientSecrets]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientSecretsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientClaims";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientClaimsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientClaimsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientClaimsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientClaims";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientClaims_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientClaims_IUD]
ON [dbo].[ClientClaims]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientClaimsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientCorsOrigins";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientCorsOriginsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientCorsOriginsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientCorsOriginsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientCorsOrigins";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientCorsOrigins_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientCorsOrigins_IUD]
ON [dbo].[ClientCorsOrigins]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientCorsOriginsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientIdPRestrictions";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientIdPRestrictionsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientIdPRestrictionsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientIdPRestrictionsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientIdPRestrictions";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientIdPRestrictions_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientIdPRestrictions_IUD]
ON [dbo].[ClientIdPRestrictions]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientIdPRestrictionsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientProducts";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientProductsLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientProductsLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientProductsLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientProducts";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientProducts_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientProducts_IUD]
ON [dbo].[ClientProducts]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientProductsLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientProperties";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientPropertiesLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientPropertiesLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientPropertiesLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientProperties";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientProperties_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientProperties_IUD]
ON [dbo].[ClientProperties]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientPropertiesLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
    @{
        Description = "Create logging table ClientPostLogoutRedirectUris";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientPostLogoutRedirectUrisLog]') AND type in (N'U')
"@;
        Migrate = @"
CREATE TABLE [dbo].[ClientPostLogoutRedirectUrisLog] (
    [LogId]          BIGINT                                           IDENTITY (1, 1) NOT NULL,
    [ModifiedBy]     NVARCHAR (20)                                    NOT NULL,
    [ModifiedOn]     DATETIMEOFFSET (7) DEFAULT (SYSDATETIMEOFFSET()) NOT NULL,
	[Id]             INT                                              NOT NULL,
    [NewJson]        NVARCHAR (MAX)                                   NULL,
	[OldJson]        NVARCHAR (MAX)                                   NULL,
    CONSTRAINT [PK_ClientPostLogoutRedirectUrisLog_LogId] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
"@;
    },
    @{
        Description = "Create logging trigger for table ClientPostLogoutRedirectUris";
        Test = @"
SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TR_ClientPostLogoutRedirectUris_IUD]') AND type in (N'TR')
"@;
        Migrate = @"
CREATE TRIGGER [TR_ClientPostLogoutRedirectUris_IUD]
ON [dbo].[ClientPostLogoutRedirectUris]
FOR UPDATE, INSERT, DELETE
AS
BEGIN

	INSERT INTO dbo.ClientPostLogoutRedirectUrisLog 
	(
	    ModifiedBy,
        ModifiedOn,
        Id,
        NewJson,
        OldJson
	)
	SELECT  dbo.RepName(), -- ModifiedBy - nvarchar(20)
            SYSDATETIMEOFFSET(), -- ModifiedOn - datetimeoffset(7)
            COALESCE(i.[Id], d.[Id]), -- Id - int
			( SELECT * 
			   FROM Inserted i2
			   WHERE i2.[Id] = i.[id]
			   FOR JSON PATH ), -- NewJson - nvarchar(max)
			( SELECT * 
			   FROM Deleted d2
			   WHERE d2.[Id] = d.[id]
			   FOR JSON PATH ) -- OldJson - nvarchar(max)
	FROM Inserted i
	FULL JOIN Deleted d ON i.[Id] = d.[Id]

END;
"@;
    },
	@{
		Description= "Create table ClientAllowedIPAddress and populate default values.";
		Test = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientAllowedIPAddress]') AND type in (N'U');";
		Migrate = @"
CREATE TABLE dbo.ClientAllowedIPAddress
(
    Id INT IDENTITY(1, 1) PRIMARY KEY NOT NULL,
    ClientId INT NOT NULL,
    AllowedIPAddressOrRange VARCHAR(50),
	CONSTRAINT FK_ClientAllowedIPAddress_ClientId_on_Clients_Id FOREIGN KEY (ClientId) REFERENCES dbo.Clients (Id)
);

WITH TWClients AS
(
    SELECT  c.Id
    FROM    dbo.Clients c
            INNER JOIN dbo.ClientAdditionalInfo cai ON cai.ClientId = c.Id
    WHERE   cai.IsTWProduct = 1
)
INSERT INTO dbo.ClientAllowedIPAddress
(
    ClientId,
    AllowedIPAddressOrRange
)
SELECT  t.Id,
        '0.0.0.0/0'
FROM    TWClients t;
"@;
	},
	@{
		Description= "Client grant types";
		Test= @"
SELECT  1
FROM    dbo.Clients c
        INNER JOIN dbo.ClientGrantTypes cgt ON cgt.ClientId = c.Id
WHERE   c.ClientId = 'twapi3'
        AND cgt.GrantType = 'client_credentials';		
"@;
		Migrate= @"
INSERT INTO dbo.ClientGrantTypes
(
    ClientId,
    GrantType
)
SELECT  c.Id,
        N'client_credentials'
FROM    dbo.Clients c
WHERE   c.ClientId = 'twapi3';		
"@;
	}
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
