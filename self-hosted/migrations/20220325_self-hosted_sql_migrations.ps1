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
        } else {

        }
    }
}

$loginServerUpdates = @(
    @{
        Description = "Add RequireSsoLogin to Tenants table";
        Test = @"
SELECT 1 FROM sys.columns 
    WHERE Name = N'RequireSsoLogin'
    AND Object_ID = Object_ID(N'dbo.Tenants')
"@;
        Migrate = @"
ALTER TABLE dbo.[Tenants]
ADD [RequireSsoLogin] BIT NOT NULL DEFAULT (0);
"@;
    },
    @{
        Description = "Add UseExternalUserIdentifier to ExternalIdentityProvider table";
        Test = @"
SELECT 1 FROM sys.columns 
    WHERE Name = N'UseExternalUserIdentifier'
    AND Object_ID = Object_ID(N'dbo.ExternalIdentityProvider')
"@;
        Migrate = @"
ALTER TABLE dbo.[ExternalIdentityProvider]
ADD [UseExternalUserIdentifier] BIT NOT NULL DEFAULT (0);
"@;
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}