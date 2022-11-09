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

    WindowsFeature @{
        Name = 'Web-Server'
        IncludeManagementTools = $true
    }

    UninstalledWindowsFeatures @(
        'Windows-Defender'
    )

    AspNetCoreHostingBundle

    # website is set up by the code deployments
}

function EnvironmentVariables($variables) {
    Write-Output "Environment Variables:"
    $variables.GetEnumerator() | % {
        Write-Output "  - $($_.Key)"
        [Environment]::SetEnvironmentVariable($_.Key, $_.Value, [EnvironmentVariableTarget]::Machine)
    }
}

function WindowsFeature($options) {
    Write-Output "Install: $($options.Name)"
    if ((Get-WindowsFeature ($options.Name)).InstallState -ne 'Installed') {
        Install-WindowsFeature -Name ($options.Name) -IncludeManagementTools:($options.IncludeManagementTools)
        Write-Output "  - installed"
    }
    else {
        Write-Output "  - already installed, skipped"
    }
}

function UninstalledWindowsFeatures($featureNames) {
    $featureNames | % {
        Write-Output "Uninstall: $_"
        if ((Get-WindowsFeature $_).InstallState -eq 'Installed') {
            Uninstall-WindowsFeature -Name $_
            Write-Output "  - uninstalled"
        }
        else {
            Write-Output "  - already uninstalled, skipped"
        }
    }
}

function AspNetCoreHostingBundle {
    Write-Output "ASP.NET Core Hosting Bundle"
    $dotnetRuntimes = @()
    if ((Get-Command 'dotnet' -ErrorAction SilentlyContinue)) {
        try {
            $dotnetRuntimes = @(dotnet --list-runtimes)
        }
        catch {
            Write-Output "Failed to list dotnet runtimes: $_"
        }
    }

    if (-not ($dotnetRuntimes | ? { $_.Contains('Microsoft.AspNetCore.App 7.0.0') })) {
        if (!(Test-Path 'D:\dotnet-hosting-7.0.0-win.exe')) {
            Invoke-WebRequest 'https://download.visualstudio.microsoft.com/download/pr/8de163f5-5d91-4dc3-9d01-e0b031a03dd9/0170b328d569a49f6f6a080064309161/dotnet-hosting-7.0.0-win.exe' -OutFile 'D:\dotnet-hosting-7.0.0-win.exe'
            Write-Output "  - downloaded"
        }
        D:\dotnet-hosting-7.0.0-win.exe /quiet /install /norestart
        if ($LastExitCode -ne 0) {
            throw "dotnet-hosting-7.0.0-win.exe exited with code $LastExitCode"
        }
        iisreset
        if ($LastExitCode -ne 0) {
            throw "iisreset exited with code $LastExitCode"
        }
        Write-Output "  - installed"
    }
    else {
        Write-Output "  - already installed, skipped"
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