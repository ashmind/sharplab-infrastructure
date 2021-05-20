[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "AdminPassword")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminUserName", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "AdminPassword", Justification = "https://github.com/PowerShell/PSScriptAnalyzer/issues/1472")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "ScheduledTask")]

param (
    [string] $AdminUserName,
    [string] $AdminPassword
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
            Execute = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        }
    }

    Idempotent {
        Uninstall-WindowsFeature -Name Windows-Defender
    }
}

function ScheduledTask($options) {
    Write-Output "Scheduled Task: $($options.Name)"
    if (Get-ScheduledTask -TaskName $options.Name) {
        Write-Output "- exists, skipped"
        return
    }

    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = $options.Trigger.Delay

    $action = New-ScheduledTaskAction -Execute $options.Action.Execute

    $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable -RestartCount 999

    Register-ScheduledTask `
        -TaskName $options.Name `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $options.Login.UserName `
        -Password $options.Login.Password
    Write-Output "- created"
}

function Idempotent($action) {
    $action.Invoke()
}

State