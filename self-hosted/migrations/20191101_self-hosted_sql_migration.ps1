param (
    # Path to the login-server configuration directory
    [string]$loginServer = "C:\ProgramData\TempWorks\config\login-server"
)

$loginServerConnectionString = (Get-Content ($loginServer+'\appsettings.production.json') | Out-String |ConvertFrom-Json).ConnectionStrings.TwLoginServerDatabase

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
        }
    }
}

$sqlMigrationTestQuery1 = @'
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SubTenants]') AND type in (N'U')
'@
$sqlMigrationQuery1 = @'
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SubTenants]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SubTenants](
	[SubTenantId] [INT] IDENTITY(1000,1) NOT NULL,
	[TenantId] [INT] NOT NULL,
	[Name] [NVARCHAR](255) NOT NULL,
	[Description] [NVARCHAR](1000) NOT NULL,
	[ConnectionString] [NVARCHAR](1000) NOT NULL,
	[ProviderName] [NVARCHAR](255) NOT NULL,
	[LogoUrl] [NVARCHAR](1000) NULL,
	[SortOrder] [INT] NOT NULL,
 CONSTRAINT [PK_SubTenants] PRIMARY KEY CLUSTERED 
(
	[SubTenantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SubTenants_ProviderName]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SubTenants] ADD  CONSTRAINT [DF_SubTenants_ProviderName]  DEFAULT ('System.Data.SqlClient') FOR [ProviderName]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SubTenants_SortOrder]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SubTenants] ADD  CONSTRAINT [DF_SubTenants_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SubTenants_Tenants]') AND parent_object_id = OBJECT_ID(N'[dbo].[SubTenants]'))
BEGIN
ALTER TABLE [dbo].[SubTenants]  WITH CHECK ADD  CONSTRAINT [FK_SubTenants_Tenants] FOREIGN KEY([TenantId])
REFERENCES [dbo].[Tenants] ([TenantId])
END

ALTER TABLE [dbo].[SubTenants] CHECK CONSTRAINT [FK_SubTenants_Tenants]
'@
Apply-SqlMigration $loginServerConnectionString "Create SubTenants table" $sqlMigrationTestQuery1 $sqlMigrationQuery1

$sqlMigrationTestQuery2 = "Select * From ApiScopes WHERE Name Like 'report-read'"
$sqlMigrationQuery2 = @'
INSERT [dbo].[ApiScopes] ([ApiResourceId], [Description], [DisplayName], [Emphasize], [Name], [Required], [ShowInDiscoveryDocument])
VALUES (1, N'Allow read access to Reports, Exports, and Insight Widgets', N'Report Read', 0, N'report-read', 0, 1)
'@
Apply-SqlMigration $loginServerConnectionString "Create report-read API scope" $sqlMigrationTestQuery2 $sqlMigrationQuery2
