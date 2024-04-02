function mgConnect {
    Connect-mgGraph -TenantId $tenantId -ClientId $clientId -Scope $scope -NoWelcome
}

$tenantId = ''
$clientId = ''
$scope = @('','')
$mgConnected = $false

$mgContext = Get-MgContext
if (!$mgContext) {
    ### Not connected to Graph. Connecting.
    mgConnect
} elseif ($mgContext.ClientId -ne $clientId) {
    ### Connected to a different app reg. Disconnecting and connecting to correct app reg.
    Disconnect-MgGraph
    mgConnect
} else {
    ### Already connected. Skipping auth.
}
$mgConnected = $true