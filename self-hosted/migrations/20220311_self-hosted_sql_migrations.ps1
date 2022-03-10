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
        Description = "Create twapi3 client";
        Test = "SELECT TOP 1 1 FROM dbo.Clients WHERE ClientId = 'twapi3'";
        Migrate = @"
INSERT INTO dbo.Clients (
    [AbsoluteRefreshTokenLifetime], [AccessTokenLifetime], [AccessTokenType], [AllowAccessTokensViaBrowser], [AllowOfflineAccess], [AllowPlainTextPkce],
    [AllowRememberConsent], [AlwaysIncludeUserClaimsInIdToken], [AlwaysSendClientClaims], [AuthorizationCodeLifetime], [BackChannelLogoutSessionRequired],
    [ClientId], [ClientName], [EnableLocalLogin], [Enabled], [FrontChannelLogoutSessionRequired], [IdentityTokenLifetime], [IncludeJwtId], [ProtocolType],
    [RefreshTokenExpiration], [RefreshTokenUsage], [RequireClientSecret], [RequireConsent], [RequirePkce], [SlidingRefreshTokenLifetime],
    [UpdateAccessTokenClaimsOnRefresh], [Created], [DeviceCodeLifetime], [NonEditable]
) VALUES (
    --AbsoluteRefreshTokenLifetime, AccessTokenLifetime, AccessTokenType, AllowAccessTokensViaBrowser, AllowOfflineAccess, AllowPlainTextPkce,
    2592000, 7884000, 1, 0, 1, 0,
    --AllowRememberConsent, AlwaysIncludeUserClaimsInIdToken, AlwaysSendClientClaims, AuthorizationCodeLifetime, BackChannelLogoutSessionRequired,
    0, 1, 0, 300, 0,
    --ClientId, ClientName, EnableLocalLogin, Enabled, FrontChannelLogoutSessionRequired, IdentityTokenLifetime, IncludeJwtId, ProtocolType,
    'twapi3', 'TempWorks API v3', 1, 1, 0, 300, 0, 'oidc',
    --RefreshTokenExpiration, RefreshTokenUsage, RequireClientSecret, RequireConsent, RequirePkce, SlidingRefreshTokenLifetime,
    1, 1, 1, 0, 0, 1296000, 0,
    --UpdateAccessTokenClaimsOnRefresh, Created, DeviceCodeLifetime, NonEditable
    GETDATE(), 1000, 0
)
"@;
    },
    @{
        Description = "Add twapi3 client grant types";
        Test = @"
SELECT 1 FROM dbo.ClientGrantTypes cgt
INNER JOIN dbo.Clients c on cgt.ClientId = c.Id
WHERE c.ClientId = 'twapi3' AND cgt.GrantType = 'tw-privileged-service'
"@;
        Migrate = @"
INSERT INTO dbo.ClientGrantTypes ( [ClientId], [GrantType] )
SELECT TOP 1 Id, 'tw-privileged-service' FROM Clients c where c.ClientId = 'twapi3'
"@;
    },
    @{
        Description = "Add tw-api-access API scope";
        Test = "SELECT TOP 1 1 FROM dbo.ApiScopes WHERE [Name] = 'tw-api-access'";
        Migrate = @"
INSERT INTO dbo.ApiScopes ( [ApiResourceId], [Description], [DisplayName], [Emphasize], [Name], [Required], [ShowInDiscoveryDocument] )
VALUES ( 1, 'TW API Access', 'TW API Access', 0, 'tw-api-access', 0, 0 )
"@;
    },
    @{
        Description = "Add client scopes for twapi3 client";
        Test = @"
SELECT 1 FROM dbo.ClientScopes cs
INNER JOIN dbo.Clients c on cs.ClientId = c.Id
WHERE c.ClientId = 'twapi3' AND cs.Scope = 'tw-api-access'

"@;
        Migrate = @"
INSERT INTO dbo.ClientScopes ( [ClientId], [Scope] )
SELECT TOP 1 Id, 'tw-api-access' FROM Clients c where c.ClientId = 'twapi3'
"@;
    },
    @{
        Description = "Make ExternalIdentityProvider columns not nullable";
        Test = @"
IF (COLUMNPROPERTY(OBJECT_ID('dbo.ExternalIdentityProvider', 'U'), 'AuthorityUrl', 'AllowsNull') = 0 OR COLUMNPROPERTY(OBJECT_ID('dbo.ExternalIdentityProvider', 'U'), 'ClientId', 'AllowsNull') = 0 )
BEGIN
  SELECT 1
END
"@;
        Migrate = @"
ALTER TABLE ExternalIdentityProvider
ALTER COLUMN [AuthorityUrl] [nvarchar](1000) NOT NULL;

ALTER TABLE ExternalIdentityProvider
ALTER COLUMN [ClientId] [nvarchar](1000) NOT NULL;
"@;
    },
    @{
        Description = "Create new schema for logging changes to ExternalIdentityProviders";
        Test = "SELECT 1 FROM sys.objects WHERE [Name] = 'ExternalIdentityProviderLog'";
        Migrate = @"
CREATE TABLE [dbo].[ExternalIdentityProviderLog] (
    [ExternalIdentityProviderLogId]         BIGINT IDENTITY (1, 1) NOT NULL,
    [ExternalIdentityProviderId]            BIGINT NOT NULL,
    [ModifiedBy]                            NVARCHAR (20) NULL,
    [ModifiedOn]                            DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    [PreviousAuthorityUrl]                  NVARCHAR (1000) NULL,
    [PreviousClientId]                      NVARCHAR (1000) NULL,
    [PreviousClientSecret]                  VARBINARY (MAX) NULL,
    [PreviousClaim]                         NVARCHAR(1000) NULL,
    [PreviousLogoutUrl]                     NVARCHAR(1000) NULL,
    [PreviousIsActive]                      BIT NULL,
    [PreviousBypassTenantRestrictions]		BIT NULL,
    CONSTRAINT [PK_ExternalIdentityProviderLog_ExternalIdentityProviderLogId] PRIMARY KEY CLUSTERED ([ExternalIdentityProviderId] ASC, [ExternalIdentityProviderLogId] ASC),
    CONSTRAINT [FK_ExternalIdentityProviderLog_ExternalIdentityProviderId] FOREIGN KEY ([ExternalIdentityProviderId]) REFERENCES [dbo].[ExternalIdentityProvider] ([ExternalIdentityProviderId])
);
"@;
    },
    @{
        Description = "Create ExternalIdentityProvider_IUD";
        Test = "IF EXISTS ( SELECT 1 FROM sys.objects WHERE [Name] = 'ExternalIdentityProvider' ) AND
EXISTS ( SELECT 1 FROM sys.objects WHERE [Name] = 'ExternalIdentityProvider_IUD' )
SELECT 1;";
        Migrate = @"
CREATE TRIGGER [dbo].[ExternalIdentityProvider_IUD] ON [dbo].[ExternalIdentityProvider]
FOR INSERT, UPDATE, DELETE AS

IF @@ROWCOUNT = 0 
RETURN

SET NOCOUNT ON

DECLARE @RepName VARCHAR(20) = ISNULL(CONVERT(VARCHAR(20), SESSION_CONTEXT(N'Repname')), CONVERT(VARCHAR(20), STUFF(SYSTEM_USER, 1, CHARINDEX('\', SYSTEM_USER), '')));

INSERT INTO [dbo].[ExternalIdentityProviderLog]
(ExternalIdentityProviderId, ModifiedBy, PreviousAuthorityUrl, PreviousClientId, PreviousClientSecret, PreviousClaim, PreviousLogoutUrl, PreviousIsActive, PreviousBypassTenantRestrictions)
SELECT
i.ExternalIdentityProviderId,
@RepName AS ModifiedBy,
d.AuthorityUrl AS PreviousAuthorityUrl,
d.ClientId AS PreviousClientId,
d.ClientSecret AS PreviousClientSecret,
d.Claim AS PreviousClaim,
d.LogoutUrl AS PreviousLogoutUrl,
d.IsActive AS PreviousIsActive,
d.BypassTenantRestrictions AS PreviousBypassTenantRestrictions
FROM [Inserted] i
FULL OUTER JOIN [Deleted] d ON i.[ExternalIdentityProviderId] = d.[ExternalIdentityProviderId]
;
"@;
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
