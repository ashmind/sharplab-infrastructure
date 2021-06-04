[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "AdminPassword")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminUserName", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminPassword", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "TelemetryKey", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AuthorizationToken", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "ScheduledTask")]

param (
    [Parameter(Mandatory = $true)] [string] $AdminUserName,
    [Parameter(Mandatory = $true)] [string] $AdminPassword,
    [Parameter(Mandatory = $true)] [string] $TelemetryKey,
    [Parameter(Mandatory = $true)] [string] $AuthorizationToken
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# Home-made DSC :)
function State() {
    # TODO:
    # 1. Enable IIS
    # 2. Install .NET 5
    # 3. Install Docker Desktop
    # 4. Pull MS container
    # 5. Setup IIS (website)
    # 6. Give AppPool permissions to Docker pipe

    EnvironmentVariables @{
        SHARPLAB_TELEMETRY_KEY = $TelemetryKey
        SHARPLAB_CONTAINER_HOST_AUTHORIZATION_TOKEN = $AuthorizationToken
    }

    ScheduledTask @{
        Name = 'DockerDesktopStartup'
        Login = @{
            UserName = $AdminUserName
            Password = $AdminPassword
        }
        Trigger = @{
            At = 'Startup'
            Delay = 'PT1M'
        }
        Action = @{
            Execute = 'cmd'
            Argument = '/c start "C:\Program Files\Docker\Docker\Docker Desktop.exe"'
        }
    }

    Idempotent {
        Write-Output "Unistall: Windows-Defender"
        Uninstall-WindowsFeature -Name Windows-Defender
    }
}

function ScheduledTask($options) {
    Write-Output "Scheduled Task: $($options.Name)"
    if (Get-ScheduledTask -TaskName $options.Name) {
        Write-Output "  - exists, skipped"
        return
    }

    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = $options.Trigger.Delay

    $action = New-ScheduledTaskAction -Execute $options.Action.Execute -Argument $options.Action.Argument

    $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable -RestartCount 999

    Register-ScheduledTask `
        -TaskName $options.Name `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $options.Login.UserName `
        -Password $options.Login.Password
    Write-Output "  - created"
}

function Idempotent($action) {
    $action.Invoke()
}

function EnvironmentVariables($variables) {
    Write-Output "Environment Variables:"
    $variables.GetEnumerator() | % {
        Write-Output "  - $($_.Key)"
        [Environment]::SetEnvironmentVariable($_.Key, $_.Value, [EnvironmentVariableTarget]::Machine)
    }
}

State