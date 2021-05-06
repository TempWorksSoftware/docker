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

$additionalScopes = @(@{ApiResourceId = 1; Description = "Allow access to read legal acknowledgements."; DisplayName = "Legal Read"; Emphasize = 0; Name = "legal-read"; Required = 0; ShowInDiscoveryDocument = 0;},
                      @{ApiResourceId = 1; Description = "Allow access to write legal acknowledgements."; DisplayName = "Legal Write"; Emphasize = 0; Name = "legal-write"; Required = 0; ShowInDiscoveryDocument = 0;},
                      @{ApiResourceId = 1; Description = "Allow write access to Payroll, Paycard Funding, and Paycard Enrollment"; DisplayName = "Payroll Write"; Emphasize = 0; Name = "payroll-write"; Required = 0; ShowInDiscoveryDocument = 1;})

$additionalScopes | % {
    $sqlMigrationTestQuery = @"
SELECT 1 from dbo.ApiScopes WHERE name LIKE '$($_.Name)'
"@
    $sqlMigrationQuery = @"
IF NOT EXISTS (SELECT 1 from dbo.ApiScopes WHERE name LIKE '$($_.Name)')
BEGIN
PRINT N'Inserting ApiScope "$($_.Name)"...';

INSERT INTO ApiScopes (ApiResourceId, Description, DisplayName, Emphasize, Name, Required, ShowInDiscoveryDocument)
VALUES ($($_.ApiResourceId), '$($_.Description)', '$($_.DisplayName)', $($_.Emphasize), '$($_.Name)', $($_.Required), $($_.ShowInDiscoveryDocument))
END

"@
    Apply-SqlMigration $loginServerConnectionString "Add $($_.Name) ApiScope to login database" $sqlMigrationTestQuery $sqlMigrationQuery
}
