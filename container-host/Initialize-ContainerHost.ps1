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

    UserGroup @{
        Name = 'docker-users'
        Members = @('IIS APPPOOL\SharpLab.Container.Manager')
    }

    Package @{
        Name = 'docker'
        Provider = 'DockerMsftProvider'
        Version = '20.10.5'
        IsInstalled = {
            Get-Service -Name docker -ErrorAction SilentlyContinue
        }
    }

    File @{
        Path = 'C:\ProgramData\docker\config\daemon.json'
        Content = '{"group":"docker-users"}'
    }

    Custom @{
        Name = 'Docker Image: mcr.microsoft.com/dotnet/runtime:5.0'
        Condition = {
            !(docker image list | ? { $_ -like 'mcr.microsoft.com/dotnet/runtime*' })
        }
        Action = {
            docker pull 'mcr.microsoft.com/dotnet/runtime:5.0'
        }
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

function Package($options) {
    Write-Output "Package: $($options.Name)"
    if ($options.Contains('IsInstalled')) {
        $installed = $options.IsInstalled.Invoke()
    }
    else {
        $installed = Get-Package -Name $($options.Name) -ErrorAction SilentlyContinue
    }

    if ($installed) {
        Write-Output "  - exists, skipped"
        return
    }

    if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Force
    }

    if (!(Get-Module -ListAvailable -Name $($options.Provider))) {
        Install-Module `
            -Name $($options.Provider) `
            -Repository PSGallery `
            -Force
    }

    Install-Package `
        -Name $($options.Name) `
        -ProviderName $($options.Provider) `
        -RequiredVersion $($options.Version) `
        -Force
    Write-Output "  - installed"
}

function File($options) {
    Write-Output "File: $($options.Path)"
    if (Test-Path $($options.Path)) {
        $content = [IO.File]::ReadAllText($options.Path)
        if ($content -eq $options.Content) {
            Write-Output '  - same, skipped'
            return
        }
    }

    [IO.File]::WriteAllText($options.Path, $options.Content)
    Write-Output '  - updated'
}

function Custom($options) {
    Write-Output $options.Name
    if (!$options.Condition.Invoke()) {
        Write-Output '  - up to date, skipped'
    }
    $options.Action.Invoke()
    Write-Output '  - done'
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