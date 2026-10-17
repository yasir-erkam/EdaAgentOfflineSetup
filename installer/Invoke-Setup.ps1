param([switch]$ConfigureOpenCode, [string]$OpenCodeConfig, [switch]$EnableAltiumMenu, [string]$LogPath)
$ErrorActionPreference = 'Stop'
$setupExit = 0
. (Join-Path $PSScriptRoot 'setup_logging.ps1')
if (-not $LogPath) { $LogPath = New-SetupLog -Operation install }
try {
    $options = @{ BundlePath = $PSScriptRoot; InstallDir = $PSScriptRoot; ConfigureExisting = $true; LogPath = $LogPath }
    if ($ConfigureOpenCode) { $options.ConfigureOpenCode = $true }
    if ($OpenCodeConfig) { $options.OpenCodeConfig = $OpenCodeConfig }
    if ($EnableAltiumMenu) { $options.EnableAltiumMenu = $true }
    & "$PSScriptRoot\Install-Offline.ps1" @options
} catch {
    $setupExit = 1
    Write-SetupLog -Path $LogPath -Event configuration-failed -Code $_.Exception.HResult
    Write-Output "SETUP FAILED. Log: $LogPath"
}
exit $setupExit
