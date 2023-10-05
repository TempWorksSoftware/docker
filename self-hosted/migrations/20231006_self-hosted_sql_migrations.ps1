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

$loginServerUpdates = @(
    @{
        Description = "Remove defunct tables";
        Test = @"
        SELECT
	        CASE 
		        WHEN
			        EXISTS (
				        SELECT 1 
				        FROM sys.objects 
				        WHERE object_id 
					        IN (
						        OBJECT_ID(N'[dbo].[ApiClaims]'),
						        OBJECT_ID(N'[dbo].[ApiProperties]'),
						        OBJECT_ID(N'[dbo].[ApiSecrets]'),
						        OBJECT_ID(N'[dbo].[IdentityClaims]'),
						        OBJECT_ID(N'[dbo].[IdentityProperties]')
					        )
					        AND type = N'U'
			        )
			        AND EXISTS (
				        SELECT 1
				        FROM sys.columns
				        WHERE Name = N'ApiScopeId' AND object_id = OBJECT_ID(N'[dbo].[ApiScopeClaims]')
			        )
		        THEN 0
		        ELSE 1
	        END
"@;
        Migrate = @"
            DROP TABLE [dbo].[ApiClaims];
            DROP TABLE [dbo].[ApiProperties];
            DROP TABLE [dbo].[ApiSecrets];
            DROP TABLE [dbo].[IdentityClaims];
            DROP TABLE [dbo].[IdentityProperties];
            ALTER TABLE [dbo].[ApiScopeClaims] DROP COLUMN [ApiScopeId];     
"@;
	}
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
