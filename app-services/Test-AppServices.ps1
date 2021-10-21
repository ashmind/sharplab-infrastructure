param (
    [string] $ParametersPath
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$parameters = ConvertFrom-Json (Get-Content $ParametersPath -Raw)

@(
    '',
    '/status'
) | % {
    $url = "https://$($parameters.parameters.sites_default_name_public.value)$_"
    Write-Output "GET $url"
    Invoke-RestMethod $url
}

@(
    "core-x64",
    "netfx",
    "netfx-x64"
) | % {
    $url = "https://$($parameters.parameters.sites_architecture_prefix.value)$_.azurewebsites.net/status"
    Write-Output "GET $url"
    Invoke-RestMethod $url
}