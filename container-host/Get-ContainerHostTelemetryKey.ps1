Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

Write-Output "Getting telemtry key..."
# Not using PowerShell to avoid login performance error: https://github.com/Azure/login/issues/20
$telemetryKey = (az monitor app-insights component show --app sharplab-container-host-insights -g $($env:ResourceGroupName) --query instrumentationKey --output tsv)

Write-Output "::add-mask::$telemetryKey"
Write-Output "::set-output name=telemetry_key::$telemetryKey"
