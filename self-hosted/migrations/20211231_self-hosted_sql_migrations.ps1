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
        Description = "Create Products table";
        Test = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Products]') AND type in (N'U')";
        Migrate = @"
CREATE TABLE [dbo].[Products] (
    ProductId INT NOT NULL,
    ProductName NVARCHAR(255) NOT NULL,
	CONSTRAINT [PK_Product_ProductId] PRIMARY KEY CLUSTERED (ProductId)
        )
"@;
    },
    @{
        Description = "Create ClientProducts table";
        Test = "SELECT TOP 1 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClientProducts]') AND type in (N'U')";
        Migrate = @"
CREATE TABLE [dbo].[ClientProducts] (
	Id INT IDENTITY(1,1) NOT NULL,
    ClientId INT NOT NULL
	    CONSTRAINT [FK_ClientProducts_ClientId_Clients_Id]
        FOREIGN KEY REFERENCES [dbo].[Clients] ([Id]),
    ProductId INT NOT NULL
		CONSTRAINT [FK_ClientProducts_ProductId_Products_ProductId]
        FOREIGN KEY REFERENCES [dbo].[Products] ([ProductId]),
CONSTRAINT [PK_ProductClients_Id] PRIMARY KEY CLUSTERED (Id)
)
CREATE UNIQUE NONCLUSTERED INDEX [UX_ClientProducts_ClientId_ProductId]
    ON [dbo].[ClientProducts]([ClientId] ASC, [ProductId] ASC);
"@
    },
    @{
        Description = "Insert Products";
        Test = "SELECT 1 FROM Products WHERE ProductId = 1";
        Migrate = @"
INSERT INTO Products
VALUES
(1, 'Enterprise'),
(2, 'Beyond'),
(4, 'WebCenter'),
(8, 'HR Center'),
(16, 'Companion'),
(32, 'JobBoard'),
(64, 'Distributor')
"@;
    },
    @{
        Description = "Insert Product Clients";
        Test = "SELECT 1 from ClientProducts";
        Migrate = @"
DECLARE @ClientProducts TABLE
(
    Id INT ,
    ProductId INT
);

INSERT INTO @ClientProducts 
( 
	Id ,
	ProductId 
)
SELECT c.Id ,
        NULL
FROM   dbo.Clients c;

--Enterprise
UPDATE cp
SET    ProductId = 1
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientGrantTypes cgt ON cgt.ClientId = cp.Id
WHERE  cgt.GrantType = 'tw_enterprise';

--Enterprise 2
;
WITH ClientIdsWithOfflineAccess
  AS ( SELECT ClientId
       FROM   dbo.ClientScopes cs
       WHERE  cs.Scope = 'offline_access' )
UPDATE cp
SET    ProductId = 1
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
       LEFT JOIN ClientIdsWithOfflineAccess ciwoa ON ciwoa.ClientId = cp.Id
WHERE  cs.Scope = 'tw-webats-access'
       AND cp.ProductId IS NULL
       AND ciwoa.ClientId IS NULL;

--Beyond
UPDATE cp
SET    ProductId = 2
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
WHERE  cs.Scope = 'tw-webats-access'
       AND cp.ProductId IS NULL;

--WebCenter
UPDATE cp
SET    ProductId = 4
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
WHERE  cs.Scope = 'tw-webcenter-access'
       AND cp.ProductId IS NULL;

--HRCenter
UPDATE cp
SET    ProductId = 8
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
WHERE  cs.Scope = 'tw-hrcenter-access'
       AND cp.ProductId IS NULL;

--Buzz
UPDATE cp
SET    ProductId = 16
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
WHERE  cs.Scope = 'tw-companion-access'
       AND cp.ProductId IS NULL;

--Job Board
UPDATE cp
SET    ProductId = 32
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientScopes cs ON cs.ClientId = cp.Id
WHERE  cs.Scope = 'tw-jobboard-access'
       AND cp.ProductId IS NULL;

-- Distributor
UPDATE cp
SET    ProductId = 64
FROM   @ClientProducts cp
       INNER JOIN dbo.ClientGrantTypes cgt ON cgt.ClientId = cp.Id
WHERE  cgt.GrantType = 'distributor';

MERGE INTO ClientProducts AS [Target]
USING(
	SELECT Id, ProductId 
	FROM @ClientProducts
	WHERE ProductId IS NOT NULL
) AS Source(Id, ProductId)
ON [Target].ClientId = Source.Id
WHEN MATCHED THEN 
	UPDATE SET [Target].ProductId = Source.ProductId
WHEN NOT MATCHED BY TARGET THEN
	INSERT(ClientId, ProductId)
	VALUES(Id, ProductID);
"@;
    }
);

$loginServerUpdates | ForEach-Object {
    Apply-SqlMigration $loginServerConnectionString $_.Description $_.Test $_.Migrate
}
