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
        Description = "Add Enterprise and Corporate rate limit tiers. [WI 91881]";
        Test = @"
            SELECT 1 FROM [dbo].[RateLimitType] WHERE [Name]='Corporate'
"@;
        Migrate = 
        @"
        	SET IDENTITY_INSERT [dbo].[RateLimitType] ON
	        INSERT INTO [dbo].[RateLimitType]
	        (
		        [RateLimitTypeId], 
		        [Name], 
		        [Description], 
		        [Requests], 
		        [Period]
	        )
	        VALUES
	        (4, 'Corporate', 'A enhanced API rate for Coporate non TW products', 60, 5),
	        (5, 'Enterprise', 'A enhanced API rate for Enterprise non TW products', 125, 5)
	        SET IDENTITY_INSERT [dbo].[RateLimitType] OFF
"@;
	}
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
