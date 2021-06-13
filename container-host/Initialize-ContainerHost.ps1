[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "AdminPassword")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminUserName", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminPassword", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "TelemetryKey", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AuthorizationToken", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "Package")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]

param (
    [Parameter(Mandatory = $true)] [string] $AdminUserName,
    [Parameter(Mandatory = $true)] [string] $AdminPassword,
    [Parameter(Mandatory = $true)] [string] $TelemetryKey,
    [Parameter(Mandatory = $true)] [string] $AuthorizationToken
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# Home-made DSC :)
function Set-State() {
    # TODO:
    # 1. Enable IIS
    # 2. Install .NET 5
    # 3. Pull MS container
    # 4. Setup IIS (website)
    # 5. Give AppPool permissions to Docker pipe

    EnvironmentVariables @{
        SHARPLAB_TELEMETRY_KEY = $TelemetryKey
        SHARPLAB_CONTAINER_HOST_AUTHORIZATION_TOKEN = $AuthorizationToken
    }

    Package @{
        Name = 'docker'
        Provider = 'DockerMsftProvider'
        Version = '20.10.5'
    }

    UninstalledWindowsFeatures @(
        'Windows-Defender'
    )
}

function EnvironmentVariables($variables) {
    Write-Output "Environment Variables:"
    $variables.GetEnumerator() | % {
        Write-Output "  - $($_.Key)"
        [Environment]::SetEnvironmentVariable($_.Key, $_.Value, [EnvironmentVariableTarget]::Machine)
    }
}

function Package($options) {
    Write-Output "Package: $($options.Name)"
    if (Get-Package -Name $($options.Name) -ErrorAction SilentlyContinue) {
        Write-Output "  - exists, skipped"
        return
    }

    if (!(Get-Module -ListAvailable -Name $($options.Provider))) {
        Install-Module `
            -Name $($options.Provider) `
            -Repository PSGallery
    }

    Install-Package `
        -Name $($options.Name) `
        -ProviderName $($options.Provider) `
        -RequiredVersion $($options.Version)
    Write-Output "  - installed"
}

function UninstalledWindowsFeatures($featureNames) {
    $featureNames | % {
        Write-Output "Unistall: $_"
        if ((Get-WindowsFeature $_).InstallState -eq 'Installed') {
            Uninstall-WindowsFeature -Name $_
            Write-Output "  - uninstalled"
        }
        else {
            Write-Output "  - already uninstalled, skipped"
        }
    }
}

Set-State