<#
    Synopsis
        Create an Azure automation account
        Optionally create a schedule to apply to runbooks
        Optionally create one or more runbooks, apply schedule if one was created
#>

#region Function
### Function, select file dialog, limit selection to PS1 files
Add-Type -AssemblyName System.Windows.Forms
function Select-Script {
    $scriptSelect = New-Object System.Windows.Forms.OpenFileDialog
    $scriptSelect.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
    $scriptSelect.Title = "Select a PowerShell Script"
    
    if ($scriptSelect.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $scriptSelect.FileName
    }
    return $null
}
#endregion Function

#region Connect
### Set environment variables and connect
$tenantID = 'XXXXX'
$subId = 'YYYYY'
$rg = 'Automations-PROD'
Connect-AzAccount -Tenant $tenantID -Subscription $subId
#endregion Connect

#region AutomationAccount
### Set the name for this automation account, loop if empty
do {
    $aaName = Read-Host "Enter a name for your automation account"
    if ($aaName -eq '') {
        Write-Host 'Invalid input detected Enter DEV, TEST, or PROD, or leave blank for PROD.' -ForegroundColor Red
    }
} until ($aaName -ne '')

### Set value for environment tag, loop if empty
do {
    $environment = Read-Host "Is this automation account for a DEV, TEST, or PROD environment? Leave blank for default (PROD)"
    if ($environment -eq '') {$environment = "PROD"}
    if (@('DEV','TEST','PROD') -inotcontains $environment) {
        Write-Host 'Invalid input detected Enter DEV, TEST, or PROD, or leave blank for PROD.' -ForegroundColor Red
    }
} until (@('DEV','TEST','PROD') -icontains $environment)

### Define tags
$tags = @{
    "createdBy" = $azConnect.Account
    "dateCreated" = (Get-Date -Format yyyyMMdd)
    "Environment" = $environment
}

