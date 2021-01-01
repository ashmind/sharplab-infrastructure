param (
    [string] $ParametersPath
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$Parameters = ConvertFrom-Json (Get-Content $ParametersPath -Raw)

Write-Output "Getting Azure certificates..."
$Certificate = (Get-AzWebAppCertificate).GetEnumerator() | ? {
    $_.SubjectName -eq $Parameters.parameters.sites_default_name_public.value
} | sort 'ExpirationDate' -Descending | select -First 1

Write-Output "Found certificate for $($Certificate.SubjectName) expiring at $($Certificate.ExpirationDate)."
$Parameters.parameters.sites_default_certificate_thumbprint.value = $Certificate.Thumbprint

Set-Content $ParametersPath (ConvertTo-Json $Parameters)