[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "AdminPassword")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminUserName", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminPassword", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "TelemetryKey", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AuthorizationToken", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "Package")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]

param (
    [Parameter(Mandatory = $true)] [string] $TelemetryKey,
    [Parameter(Mandatory = $true)] [string] $AuthorizationToken
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if (!([Environment]::GetCommandLineArgs() | ? { $_ -like '-noninteractive*' })) {
    $process = (Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList @(
            '-NonInteractive',
            '-File', $MyInvocation.MyCommand.Path,
            '-TelemetryKey', $TelemetryKey,
            '-AuthorizationToken', $AuthorizationToken
        ) `
        -Wait `
        -NoNewWindow `
        -PassThru)
    exit $process.ExitCode
}

# Home-made DSC :)
function Set-State() {
    # TODO:
    # 1. Enable IIS
    # 2. Install .NET 5
    # 3. Setup IIS (website)

    EnvironmentVariables @{
        SHARPLAB_TELEMETRY_KEY = $TelemetryKey
        SHARPLAB_CONTAINER_HOST_AUTHORIZATION_TOKEN = $AuthorizationToken
    }

    Directory @{
        Path = 'C:\Deployments'
    }

    Custom @{
        Name = 'ACL: Grant Read for C:\Deployments to Capability SID'
        Action = {
            icacls C:\Deployments /grant '*S-1-15-3-1024-4233803318-1181731508-1220533431-3050556506-2713139869-1168708946-594703785-1824610955:(OI)(CI)R'
        }
    }

    UserGroup @{
        Name = 'docker-users'
        Members = @('IIS APPPOOL\SharpLab.Container.Manager')
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

function UserGroup($options) {
    Write-Output "User Group: $($options.Name)"
    $created = $false
    $updated = $false
    $group = Get-LocalGroup $($options.Name) -ErrorAction SilentlyContinue
    if (!$group) {
        $group = New-LocalGroup -Name $($options.Name)
        $created = $true
    }

    $options.Members | % {
        if ($created -or !(Get-LocalGroupMember -Group $group -Member $_)) {
            Add-LocalGroupMember -Group $group -Member $_
            $script:updated = $true
        }
    }

    if ($created) {
        Write-Output '  - created'
    }
    elseif ($updated) {
        Write-Output '  - updated'
    }
    else {
        Write-Output '  - exists, skipped'
    }
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

function Directory($options) {
    Write-Output "Directory: $($options.Path)"
    if (Test-Path $($options.Path)) {
        Write-Output '  - exists, skipped'
        return
    }

    [IO.Directory]::CreateDirectory($options.Path)
    Write-Output '  - created'
}

function Custom($options) {
    Write-Output $options.Name
    if ($options.ContainsKey('Condition') -and !$options.Condition.Invoke()) {
        Write-Output '  - up to date, skipped'
    }
    $options.Action.Invoke()
    Write-Output '  - done'
}

Set-State