### Create automation account
New-AzAutomationAccount -Name $aaName -ResourceGroupName $rg -Location 'East US' `
    -Tags $tags -AssignSystemIdentity
#endregion AutomationAccount


#region Schedule
### Ask if a schedule should be created, loop if not Y or N
do {
    $answerSchedule = Read-Host "Would you like to create a schedule for this automation account? (Y/N)"
    if (@('y','n') -inotcontains $answerSchedule) {
        Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
    }
} until (@('y','n') -icontains $answerSchedule)

### Enter schedule creation if specified in previous step, skip otherwise
if ($answerSchedule -ieq 'y') {
    ### Get local time zone
    $tz = ([System.TimeZoneInfo]::Local).Id

    ### Enter a name for the schedule, loop if empty
    do {
        $scheduleName = Read-Host "Enter the name of this schedule"
        if ($scheduleName -eq '') {
            Write-Host "Invalid input detected. Please enter a name for this schedule" -ForegroundColor Red
        }
    } until ($scheduleName -ne '')
    
    ### Enter hours and minutes for the start time, format in 24-hour time
    do {
        $hours = Read-Host "Enter the hours of your start time (0-23)"
        $minutes = Read-Host "Enter the minutes of your start time (0-59)"
        if (@(00..23) -notcontains $hours -or @(00..59) -notcontains $minutes) {
            Write-Host "Invalid input detected on either your Hours or Minutes. Please enter 0-23 for hours and 0-59 for minutes." -ForegroundColor Red
        }
    } until (@(00..23) -contains $hours -and @(00..59) -contains $minutes)
    if (@(0..9) -contains $hours) {$hours = '0' + $hours}
    if (@(0..9) -contains $minutes) {$minutes = '0' + $minutes}
    $startTime = $hours + ':' + $minutes

    ### Ask if this schedule should run weekly, loop if not Y or N
    do {
        $answerWeekly = Read-Host "Would you like this schedule to run weekly? (Y/N)"
        if (@('y','n') -inotcontains $answerSchedule) {
            Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
        }
    } until (@('y','n') -icontains $answerSchedule)

    ### If specified to be weekly, select the day of the week and create the schedule, otherwise create the schedule to run once
    if ($answerWeekly -ieq 'y') {
        do {
            $day = Read-Host "Enter the day of the week this schedule should activate. (ex. 'Monday', 'Tuesday', etc.)"
            if (@('monday','tuesday','wednesday','thursday','friday','saturday','sunday') -inotcontains $day) {
                Write-Host "Invalid input detected. Please enter the name of the day of the week that this schedule should activate on." -ForegroundColor Red
            }
        } until (@('monday','tuesday','wednesday','thursday','friday','saturday','sunday') -icontains $day)

        New-AzAutomationSchedule -ResourceGroupName $rg -AutomationAccountName $aaName -Name $scheduleName `
            -WeekInterval 1 -DaysOfWeek $day -StartTime $startTime -TimeZone $tz
    } else {
        New-AzAutomationSchedule -ResourceGroupName $rg -AutomationAccountName $aaName -Name $scheduleName `
            -StartTime $startTime -OneTime -TimeZone $TimeZone
    }
}
#endregion Schedule



#region Runbook
### Ask if a runbook should be created, loop if not Y or N
do {
    $answerCreateRb = Read-Host "Would you like to create a runbook? (Y/N)"
    if ($('y','n') -inotcontains $answerCreateRb) {
        Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
    }
} until ($('y','n') -icontains $answerCreateRb)

### Get information for runbook and create, loop to create multiple if desired, skip otherwise
if ($answerCreateRb -ieq 'y') {
    ### Loop to create multiple if desired
    do {
        ### Set runbook name, loop if empty
        do {
            $rbName = Read-Host "Enter the name of this runbook"
            if ($rbName -eq '') {
                Write-Host "Invalid input detected. Please enter a name for this schedule" -ForegroundColor Red
            }
        } until ($rbName -ne '')

        ### Set description, loop if empty
        do {
            $description = Read-Host "Enter a short description for this runbook"
            if ($description -eq '') {
                Write-Host "Invalid input detected. While a description is not a required property, please provide one for documentation." -ForegroundColor Red
            }
        } until ($description -ne '')

        ### Ask if a PS1 file should be imported for this runbook, loop if not Y or N
        do {
            $answerImportScript = Read-Host "Would you like to add $rbName to $scheduleName? (Y/N)"
            if ($('y','n') -inotcontains $answerImportScript) {
                Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
            }
        } until ($('y','n') -icontains $answerImportScript)

        ### Create an empty runbook if not importing a file, otherwise select a PS1 through a file dialog and import
        if ($answerImportScript -ieq 'n') {
            New-AzAutomationRunbook -ResourceGroupName $rg -AutomationAccountName $aaName -Name $rbName `
                -Tags $tags -Type PowerShell -Description $description
        } else {
            ### Select PS1 file, loop if path is null
            do {
                $scriptPath = Select-Script
                if (!$scriptPath) {
                    Write-Host "No file selected." -ForegroundColor Red
                }
            } until ($scriptPath)

            ### Import PS1 file to new runbook
            Import-AzAutomationRunbook -ResourceGroupName $rg -AutomationAccountName $aaName -Name $rbName `
                -Tags $tags -Type PowerShell -Description $description -Path $scriptPath -Published
        }

        ### If a schedule was created earlier, ask if it should be associated to this runbook
        if ($scheduleName) {
            ### Ask to associate schedule to runbook, loop if not Y or N
            do {
                $answerAddRbToSchedule = Read-Host "Would you like to add $rbName to $scheduleName? (Y/N)"
                if ($('y','n') -inotcontains $answerAddRbToSchedule) {
                    Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
                }
            } until ($('y','n') -icontains $answerAddRbToSchedule)

            if ($answerAddRbToSchedule -ieq 'y') {
                Register-AzAutomationScheduledRunbook -ResourceGroupName $rg -AutomationAccountName $aaName -RunbookName $rbName -ScheduleName $scheduleName
            }
        }

        ### Ask if an additional runbook should be created, skip if not and finish script, loop if not Y or N
        do {
            $answerCreateAnotherRb = Read-Host "Would you like to create a runbook? (Y/N)"
            if ($('y','n') -inotcontains $answerCreateAnotherRb) {
                Write-Host "Invalid input detected. Please enter Y for yes or N for no." -ForegroundColor Red
            }
        } until ($('y','n') -icontains $answerCreateAnotherRb)
    } until ($answerCreateAnotherRb -ieq 'n')
}
#endregion Runbook