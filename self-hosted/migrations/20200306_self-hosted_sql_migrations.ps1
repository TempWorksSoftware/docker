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

$sqlMigrationTestQuery1 = @'
SELECT 1 from dbo.ApiScopes WHERE name='backgroundcheck-webhook'
'@
$sqlMigrationQuery1 = @'

IF NOT EXISTS (SELECT 1 from dbo.ApiScopes WHERE name='backgroundcheck-webhook')
BEGIN
PRINT N'Inserting ApiScope...';

INSERT dbo.ApiScopes ( ApiResourceId ,
                        Description ,
                        DisplayName ,
                        Emphasize ,
                        Name ,
                        Required ,
                        ShowInDiscoveryDocument )
VALUES ( 1,
         N'Allow write access to Background Checks Webhooks',
         N'Background Check Webhook',
         0,
         N'backgroundcheck-webhook',
         0,
         0
    )
END

'@
Apply-SqlMigration $loginServerConnectionString "Add backgroundcheck-webhook ApiScope to login database" $sqlMigrationTestQuery1 $sqlMigrationQuery1

$sqlMigrationTestQuery2 = @'
SELECT 1 from dbo.ApiScopes WHERE name='textmessage-write'
'@
$sqlMigrationQuery2 = @'

IF NOT EXISTS (SELECT 1 from dbo.ApiScopes WHERE name='textmessage-write')
BEGIN
PRINT N'Inserting ApiScope...';

INSERT INTO ApiScopes (ApiResourceId, Description, DisplayName, Emphasize, Name, Required, ShowInDiscoveryDocument)
VALUES (1, 'Allow write access to Text Message data', 'Text Message Write', 0, 'textmessage-write', 0, 1)
END

'@
Apply-SqlMigration $loginServerConnectionString "Add textmessage-write ApiScope to login database" $sqlMigrationTestQuery2 $sqlMigrationQuery2

$sqlMigrationTestQuery3 = @'
SELECT 1 from dbo.ApiScopes WHERE name='textmessage-read'
'@
$sqlMigrationQuery3 = @'

IF NOT EXISTS (SELECT 1 from dbo.ApiScopes WHERE name='textmessage-read')
BEGIN
PRINT N'Inserting ApiScope...';

INSERT INTO ApiScopes (ApiResourceId, Description, DisplayName, Emphasize, Name, Required, ShowInDiscoveryDocument)
VALUES (1, 'Allow read access to Text Message data', 'Text Message Read', 0, 'textmessage-read', 0, 1)
END

'@
Apply-SqlMigration $loginServerConnectionString "Add textmessage-read ApiScope to login database" $sqlMigrationTestQuery3 $sqlMigrationQuery3

$sqlMigrationTestQuery4 = @'
SELECT 1 from dbo.ApiScopes WHERE name='textmessage-webhook'
'@
$sqlMigrationQuery4 = @'

IF NOT EXISTS (SELECT 1 from dbo.ApiScopes WHERE name='textmessage-webhook')
BEGIN
PRINT N'Inserting ApiScope...';

INSERT INTO ApiScopes (ApiResourceId, Description, DisplayName, Emphasize, Name, Required, ShowInDiscoveryDocument)
VALUES (1, 'Allow webhook access for Text Message Vendors', 'Text Message Webhook', 0, 'textmessage-webhook', 0, 0)
END

'@
Apply-SqlMigration $loginServerConnectionString "Add textmessage-webhook ApiScope to login database" $sqlMigrationTestQuery4 $sqlMigrationQuery4
