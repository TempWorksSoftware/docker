param (
    # Path to the api-email-server configuration directory
    [ValidateScript(
         {
             if (-Not (Test-Path -Path $_)) {
                 throw "Email Server service config directory ($_) not found!"
             }
             return $true
         })]
    [string]
    $apiEmailServer = $(
        if (-Not (Test-Path -Path "C:\ProgramData\TempWorks\config\api-email-server")) {
            throw "Email Server service config directory (C:\ProgramData\TempWorks\config\api-email-server) not found!"
        }
        return "C:\ProgramData\TempWorks\config\api-email-server"
    )
)

$appsettingsPath = $apiEmailServer+'\appsettings.production.json'

$emailServerConnectionString = (Get-Content ($appsettingsPath) -ErrorAction stop | Out-String |ConvertFrom-Json).ConnectionStrings.EmailDatabase

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

write-host "Connection string: " + $emailServerConnectionString

$sqlMigrationTestQuery1 = @'
SELECT * FROM sys.columns AS c
INNER JOIN sys.tables AS t ON t.object_id = c.object_id
WHERE t.object_id = OBJECT_ID(N'[dbo].[Email]') AND type in (N'U')
AND c.name = 'RetryCount'
'@
$sqlMigrationQuery1 = @'
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
ALTER TABLE [dbo].[Email]
ADD RetryCount INT NULL
'@
Apply-SqlMigration $emailServerConnectionString "Email schema change" $sqlMigrationTestQuery1 $sqlMigrationQuery1