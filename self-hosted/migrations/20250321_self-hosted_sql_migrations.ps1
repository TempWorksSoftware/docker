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
    if ($testResult.Table.Column1) {
        Write-Host "'$description' already applied." -foregroundcolor green
    } else {
        Write-Host "Applying '$description'..." -NoNewline
        try {                        
            $updateQuery | ForEach-Object { Execute-SqlQuery $connectionString $_ }
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

$testQuery1 = @"
    SELECT 1
    FROM [dbo].[ClientScopes]
    WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'hrcenter') AND Scope = 'tenant-read'
"@;

$sqlMigrationQuery1 = @"
    INSERT INTO [dbo].[ClientScopes] (ClientId, Scope)
    VALUES ((SELECT Id FROM Clients WHERE ClientId = 'hrcenter'), 'tenant-read')
"@;

Apply-SqlMigration $loginServerConnectionString "Add tenant-read clientscope record for HRCenter client. [WI 99591]" $testQuery1 $sqlMigrationQuery1
    
