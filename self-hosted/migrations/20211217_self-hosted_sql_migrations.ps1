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


$sqlMigrationTestQuery1 = "SELECT 1 FROM sysobjects WHERE name = 'CHK_ExternalIdentityProviderName'"
$sqlMigrationQuery1 = @"
ALTER TABLE dbo.ExternalIdentityProvider
ADD CONSTRAINT CHK_ExternalIdentityProviderName
CHECK (NOT ExternalIdentityProviderName LIKE '%[^A-Z0-9]%')
"@
Apply-SqlMigration $loginServerConnectionString "Adding ExternalIdentityProviderName constraint..." $sqlMigrationTestQuery1 $sqlMigrationQuery1

$sqlMigrationTestQuery2 = "SELECT 1 FROM ClientScopes where Scope like 'tw-webats-access'"
$sqlMigrationQuery2 = @"
INSERT ClientScopes (ClientId, Scope)
	SELECT
		c.Id AS ClientId,
		'tw-webats-access' AS Scope
	FROM Clients c
	LEFT JOIN ClientScopes cs ON cs.ClientId = c.Id AND cs.Scope = 'tw-webats-access'
	WHERE c.ClientId IN ('webats', 'webats-development', 'webats-staging')
	AND cs.Scope IS NULL
"@
Apply-SqlMigration $loginServerConnectionString "Adding tw-webats-access ClientScope..." $sqlMigrationTestQuery2 $sqlMigrationQuery2

$sqlMigrationTestQuery3 = "SELECT 1 FROM ApiScopes WHERE Name = 'tw-webats-access'"
$sqlMigrationQuery3 = @"
INSERT ApiScopes
(
	ApiResourceId,
	Description,
	DisplayName,
	Emphasize,
	Name,
	Required,
	ShowInDiscoveryDocument
)
SELECT
	1,
	'TW WebATS access',
	'TW WebATS access',
	0,
	'tw-webats-access',
	0,
	0
"@
Apply-SqlMigration $loginServerConnectionString "Adding tw-webats-access ApiScope..." $sqlMigrationTestQuery3 $sqlMigrationQuery3
