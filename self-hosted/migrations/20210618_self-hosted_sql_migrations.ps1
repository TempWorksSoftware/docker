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

$additionalScopes = @(@{ApiResourceId = 1; Description = "Allow read access to External Service Administration"; DisplayName = "External Service Read"; Emphasize = 0; Name = "externalservice-read"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow write access to External Service Administration"; DisplayName = "External Service Write"; Emphasize = 0; Name = "externalservice-write"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read and write access to WebCenter Job Board Administration"; DisplayName = "Job Board Admin"; Emphasize = 0; Name = "jobboard-admin"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow Resume Parser access"; DisplayName = "Resume Parser"; Emphasize = 0; Name = "resumeparser"; Required = 0; ShowInDiscoveryDocument = 1; },
                      @{ApiResourceId = 1; Description = "Allow write access to Security Groups"; DisplayName = "Security Group Write"; Emphasize = 0; Name = "securitygroup-write"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read access to Service Rep Tokens"; DisplayName = "Service Rep Token Read"; Emphasize = 0; Name = "servicereptoken-read"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read and write access to Service Rep Tokens"; DisplayName = "Service Rep Token Write"; Emphasize = 0; Name = "servicereptoken-write"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read access to Tasks"; DisplayName = "Task Read"; Emphasize = 0; Name = "task-read"; Required = 0; ShowInDiscoveryDocument = 1; },
                      @{ApiResourceId = 1; Description = "Allow read and write access to Tasks"; DisplayName = "Task Write"; Emphasize = 0; Name = "task-write"; Required = 0; ShowInDiscoveryDocument = 1; },
                      @{ApiResourceId = 1; Description = "Allow write access to Team Settings"; DisplayName = "Team Settings Write"; Emphasize = 0; Name = "team-settings-write"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read access to Employee Timeclock Punch Assignments"; DisplayName = "Timeclock Read"; Emphasize = 0; Name = "timeclock-read"; Required = 0; ShowInDiscoveryDocument = 1; },
                      @{ApiResourceId = 1; Description = "Allow write access to Employee Timeclock Punching"; DisplayName = "Timeclock Write"; Emphasize = 0; Name = "timeclock-write"; Required = 0; ShowInDiscoveryDocument = 1; },
                      @{ApiResourceId = 1; Description = "TW Browser Extension Sidebar access"; DisplayName = "TW Browser Extension Sidebar access"; Emphasize = 0; Name = "tw-browser-ext-sidebar-access"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow read access to Vendors"; DisplayName = "Vendor Read"; Emphasize = 0; Name = "vendor-read"; Required = 0; ShowInDiscoveryDocument = 0; },
                      @{ApiResourceId = 1; Description = "Allow write access to Vendors"; DisplayName = "Vendor Write"; Emphasize = 0; Name = "vendor-write"; Required = 0; ShowInDiscoveryDocument = 0; })

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
