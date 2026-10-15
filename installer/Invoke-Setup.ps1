param([switch]$ConfigureOpenCode, [string]$OpenCodeConfig)
$ErrorActionPreference = 'Stop'
$setupExit = 0
Start-Transcript -LiteralPath (Join-Path $PSScriptRoot 'setup-configuration.log') -Append | Out-Null
try {
    $options = @{ BundlePath = $PSScriptRoot; InstallDir = $PSScriptRoot; ConfigureExisting = $true }
    if ($ConfigureOpenCode) { $options.ConfigureOpenCode = $true }
    if ($OpenCodeConfig) { $options.OpenCodeConfig = $OpenCodeConfig }
    & "$PSScriptRoot\Install-Offline.ps1" @options
} catch {
    $setupExit = 1
    Write-Output ('SETUP FAILED: ' + $_.Exception.Message)
} finally { Stop-Transcript | Out-Null }
exit $setupExit
