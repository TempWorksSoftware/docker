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

$Tenants_IUTrig_Create = @"
        CREATE TRIGGER dbo.Tenants_IUTrig
        ON dbo.Tenants
        FOR INSERT, UPDATE
        AS
        BEGIN
            DECLARE @InvalidCharsPattern NVARCHAR(20) = N'%[^a-z0-9-]%';
            DECLARE @TopInvalidTenantName NVARCHAR(255);
            DECLARE @TopInvalidExistingTenantName NVARCHAR(255);
            DECLARE @ErrorMessage NVARCHAR(2000);

            DECLARE @deleted INT, @inserted INT;

            SELECT @deleted = COUNT(*) FROM Deleted
            SELECT @inserted = COUNT(*) FROM Inserted

            DECLARE @isInsert BIT
            SELECT @isInsert = CASE WHEN @inserted > 0 AND @deleted = 0 THEN 1 
				        ELSE 0
				        END
            IF (UPDATE (Name) OR @isInsert = 1) 
	        BEGIN
                --Tenant name must be all lowercase alphanumeric characters and dashes.
                SELECT      TOP 1
                            @TopInvalidTenantName = i.[Name]
                FROM        Inserted i
                WHERE       i.[Name] <> LOWER(i.[Name])COLLATE SQL_Latin1_General_CP1_CS_AS
                            OR  i.[Name] = N''
                            OR  i.[Name] LIKE @InvalidCharsPattern
                ORDER BY    i.[Name];

                IF @TopInvalidTenantName IS NOT NULL
                BEGIN
                    SET @ErrorMessage
                        = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' contains invalid characters. Must be all lowercased alphanumberic characters or dashes.');
                    THROW 50000, @ErrorMessage, 1;
                END;


                -- Prevent naming conflicts between tenant names like my_tenant and my-tenant
                SELECT      TOP 1
                            @TopInvalidTenantName = i.[Name],
                            @TopInvalidExistingTenantName = t.[Name]
                FROM        dbo.Tenants t
                            INNER JOIN Inserted i ON REPLACE(t.[Name], '_', '-') = i.[Name]
                                                     AND   t.[Name] <> i.[Name]
                ORDER BY    i.[Name];

                IF @TopInvalidTenantName IS NOT NULL
                BEGIN
                    SET @ErrorMessage
                        = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' will create a name conflict with the existing Tenant ', @TopInvalidExistingTenantName);
                    THROW 50000, @ErrorMessage, 1;
                END;
	        END;
        END;
"@;
$Tenants_IUTrig_Test = @"
SELECT 1 FROM sys.sql_modules sm
JOIN sys.objects o ON sm.object_id = o.object_id
WHERE o.name = 'Tenants_IUTrig' and REPLACE(REPLACE(REPLACE(sm.definition, CHAR(13), ''), CHAR(10), ''), CHAR(7), '') = REPLACE(REPLACE(REPLACE('$($Tenants_IUTrig_Create -replace "'", "''")', CHAR(13), ''), CHAR(10), ''), CHAR(7), '')
"@;

$SubTenants_IUTrig_Create = @"
        CREATE TRIGGER dbo.SubTenants_IUTrig
        ON dbo.SubTenants
        FOR INSERT, UPDATE
        AS
        BEGIN
            DECLARE @InvalidCharsPattern NVARCHAR(20) = N'%[^a-z0-9-]%';
            DECLARE @TopInvalidTenantName NVARCHAR(255);
            DECLARE @TopInvalidExistingTenantName NVARCHAR(255);
            DECLARE @ErrorMessage NVARCHAR(2000);

            DECLARE @deleted INT, @inserted INT;

            SELECT @deleted = COUNT(*) FROM Deleted
            SELECT @inserted = COUNT(*) FROM Inserted

            DECLARE @isInsert BIT
            SELECT @isInsert = CASE WHEN @inserted > 0 AND @deleted = 0 THEN 1 
				        ELSE 0
				        END
            IF (UPDATE (Name) OR @isInsert = 1) 
	        BEGIN
                --Tenant name must be all lowercase alphanumeric characters and dashes.
                SELECT      TOP 1
                            @TopInvalidTenantName = i.[Name]
                FROM        Inserted i
                WHERE       i.[Name] <> LOWER(i.[Name])COLLATE SQL_Latin1_General_CP1_CS_AS
                            OR  i.[Name] = N''
                            OR  i.[Name] LIKE @InvalidCharsPattern
                ORDER BY    i.[Name];

                IF @TopInvalidTenantName IS NOT NULL
                BEGIN
                    SET @ErrorMessage
                        = CONCAT(
                                    N'The SubTenant named ', @TopInvalidTenantName,
                                    N' contains invalid characters. Must be all lowercased alphanumberic characters or dashes.'
                                );
                    THROW 50000, @ErrorMessage, 1;
                END;


                -- Prevent naming conflicts between subtenant names like subtenant_1 and subtenant-1.
	            -- This naming conflict is only checked within same parent tenant.
                SELECT      TOP 1
                            @TopInvalidTenantName = i.[Name],
                            @TopInvalidExistingTenantName = t.[Name]
                FROM        dbo.SubTenants t
                            INNER JOIN Inserted i ON REPLACE(t.[Name], '_', '-') = i.[Name]
                                                     AND   t.[Name] <> i.[Name]
                                                     AND   t.TenantId = i.TenantId
                ORDER BY    i.[Name];

                IF @TopInvalidTenantName IS NOT NULL
                BEGIN
                    SET @ErrorMessage
                        = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' will create a name conflict with the existing Tenant ', @TopInvalidExistingTenantName);
                    THROW 50000, @ErrorMessage, 1;
                END;
            END;
        END;
"@;
$SubTenants_IUTrig_Test = @"
SELECT 1 FROM sys.sql_modules sm
JOIN sys.objects o ON sm.object_id = o.object_id
WHERE o.name = 'SubTenants_IUTrig' and REPLACE(REPLACE(REPLACE(sm.definition, CHAR(13), ''), CHAR(10), ''), CHAR(7), '') = REPLACE(REPLACE(REPLACE('$($SubTenants_IUTrig_Create -replace "'", "''")', CHAR(13), ''), CHAR(10), ''), CHAR(7), '')
"@;

$loginServerUpdates = @(
    @{
        Description = "Update Tenants_IUTrig to only apply name error checking for inserts and updates to the name column.";
        Test = $Tenants_IUTrig_Test;
        Migrate = @('DROP TRIGGER IF EXISTS dbo.Tenants_IUTrig', $Tenants_IUTrig_Create);
	},
    @{
        Description = "Update SubTenants_IUTrig to only apply name error checking for inserts and updates to the name column.";
        Test = $SubTenants_IUTrig_Test;
        Migrate = @('DROP TRIGGER IF EXISTS dbo.SubTenants_IUTrig', $SubTenants_IUTrig_Create);
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
