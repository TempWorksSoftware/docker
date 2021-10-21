param (
    # Path to the api-server configuration directory
    [ValidateScript(
         {
             if (-Not (Test-Path -Path $_)) {
                 throw "API Server service config directory ($_) not found!"
             }
             return $true
         })]
    [string]
    $apiServer = $(
        if (-Not (Test-Path -Path "C:\ProgramData\TempWorks\config\api-server")) {
            throw "API Server service config directory (C:\ProgramData\TempWorks\config\api-server) not found!"
        }
        return "C:\ProgramData\TempWorks\config\api-server"
    )
)

$appsettingsPath = $apiServer+'\appsettings.production.json'

$rebusConnectionString = (Get-Content ($appsettingsPath) -ErrorAction stop | Out-String |ConvertFrom-Json).ConnectionStrings.RebusDatabase

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

$sqlMigrationTestQuery = @"
SELECT *
FROM
    sys.indexes ind 
        INNER JOIN sys.index_columns ic ON  ind.object_id = ic.object_id and ind.index_id = ic.index_id
        INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id
WHERE
    ind.is_primary_key = 0 -- Not a Primary Key
        AND ind.is_disabled = 0 -- Is Enabled
        AND ind.[name] = 'IDX_RECEIVE_rebus_TwApi_JobService_DefaultQueue' -- Index Name
        AND col.[name] = 'priority' -- Index column we're interested in
        AND ic.is_descending_key = 1 -- Order By is ASC
"@
$sqlMigrationQuery = @"
DROP INDEX [IDX_RECEIVE_rebus_TwApi_JobService_DefaultQueue] ON [rebus].[TwApi_JobService_DefaultQueue]

CREATE NONCLUSTERED INDEX [IDX_RECEIVE_rebus_TwApi_JobService_DefaultQueue] ON [rebus].[TwApi_JobService_DefaultQueue]
(
        [priority] DESC,
        [visible] ASC,
        [id] ASC,
        [expiration] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
"@
Apply-SqlMigration $rebusConnectionString "Update TwApi_JobService_DefaultQueue index" $sqlMigrationTestQuery $sqlMigrationQuery
