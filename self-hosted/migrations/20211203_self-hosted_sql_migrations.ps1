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


$sqlMigrationTestQuery1 = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExternalIdentityProvider]') AND type in (N'U')"

$sqlMigrationQuery1 = @"
CREATE TABLE [dbo].[ExternalIdentityProvider]
    (
        ExternalIdentityProviderId BIGINT NOT NULL IDENTITY PRIMARY KEY,
        ExternalIdentityProviderName NVARCHAR(100) NOT NULL UNIQUE,
        AuthorityUrl NVARCHAR(1000) NULL,
		ClientId NVARCHAR(1000) NULL,
		ClientSecret VARBINARY(MAX) NULL,
		Claim NVARCHAR(100) NULL,
		LogoutUrl NVARCHAR(1000) NULL,
		IsActive BIT NOT NULL,
		BypassTenantRestrictions BIT NOT NULL DEFAULT 0
    );
"@
Apply-SqlMigration $loginServerConnectionString "Creating [dbo].[ExternalIdentityProvider]..." $sqlMigrationTestQuery1 $sqlMigrationQuery1

$sqlMigrationTestQuery2 = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SsoDomains]') AND type in (N'U')"

$sqlMigrationQuery2 = @"
CREATE TABLE [dbo].[SsoDomains]
    (
        SsoDomainId BIGINT NOT NULL IDENTITY PRIMARY KEY,
        Domain NVARCHAR(255) NOT NULL,
		OwnedByTenantId INT NOT NULL FOREIGN KEY REFERENCES dbo.Tenants (TenantId),
        ExternalIdentityProviderId BIGINT NULL FOREIGN KEY REFERENCES dbo.ExternalIdentityProvider (ExternalIdentityProviderId)
    );
"@

Apply-SqlMigration $loginServerConnectionString "Creating [dbo].[SsoDomains]..." $sqlMigrationTestQuery2 $sqlMigrationQuery2

$sqlMigrationTestQuery3 = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TenantSsoDomains]') AND type in (N'U')"
$sqlMigrationQuery3 = @"
CREATE TABLE [dbo].[TenantSsoDomains]
    (
        TenantDomainId BIGINT NOT NULL IDENTITY PRIMARY KEY,
        TenantId INT NOT NULL REFERENCES dbo.Tenants (TenantId),
        SsoDomainId BIGINT NOT NULL REFERENCES dbo.SsoDomains (SsoDomainId)
    );
"@
Apply-SqlMigration $loginServerConnectionString "Creating [dbo].[TenantSsoDomains]..." $sqlMigrationTestQuery3 $sqlMigrationQuery3
