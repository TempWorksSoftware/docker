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

$loginServerUpdates = @(
    @{
        Description = "Give enterprise clients the tw-enterprise-access scope.";
        Test = @"
        SELECT TOP 1 1 FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise') AND Scope = 'tw-enterprise-access';
"@;
        Migrate = @"
        INSERT INTO ClientScopes (ClientId, Scope) VALUES ((SELECT Id FROM Clients WHERE ClientId = 'enterprise'), 'tw-enterprise-access');
"@;
	},
    @{
        Description = "Give enterprise-impersonation clients the tw-enterprise-access scope.";
        Test = @"
        SELECT TOP 1 1 FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise-impersonation') AND Scope = 'tw-enterprise-access';
"@;
        Migrate = @"
        INSERT INTO ClientScopes (ClientId, Scope) VALUES ((SELECT Id FROM Clients WHERE ClientId = 'enterprise-impersonation'), 'tw-enterprise-access');
"@;
    },
    @{
        Description = "Remove allow-full-access scope from enterprise and enterprise-impersonation clients. Also remove client-credentials grant type from enterprise clients.";
        Test = @"
        IF NOT EXISTS (
            SELECT TOP 1 1 FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise') AND Scope = 'allow-full-access'
            UNION ALL
            SELECT TOP 1 1 FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise-impersonation') AND Scope = 'allow-full-access'
            UNION ALL
            SELECT TOP 1 1 FROM ClientGrantTypes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise') AND GrantType = 'client_credentials'
        )
        BEGIN
        SELECT 1
        END
"@;
        Migrate = @"
        DELETE FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise') AND Scope = 'allow-full-access';
        DELETE FROM ClientScopes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise-impersonation') AND Scope = 'allow-full-access';
        DELETE FROM ClientGrantTypes WHERE ClientId = (SELECT Id FROM Clients WHERE ClientId = 'enterprise') AND GrantType = 'client_credentials';
"@;
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
