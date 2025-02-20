### Read-Host to get server name
$server = Read-Host "Enter the name of your active sync server"
### Read-Host to get policy type, repeat if input is not a valid policy type
do {
    $policyType = Read-Host "Enter the desired sync policy type (Delta/Initial)"
    if (@('delta','initial') -inotcontains $policyType) {
        Write-Host 'Invalid input provided. Input must be "Delta" or "Initial".' -ForegroundColor Red
    }
} until (@('delta','initial') -icontains $policyType)

### Test-Connection to server 10 times, abort script if connection cannot be made
$testCounter = 0
do {
    $testCounter = $testCounter + 1
    if ($testCounter -lt 10) {
        $connTest = Test-Connection -ComputerName $server -Count 1 2>$null
    } else {
        $connTest = Test-Connection -ComputerName $server -Count 1 `
        -ErrorVariable dcConnectionFailed 2>$null
        if ($connectionFailed) {
            Write-Error -Message "Connection test failed. Script will not function normally without this connection." `
            -RecommendedAction "Check network connection. Connect to VPN if remote." `
            -ErrorAction Stop
        }
    }
} until ($testCounter -eq 10 -or $connTest -ne $null)

### Push commands in Invoke-Command scriptblock to specified server
Invoke-Command -ComputerName $server -ScriptBlock {
    ### Use Get-AdSyncScheduler to get SyncCycleInProgress, loop if $true to wait for sync to end before new sync is created
    do {
        $isRunning = (Get-AdSyncScheduler).SyncCycleInProgress
        if ($isRunning.SyncCycleInProgress -eq $true) {
            Write-Host "Sync cycle is currently running. Waiting 10 seconds to retry. (Ctrl+C if you would like to cancel)" -ForegroundColor Gray
            Start-Sleep 10
        }
    } until ($isRunning -eq $false)

    ### Start sync cycle
    Start-AdSyncSyncCycle -PolicyType $policyType
    
    ### Repeat sync check, repeat until new sync is complete
    ### Start-Sleep to allow sync to begin before checking
    Start-Sleep 5
    do {
        $isRunning = (Get-AdSyncScheduler).SyncCycleInProgress
        if ($isRunning.SyncCycleInProgress -eq $true) {
            Write-Host "Sync cycle is currently running. Waiting 10 seconds to retry. (Ctrl+C if you would like to cancel)" -ForegroundColor Gray
            Start-Sleep 10
        }
    } until ($isRunning -eq $false)

    ### Get local timezone and next sync time, convert to local time and display
    $tz = (Get-TimeZone).Id
    $nextRunUtc = (Get-AdSyncScheduler).NextSyncCycleStartTimeInUtc
    $nextRun = ($nextRunUtc.AddHours($tz.TotalHours)).ToLocalTime()

    Write-Host "Next sync time: $nextRun" -ForegroundColor Yellow
} | Out-Null