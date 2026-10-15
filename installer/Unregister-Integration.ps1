param([Parameter(Mandatory = $true)][string]$InstallDir)
$ErrorActionPreference = 'Stop'
$InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
$stateFile = Join-Path $InstallDir 'setup-state.json'
if (Test-Path -LiteralPath $stateFile) {
    $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.configPath) {
        & "$InstallDir\runtime\python.exe" "$InstallDir\configure_opencode.py" $state.configPath "$InstallDir\opencode.mcp.json" --remove-owned
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove the OpenCode integration. Existing configuration was preserved.' }
    }
}
$pointer = if ($env:EDA_AGENT_POINTER_FILE) { $env:EDA_AGENT_POINTER_FILE } else { 'C:\ProgramData\eda-agent\workspace-path.txt' }
if (Test-Path -LiteralPath $pointer -PathType Leaf) {
    $workspace = [IO.File]::ReadAllText($pointer, [Text.Encoding]::Default).TrimEnd('\')
    if ($workspace -eq "$InstallDir\workspace") { Remove-Item -LiteralPath $pointer }
}
