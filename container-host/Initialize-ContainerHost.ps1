Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# Home-made DSC :)
function State() {
    ScheduledTask @{
        Name = 'DockerDesktopStartup'
        Login = @{
            UserName = $env:CONTAINER_HOST_ADMIN_USERNAME
            Password = $env:CONTAINER_HOST_ADMIN_PASSWORD
        }
        Trigger = @{
            At = 'Startup'
            Delay = 'PT1M'
        }
        Action = @{
            Execute = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        }
    }
}

function ScheduledTask($options) {
    Write-Output "Scheduled Task: $($options.Name)"
    if (Get-ScheduledTask -TaskName $options.Name) {
        Write-Output "- exists, skipped"
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

State