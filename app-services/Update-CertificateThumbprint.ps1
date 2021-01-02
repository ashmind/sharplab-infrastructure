param (
    [string] $ParametersPath
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$parameters = ConvertFrom-Json (Get-Content $ParametersPath -Raw)

Write-Output "Getting Azure certificates..."
$certificate = (Get-AzWebAppCertificate).GetEnumerator() | ? {
    $_.SubjectName -eq $parameters.parameters.sites_default_name_public.value
} | Sort-Object 'ExpirationDate' -Descending | Select-Object -First 1

Write-Output "Found certificate for $($certificate.SubjectName) expiring at $($certificate.ExpirationDate)."
$parameters.parameters.sites_default_certificate_thumbprint.value = $certificate.Thumbprint

Set-Content $ParametersPath (ConvertTo-Json $parameters)