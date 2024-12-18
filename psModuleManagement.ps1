$installedModules = Get-InstalledModule -Name Microsoft.Graph*
$requiredModules = @(
    'Microsoft.Graph',
    'Microsoft.Graph.Beta',
    'Az',
    'AzureAdPreview',
    'MSOnline',
    'Join-Object',
    'SqlServer'
)

foreach ($module in $requiredModules) {
    $repo = 'PSGallery'
    if ($installedModules.Name -notcontains $module) {
        Install-Module -Repository $repo -Name $module
    } else {
        $repo = ($installedModules | where {$_.Name -eq $module}).Repository
        if (($installedModules | where {$_.Name -eq $module}).Version -lt (Find-Module -Repository $repo -Name $module).Version) {
            Update-Module -Name $module
        }
    }
}