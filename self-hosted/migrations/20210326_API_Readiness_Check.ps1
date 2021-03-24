Param (
    # Path to the login-server configuration directory (containing appsettings.json files)
    [string]
    $loginServer = "C:\ProgramData\TempWorks\config\login-server"
)

Begin {
    if (!(Test-Path $loginServer)) {
        Throw "Login Server service config directory ($($loginServer) not found!"
    }
}

Process {

$loginAppsettingsPath = $loginServer+'\appsettings.production.json'

$loginServerConnectionString = (Get-Content ($loginAppsettingsPath) -ErrorAction stop | Out-String |ConvertFrom-Json).ConnectionStrings.TwLoginServerDatabase

function Execute-SqlQuery {
    param([string]$connectionString, [string]$query)
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

$tenantQuery = 'SELECT [Name], [ConnectionString] from [dbo].[Tenants]';
$tenantResults = Execute-SqlQuery -ConnectionString $loginServerConnectionString -Query $tenantQuery

$testPermissionQuery = @"
EXEC sp_set_session_context 'SRIdent', 101

SELECT SESSION_CONTEXT(N'SRIdent') AS SRIdent
"@
$permissionChecksFailed = $false;
$tenantResults.Table | Select-Object -Unique Name,ConnectionString | ForEach-Object {
    $tenantConnectionString = $_.ConnectionString
     Write-Host "Testing tenant '$($_.Name)'..." -NoNewline

     $testResult = $null;
     try {                      
         $testResult = Execute-SqlQuery -connectionString $tenantConnectionString -query $testPermissionQuery
         Write-Host " SUCCEEDED." -foregroundcolor green
     } catch [Exception] {
         $permissionChecksFailed = $true;

         $connectionParams = New-Object System.Data.SqlClient.SqlConnectionStringBuilder -argumentlist $tenantConnectionString

         Write-Host $testResult
         Write-Host " FAILED" -foregroundcolor red -NoNewline
         Write-Host " for user '$($connectionParams["User ID"]) and database '$($connectionParams["Data Source"])'."
         Write-Host "$($_.Exception.GetType().FullName) exception encountered while attempting this operation."
    }
}

if ($permissionChecksFailed) {
    Write-Host @"
SQL User(s) lacks sufficient permissions to set session context.
    
Ensure that the SQL users in connection strings listed above hav been granted 'SPSetSessionContext' for the respective databases and re-run this readiness script.  Alternatively you may run the following SQL as the target user to verify these permissions manually:
------------------------------
$($testPermissionQuery)
------------------------------

Contact TempWorks support if your require additional assistance.

"@
}
}
