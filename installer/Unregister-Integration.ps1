param([Parameter(Mandatory = $true)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
$InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$settingsPath = Join-Path $InstallDir 'installation.json'
$isKicad = $false
if (Test-Path -LiteralPath $settingsPath) {
    $isKicad = (Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json).backend -eq 'kicad'
}
$stateFile = Join-Path $InstallDir 'setup-state.json'
if (-not $isKicad -and (Test-Path -LiteralPath (Join-Path $InstallDir 'workspace\eda-menu-enabled')) -and
    (Get-Process -Name X2,DXP -ErrorAction SilentlyContinue)) {
    throw 'Close all Altium sessions before removing guarded menu support. Remove the manual EDA Agent command in Customize as well.'
}
if (Test-Path -LiteralPath $stateFile) {
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.configPath) {
        & "$InstallDir\runtime\python.exe" "$InstallDir\configure_opencode.py" $state.configPath "$InstallDir\opencode.mcp.json" --remove-owned
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove the OpenCode integration. Existing configuration was preserved.' }
    }
}
$settingsFile = Join-Path $InstallDir 'installation.json'
if (Test-Path -LiteralPath $settingsFile) {
    $settings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.backend -eq 'kicad') { return }
}
$pointer = if ($env:EDA_AGENT_POINTER_FILE) { $env:EDA_AGENT_POINTER_FILE } else { 'C:\ProgramData\eda-agent\workspace-path.txt' }
if (Test-Path -LiteralPath $pointer -PathType Leaf) {
    $workspace = [IO.File]::ReadAllText($pointer, [Text.Encoding]::Default).TrimEnd('\')
    if ($workspace -eq "$InstallDir\workspace") { Remove-Item -LiteralPath $pointer }
}
