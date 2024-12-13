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
$sqlMigrationTestQuery1 = @'
    SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES r
    WHERE r.ROUTINE_DEFINITION LIKE '%TenantGuid%' 
    AND r.ROUTINE_NAME like 'GetTokenByAccountSid'
'@;
$sqlMigrationQuery1 = @"
	ALTER PROCEDURE [dbo].[GetTokenByAccountSid]
    @accountSid NVARCHAR(255)
    AS
    DECLARE @tokenType INT; -- 0=system, 2=servicerep
    /*
        Discover token type
    */
    SELECT @tokenType = 0 -- system
    FROM   SystemTokens
    WHERE  AccountSid = @accountSid;
    SELECT @tokenType = 2 -- servicerep
    FROM   ServiceRepTokens
    WHERE  AccountSid = @accountSid;
    /*
        Return result based on TokenType
    */
    IF @tokenType = 0 -- system
        BEGIN
            SELECT 'AccountSid' = st.AccountSid ,
                   'TenantName' = t.Name ,
				   'TenantGuid' = t.TenantGuid ,
                   'AllowedScopes' = st.AllowedScopes ,
                   'IsActive' = st.IsActive ,
                   'ExpiresUtc' = st.ExpiresUtc ,
                   'TokenType' = @tokenType ,
                   'TenantConnectionString' = t.ConnectionString ,
                   'TenantProviderName' = t.ProviderName ,
                   'AuthTokenHash' = st.AuthToken
            FROM   SystemTokens st
                   INNER JOIN Tenants t ON t.TenantId = st.TenantId
            WHERE  AccountSid = @accountSid;
        END;
    IF @tokenType = 2 -- servicerep
        BEGIN
            SELECT 'AccountSid' = srt.AccountSid ,
                   'TenantName' = t.Name + ISNULL('||' + st.Name, '') ,
				   'TenantGuid' = ISNULL(st.SubTenantGUID, t.TenantGuid) ,
                   'AllowedScopes' = srt.AllowedScopes ,
                   'IsActive' = srt.IsActive ,
                   'ExpiresUtc' = srt.ExpiresUtc ,
                   'TokenType' = @tokenType ,
                   'TenantConnectionString' = ISNULL(
                                                  st.ConnectionString ,
                                                  t.ConnectionString) ,
                   'TenantProviderName' = t.ProviderName ,
                   'AuthTokenHash' = srt.AuthToken ,
                   'SrIdent' = srt.SrIdent
            FROM   dbo.ServiceRepTokens srt
                   INNER JOIN dbo.Tenants t ON t.TenantId = srt.TenantId
                   LEFT JOIN dbo.SubTenants st ON srt.SubTenantId = st.SubTenantId
            WHERE  srt.AccountSid = @accountSid;
        END;
"@;
Apply-SqlMigration $loginServerConnectionString "Add TenantGuid to GetTokenByAccountSid Procedure. [WI 108968]" $sqlMigrationTestQuery1 $sqlMigrationQuery1
