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
        Description = "Create Table RateLimitType";
        Test = @"
        SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RateLimitType]') AND type in (N'U')
"@;
        Migrate = @"
        CREATE TABLE [dbo].[RateLimitType] (
            [RateLimitTypeId] INT                                       IDENTITY (1, 1) NOT NULL,
            [Name]            NVARCHAR (20)                             NULL,
            [Description]     NVARCHAR (255)                            NULL,
        	[Requests]        BIGINT                                    NULL,
            [Period]          BIGINT                                    NULL,
            CONSTRAINT [PK_RateLimitType_RateLimitTypeId] PRIMARY KEY CLUSTERED ([RateLimitTypeId] ASC)
        );
"@;
	},
    @{
        Description = "Create Default Rate Limits";
        Test = @"
        SELECT TOP 1 1 from [dbo].[RateLimitType] WHERE [Name] = 'Unlimited'
"@;
        Migrate = @"
        SET IDENTITY_INSERT [dbo].[RateLimitType] ON;

        INSERT INTO [dbo].[RateLimitType] 
        ([RateLimitTypeId], [Name], [Description], [Requests], [Period]) 
        VALUES 
        (1, 'Unlimited', 'Limitless access to the API (for TW products)', NULL, NULL),
        (2, 'Basic', 'The basic default API rate for non TW products.', 25, 5),
	    (3, 'Plus', 'A premium enhanced API rate for non TW products.', 50, 5);

        SET IDENTITY_INSERT [dbo].[RateLimitType] OFF;

"@;
    },
    @{
        Description = "Add RateLimitType to ClientAdditionalInfo";
        Test = @"
        SELECT TOP 1 1 FROM [sys].[columns] c
        INNER JOIN [sys].[tables] t ON c.object_id = t.object_id
        WHERE c.[Name] = 'RateLimitTypeId'
        AND t.[Name] = 'ClientAdditionalInfo'
"@;
        Migrate = @"
        ALTER TABLE [dbo].[ClientAdditionalInfo] ADD
        [RateLimitTypeId] INT NOT NULL CONSTRAINT [DF_ClientAdditionalInfo_RateLimitTypeId] DEFAULT 1;
"@;
    },
    @{
        Description = "Add ClientAdditionalInfo RateLimitTypeId constraint";
        Test = @"
        SELECT TOP 1 1 FROM [sys].[foreign_keys]
	WHERE [name] like 'FK_ClientAdditionalInfo_RateLimitType_RateLimitTypeId'
"@;
        Migrate = @"
        UPDATE [dbo].[ClientAdditionalInfo]
        SET [RateLimitTypeId] = CASE WHEN [IsTWProduct] = 1 THEN 1 ELSE 2 END;

        ALTER TABLE [dbo].[ClientAdditionalInfo] ADD
        CONSTRAINT [FK_ClientAdditionalInfo_RateLimitType_RateLimitTypeId] FOREIGN KEY ([RateLimitTypeId]) REFERENCES [dbo].[RateLimitType] ([RateLimitTypeId]);
"@;
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}


