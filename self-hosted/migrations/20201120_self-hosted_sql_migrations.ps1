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
SELECT 1 from dbo.ApiScopes WHERE name='backgroundcheck-read'
'@
$sqlMigrationQuery1 = @'
INSERT dbo.ApiScopes ( ApiResourceId ,
                        Description ,
                        DisplayName ,
                        Emphasize ,
                        Name ,
                        Required ,
                        ShowInDiscoveryDocument )
SELECT 1 ,
                     'Allows reading of Background Check related data' ,
                     'Background Check Read' ,
                     0 ,
                     'backgroundcheck-read' ,
                     0 ,
                     1
'@
Apply-SqlMigration $loginServerConnectionString "Add backgroundcheck-read ApiScope to login database" $sqlMigrationTestQuery1 $sqlMigrationQuery1

$sqlMigrationTestQuery2 = @'
SELECT 1 from dbo.ApiScopes WHERE name='backgroundcheck-write'
'@
$sqlMigrationQuery2 = @'
INSERT dbo.ApiScopes ( ApiResourceId ,
                        Description ,
                        DisplayName ,
                        Emphasize ,
                        Name ,
                        Required ,
                        ShowInDiscoveryDocument )
SELECT 1 ,
                     'Allows writing access to Background Checks' ,
                     'Background Check Write' ,
                     0 ,
                     'backgroundcheck-write' ,
                     0 ,
                     1
'@
Apply-SqlMigration $loginServerConnectionString "Add backgroundcheck-write ApiScope to login database" $sqlMigrationTestQuery2 $sqlMigrationQuery2
