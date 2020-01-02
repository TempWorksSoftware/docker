param (
    # Path to the api-email-server configuration directory
    [ValidateScript(
         {
             if (-Not (Test-Path -Path $_)) {
                 throw "Email Server service config directory ($_) not found!"
             }
             return $true
         })]
    [string]
    $apiEmailServer = $(
        if (-Not (Test-Path -Path "C:\ProgramData\TempWorks\config\api-email-server")) {
            throw "Email Server service config directory (C:\ProgramData\TempWorks\config\api-email-server) not found!"
        }
        return "C:\ProgramData\TempWorks\config\api-email-server"
    )
)

$appsettingsPath = $apiEmailServer+'\appsettings.json'

$emailServerConnectionString = (Get-Content ($appsettingsPath) -ErrorAction stop | Out-String |ConvertFrom-Json).ConnectionStrings.EmailDatabase

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
    }
}

$sqlMigrationTestQuery1 = @'
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Email]') AND type in (N'U')
'@
$sqlMigrationQuery1 = @'

SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;


IF NOT EXISTS (SELECT 1 from sys.database_principals WHERE name='email-log' and Type = 'R')
PRINT N'Creating [email-log]...';
BEGIN
CREATE ROLE [email-log]
AUTHORIZATION [dbo];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Email]') AND type in (N'U'))
BEGIN
PRINT N'Creating [dbo].[Email]...';
CREATE TABLE [dbo].[Email] (
    [Id]                 BIGINT           IDENTITY (1, 1) NOT NULL,
    [EmailSessionId]     UNIQUEIDENTIFIER NOT NULL,
    [EmailId]            VARCHAR (1000)   NULL,
    [EmailTo]            VARCHAR (1000)   NULL,
    [EmailRecipientType] VARCHAR (10)     NULL,
    [OriginTypeId]       INT              NULL,
    [OriginId]           BIGINT           NULL,
    CONSTRAINT [PK_Email_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailDomainConfiguration]') AND type in (N'U'))
BEGIN
PRINT N'Creating [dbo].[EmailDomainConfiguration]...';
CREATE TABLE [dbo].[EmailDomainConfiguration] (
    [Id]                 BIGINT        NOT NULL,
    [Domain]             VARCHAR (200) NOT NULL,
    [Host]               VARCHAR (200) NOT NULL,
    [Port]               INT           NOT NULL,
    [SecureSocketOption] INT           NOT NULL,
    CONSTRAINT [PK_EmailDomainConfiguration_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailSession]') AND type in (N'U'))
BEGIN
PRINT N'Creating [dbo].[EmailSession]...';
CREATE TABLE [dbo].[EmailSession] (
    [Id]                        BIGINT             IDENTITY (1, 1) NOT NULL,
    [EmailSessionId]            UNIQUEIDENTIFIER   NOT NULL,
    [CorrelationId]             UNIQUEIDENTIFIER   NULL,
    [IsTraceOn]                 BIT                NOT NULL,
    [AccountId]                 VARCHAR (200)      NULL,
    [EmailServiceId]            INT                NULL,
    [DateCreated]               DATETIMEOFFSET (2) NOT NULL,
    [DateCompleted]             DATETIMEOFFSET (2) NULL,
    [HasError]                  BIT                NOT NULL,
    [Tenant]                    VARCHAR (200)      NULL,
    [SrIdent]                   INT                NULL,
    [Tags]                      VARCHAR (2000)     NULL,
    [RestartedByEmailSessionId] UNIQUEIDENTIFIER   NULL,
    [NumberOfEmails]            INT                NOT NULL,
    CONSTRAINT [PK_EmailSession] PRIMARY KEY NONCLUSTERED ([EmailSessionId] ASC)
);
END

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = 'ICX_EmailSession' AND object_id = OBJECT_ID('EmailSession'))
BEGIN
PRINT N'Creating [dbo].[EmailSession].[ICX_EmailSession]...';
CREATE CLUSTERED INDEX [ICX_EmailSession]
ON [dbo].[EmailSession]([Id] ASC);
END

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = 'IX_EmailSession_Tenant_SrIdent' AND object_id = OBJECT_ID('EmailSession'))
BEGIN
PRINT N'Creating [dbo].[EmailSession].[IX_EmailSession_Tenant_SrIdent]...';
CREATE NONCLUSTERED INDEX [IX_EmailSession_Tenant_SrIdent]
ON [dbo].[EmailSession]([Tenant] ASC, [SrIdent] ASC);
END


IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EmailSessionLog]') AND type in (N'U'))
BEGIN
PRINT N'Creating [dbo].[EmailSessionLog]...';
CREATE TABLE [dbo].[EmailSessionLog] (
    [LogId]                      BIGINT             IDENTITY (1, 1) NOT NULL,
    [EmailSessionId]             UNIQUEIDENTIFIER   NOT NULL,
    [IsError]                    AS                 (CASE [LogLevel] WHEN 'error' THEN CONVERT (BIT, (1)) ELSE CONVERT (BIT, (0)) END) PERSISTED NOT NULL,
    [LogLevel]                   VARCHAR (100)      NOT NULL,
    [Description]                VARCHAR (1000)     NULL,
    [EmailId]                    VARCHAR (300)      NULL,
    [DateCreated]                DATETIMEOFFSET (2) NOT NULL,
    [LogMessage]                 VARCHAR (MAX)      NULL,
    [IsLogEntryForSpecificEmail] AS                 (CASE WHEN [EmailId] IS NULL THEN CONVERT (BIT, (0)) ELSE CONVERT (BIT, (1)) END) PERSISTED NOT NULL,
    CONSTRAINT [PK_EmailSessionLog] PRIMARY KEY CLUSTERED ([LogId] ASC)
);
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSession_EmailSessionId]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSession_EmailSessionId]...';
ALTER TABLE [dbo].[EmailSession]
ADD CONSTRAINT [DF_EmailSession_EmailSessionId] DEFAULT (newid()) FOR [EmailSessionId];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSession_IsTraceOn]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSession_IsTraceOn]...';
ALTER TABLE [dbo].[EmailSession]
ADD CONSTRAINT [DF_EmailSession_IsTraceOn] DEFAULT (0) FOR [IsTraceOn];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSession_DateCreated]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSession_DateCreated]...';
ALTER TABLE [dbo].[EmailSession]
ADD CONSTRAINT [DF_EmailSession_DateCreated] DEFAULT (sysutcdatetime()) FOR [DateCreated];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSession_HasError]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSession_HasError]...';
ALTER TABLE [dbo].[EmailSession]
ADD CONSTRAINT [DF_EmailSession_HasError] DEFAULT ((0)) FOR [HasError];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSession_NumberOfEmails]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSession_NumberOfEmails]...';
ALTER TABLE [dbo].[EmailSession]
ADD CONSTRAINT [DF_EmailSession_NumberOfEmails] DEFAULT ((0)) FOR [NumberOfEmails];
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EmailSessionLog_DateCreated]') AND type = 'D')
BEGIN
PRINT N'Creating [dbo].[DF_EmailSessionLog_DateCreated]...';
ALTER TABLE [dbo].[EmailSessionLog]
ADD CONSTRAINT [DF_EmailSessionLog_DateCreated] DEFAULT (sysutcdatetime()) FOR [DateCreated];
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Email_EmailSession_EmailSessionId]') AND parent_object_id = OBJECT_ID(N'[dbo].[Email]'))
BEGIN
PRINT N'Creating [dbo].[FK_Email_EmailSession_EmailSessionId]...';
ALTER TABLE [dbo].[Email] WITH NOCHECK
ADD CONSTRAINT [FK_Email_EmailSession_EmailSessionId] FOREIGN KEY ([EmailSessionId]) REFERENCES [dbo].[EmailSession] ([EmailSessionId]);
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EmailRecipientType]') AND parent_object_id = OBJECT_ID(N'[dbo].[EmailRecipientType]'))
BEGIN
PRINT N'Creating [dbo].[CK_EmailRecipientType]...';
ALTER TABLE [dbo].[Email] WITH NOCHECK
ADD CONSTRAINT [CK_EmailRecipientType] CHECK ([EmailRecipientType] IS NULL OR ([EmailRecipientType]='Cc' OR [EmailRecipientType]='Bcc' OR [EmailRecipientType]='To'));
END

IF NOT EXISTS ( SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'Implementation_RefreshLookupData') AND type IN ( N'P', N'PC' ) )
BEGIN
-- PRINT N'Creating [dbo].[Implementation_RefreshLookupData]...';
EXEC('
CREATE PROCEDURE [dbo].[Implementation_RefreshLookupData]
AS
    -- Procedure should remove and install lookup data
    TRUNCATE TABLE dbo.EmailDomainConfiguration;

    INSERT dbo.EmailDomainConfiguration ( Id ,
                                          Domain ,
                                          Host ,
                                          Port ,
                                          SecureSocketOption )
           SELECT 1, ''gmail.com'', ''smtp.gmail.com'', 465, 1
           UNION
           SELECT 2, ''google.com'', ''smtp.gmail.com'', 465, 1
           UNION
           SELECT 3, ''outlook.com'', ''smtp-mail.outlook.com'', 587, 1
           UNION
           SELECT 4, ''hotmail.com'', ''smtp-mail.outlook.com'', 587, 1;
')
END

PRINT N'Creating Permission...';
GRANT INSERT
ON OBJECT::[dbo].[Email] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT SELECT
ON OBJECT::[dbo].[Email] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT DELETE
ON OBJECT::[dbo].[Email] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT SELECT
ON OBJECT::[dbo].[EmailDomainConfiguration] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT INSERT
ON OBJECT::[dbo].[EmailSession] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT SELECT
ON OBJECT::[dbo].[EmailSession] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT UPDATE
ON OBJECT::[dbo].[EmailSession] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT INSERT
ON OBJECT::[dbo].[EmailSessionLog] TO [email-log]
AS [dbo];

PRINT N'Creating Permission...';
GRANT SELECT
ON OBJECT::[dbo].[EmailSessionLog] TO [email-log]
AS [dbo];

PRINT N'Creating [Description]...';
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'Database used by the TempWorks Email Service';

PRINT N'Creating [email-log].[Description]...';
EXECUTE sp_addextendedproperty @name = N'Description', @value = N'role allowed to read and write to the log tables', @level0type = N'USER', @level0name = N'email-log';

PRINT N'Checking existing data against newly created constraints';

ALTER TABLE [dbo].[Email] WITH CHECK CHECK CONSTRAINT [FK_Email_EmailSession_EmailSessionId];

ALTER TABLE [dbo].[Email] WITH CHECK CHECK CONSTRAINT [CK_EmailRecipientType];

PRINT N'Adding Lookup Data for smtp auto discovery'

EXEC dbo.Implementation_RefreshLookupData

PRINT N'Adding Hangfire Schema';

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE [name] = 'HangFire') EXEC ('CREATE SCHEMA [HangFire]')

PRINT N'Db initialization complete.';

'@
Apply-SqlMigration $emailServerConnectionString "Manual Email schema population" $sqlMigrationTestQuery1 $sqlMigrationQuery1
