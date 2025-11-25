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

# Migration 1: Create OSTCInviteCodes table
$testQueryOSTCTable = @"
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo'
        AND TABLE_NAME = 'OSTCInviteCodes'
"@

$sqlMigrationOSTCTable = @"
    CREATE TABLE dbo.OSTCInviteCodes (
        Id int IDENTITY(1,1) PRIMARY KEY, 
        ProductInstanceId uniqueidentifier NOT NULL,
        InviteCode nvarchar(100) NOT NULL,
        CustomerId uniqueidentifier NOT NULL,
        TenantName nvarchar(255) NOT NULL,
        WorksiteId uniqueidentifier NOT NULL,
        IncludeChildDepartments bit NOT NULL DEFAULT 0,
        DateCreated datetime2 NOT NULL DEFAULT GETUTCDATE(),
        CreatedBy nvarchar(255) NOT NULL,
        DateRevoked datetime2 NULL,
        RevokedBy nvarchar(255) NULL,
        LastModified datetime2 NULL,
        LastModifiedBy nvarchar(255) NULL
    )
"@

# Migration 2: Create indexes for OSTCInviteCodes table
$testQueryOSTCIndexes = @"
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_OSTCInviteCodes_InviteCode'
        AND object_id = OBJECT_ID('dbo.OSTCInviteCodes')
"@

$sqlMigrationOSTCIndexes = @(
    @"
    CREATE UNIQUE NONCLUSTERED INDEX IX_OSTCInviteCodes_InviteCode 
    ON dbo.OSTCInviteCodes (InviteCode);
"@,
    @"
    CREATE NONCLUSTERED INDEX IX_OSTCInviteCodes_ProductInstanceId 
    ON dbo.OSTCInviteCodes (ProductInstanceId);
"@,
    @"
    CREATE NONCLUSTERED INDEX IX_OSTCInviteCodes_TenantName 
    ON dbo.OSTCInviteCodes (TenantName);
"@,
    @"
    CREATE NONCLUSTERED INDEX IX_OSTCInviteCodes_Customer_Worksite 
    ON dbo.OSTCInviteCodes (CustomerId, WorksiteId);
"@
)

Apply-SqlMigration $loginServerConnectionString "Create OSTCInviteCodes table for OnSite TimeClock invite codes. [WI 137000]" $testQueryOSTCTable $sqlMigrationOSTCTable
Apply-SqlMigration $loginServerConnectionString "Create indexes for OSTCInviteCodes table. [WI 137000]" $testQueryOSTCIndexes $sqlMigrationOSTCIndexes
