param (
    [string] $ParametersPath
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$parameters = ConvertFrom-Json (Get-Content $ParametersPath -Raw)

$publicSiteStatusUrl = "https://$($parameters.parameters.sites_default_name_public.value)/status"
Write-Output "GET $publicSiteStatusUrl"
Invoke-RestMethod $publicSiteStatusUrl

@(
    "core-x64",
    "core-x64-profiled",
    "netfx",
    "netfx-x64"
) | % {
    $statusUrl = "https://$($parameters.parameters.sites_architecture_prefix.value)$_.azurewebsites.net/status"
    Write-Output "GET $statusUrl"
    Invoke-RestMethod $statusUrl
}