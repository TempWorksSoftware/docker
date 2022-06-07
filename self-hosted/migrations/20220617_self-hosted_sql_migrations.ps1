[CmdletBinding(SupportsShouldProcess)]
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

        if ($PSCmdlet.ShouldProcess($description)) {
            try {                        
                Execute-SqlQuery $connectionString $updateQuery
                Write-Host " SUCCEEDED." -foregroundcolor green
            } catch [Exception] {
g                Write-Host " FAILED." -foregroundcolor red
                Write-Error -Message "Could not apply SQL migration"
                Write-Error -Exception $_.Exception
                Write-Host "Consider applying this SQL migration manually:"
                Write-Host "----------------------------------------"
                write-host $updateQuery
                Write-Host "----------------------------------------"
                Write-Error -Message "Could not apply SQL migration"
                Write-Error -Exception $_.Exception
            }
        } else {

        }
    }
}

$loginServerUpdates = @(
    @{
        Description = "Create Tenants_IUTrig"
        Test = @"
SELECT	1 
FROM	sys.triggers
WHERE	[name] = 'Tenants_IUTrig'
"@
        Migrate = @"
CREATE TRIGGER dbo.Tenants_IUTrig
ON dbo.Tenants
FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @InvalidCharsPattern NVARCHAR(20) = N'%[^a-z0-9-]%'
    DECLARE @TopInvalidTenantName NVARCHAR(255)
    DECLARE @TopInvalidExistingTenantName NVARCHAR(255)
    DECLARE @ErrorMessage NVARCHAR(2000)

    --Tenant name must be all lowercase alphanumeric characters and dashes.
    SELECT      TOP 1
                @TopInvalidTenantName = i.[Name]
    FROM        Inserted i
    WHERE       i.[Name] <> LOWER(i.[Name])COLLATE SQL_Latin1_General_CP1_CS_AS
                OR  i.[Name] = N''
                OR  i.[Name] LIKE @InvalidCharsPattern
    ORDER BY    i.[Name]

    IF @TopInvalidTenantName IS NOT NULL
    BEGIN
        SET @ErrorMessage
            = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' contains invalid characters. Must be all lowercased alphanumberic characters or dashes.')
        THROW 50000, @ErrorMessage, 1
    END


    -- Prevent naming conflicts between tenant names like my_tenant and my-tenant
    SELECT      TOP 1
                @TopInvalidTenantName = i.[Name],
                @TopInvalidExistingTenantName = t.[Name]
    FROM        dbo.Tenants t
                INNER JOIN Inserted i ON REPLACE(t.[Name], '_', '-') = i.[Name]
                                         AND   t.[Name] <> i.[Name]
    ORDER BY    i.[Name]

    IF @TopInvalidTenantName IS NOT NULL
    BEGIN
        SET @ErrorMessage
            = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' will create a name conflict with the existing Tenant ', @TopInvalidExistingTenantName)
        THROW 50000, @ErrorMessage, 1
    END
END
GO
"@
    },
	@{
		Description = "Create SubTenants_IUTrig"
		Test = @"
SELECT	1 
FROM	sys.triggers
WHERE	[name] = 'SubTenants_IUTrig'
"@
		Migrate = @"
CREATE TRIGGER dbo.SubTenants_IUTrig
ON dbo.SubTenants
FOR INSERT, UPDATE
AS
BEGIN
    DECLARE @InvalidCharsPattern NVARCHAR(20) = N'%[^a-z0-9-]%'
    DECLARE @TopInvalidTenantName NVARCHAR(255)
    DECLARE @TopInvalidExistingTenantName NVARCHAR(255)
    DECLARE @ErrorMessage NVARCHAR(2000)

    --Tenant name must be all lowercase alphanumeric characters and dashes.
    SELECT      TOP 1
                @TopInvalidTenantName = i.[Name]
    FROM        Inserted i
    WHERE       i.[Name] <> LOWER(i.[Name])COLLATE SQL_Latin1_General_CP1_CS_AS
                OR  i.[Name] = N''
                OR  i.[Name] LIKE @InvalidCharsPattern
    ORDER BY    i.[Name]

    IF @TopInvalidTenantName IS NOT NULL
    BEGIN
        SET @ErrorMessage
            = CONCAT(
                        N'The SubTenant named ', @TopInvalidTenantName,
                        N' contains invalid characters. Must be all lowercased alphanumberic characters or dashes.'
                    )
        THROW 50000, @ErrorMessage, 1
    END


    -- Prevent naming conflicts between subtenant names like subtenant_1 and subtenant-1.
	-- This naming conflict is only checked within same parent tenant.
    SELECT      TOP 1
                @TopInvalidTenantName = i.[Name],
                @TopInvalidExistingTenantName = t.[Name]
    FROM        dbo.SubTenants t
                INNER JOIN Inserted i ON REPLACE(t.[Name], '_', '-') = i.[Name]
                                         AND   t.[Name] <> i.[Name]
                                         AND   t.TenantId = i.TenantId
    ORDER BY    i.[Name]

    IF @TopInvalidTenantName IS NOT NULL
    BEGIN
        SET @ErrorMessage
            = CONCAT(N'The Tenant named ', @TopInvalidTenantName, N' will create a name conflict with the existing Tenant ', @TopInvalidExistingTenantName)
        THROW 50000, @ErrorMessage, 1
    END
END
GO  		
"@
	}
)

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
