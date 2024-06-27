function mgConnect {
    Connect-mgGraph -TenantId $tenantId -ClientId $clientId -Scope $scope -NoWelcome
}

$tenantId = ''
$clientId = ''
$scope = @('','')

$mgContext = Get-MgContext
if (!$mgContext) {
    ### Not connected to Graph. Connecting.
    mgConnect
    $mgContext = Get-MgContext
} elseif ($mgContext.ClientId -ne $clientId) {
    ### Connected to a different app reg. Disconnecting and connecting to correct app reg.
    Disconnect-MgGraph
    mgConnect
    $mgContext = Get-MgContext
}
$myId = (Get-MgUser -UserId $mgContext.Account).Id