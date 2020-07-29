function Test-SqlConnectionString ([string]$ConnectionString) {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
    $sqlConnection.Open()
    $sqlConnection.Close()
    return $true
}

function Test-AppsettingsConnectionStrings ($path, $strings) {
    Describe $path {
        foreach ($string in $strings) {
            It ('has a working '+$string+'connection string') {
                Test-SqlConnectionString (Get-Content $path | Out-String |ConvertFrom-Json).ConnectionStrings."$string" | Should Be $true
            }
        }
    }
}


$api_email_server_path = 'api-email-server'
$api_jobservice_server_path = 'api-jobservice-server'
$api_server_path = 'api-server'
$beyond_path = 'beyond'
$login_server_path = 'login-server'

# Verify connection strings
Test-AppsettingsConnectionStrings ($api_server_path + '\appsettings.production.json') $('TwApiDatabase','RebusDatabase','HangfireDatabase')
Test-AppsettingsConnectionStrings ($api_email_server_path + '\appsettings.json') @( 'EmailDatabase', 'RebusDatabase' )
Test-AppsettingsConnectionStrings ($api_jobservice_server_path + '\appsettings.json') $('TwApiDatabase', 'RebusDatabase', 'HangfireDatabase')
Test-AppsettingsConnectionStrings ($login_server_path + '\appsettings.production.json') $('TwLoginServerDatabase')
