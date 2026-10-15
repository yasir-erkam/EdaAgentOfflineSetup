[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$OpenCodePath
)
$ErrorActionPreference = 'Stop'
$InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
$OpenCodePath = (Resolve-Path -LiteralPath $OpenCodePath).Path
$project = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $project ('.work\opencode-client-' + [Guid]::NewGuid().ToString('N'))
$values = @{
    USERPROFILE = $testRoot
    APPDATA = "$testRoot\Roaming"
    LOCALAPPDATA = "$testRoot\Local"
    XDG_CONFIG_HOME = "$testRoot\config"
    XDG_DATA_HOME = "$testRoot\data"
    XDG_CACHE_HOME = "$testRoot\cache"
    XDG_STATE_HOME = "$testRoot\state"
    OPENCODE_CONFIG_DIR = "$testRoot\config\opencode"
    OPENCODE_CONFIG = "$testRoot\config\opencode\opencode.json"
    OPENCODE_DISABLE_MODELS_FETCH = '1'
    EDA_AGENT_POINTER_FILE = "$testRoot\workspace-path.txt"
}
$previous = @{}
try {
    foreach ($name in $values.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $values[$name], 'Process')
    }
    New-Item -ItemType Directory -Path $values.OPENCODE_CONFIG_DIR -Force | Out-Null
    # Use the generated settings, not a separately reconstructed MCP entry.
    Copy-Item -LiteralPath "$InstallDir\opencode.mcp.json" -Destination $values.OPENCODE_CONFIG
    # Windows PowerShell treats even native ANSI/status stderr as ErrorRecords.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $OpenCodePath mcp list 2>&1 | ForEach-Object { $_.ToString() } | Out-String
        $clientExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    Write-Output $output
    # OpenCode can return zero even when the MCP spawn fails.
    $plain = [regex]::Replace($output, '\x1B\[[0-?]*[ -/]*[@-~]', '')
    if ($clientExit -ne 0 -or $plain -notmatch '\beda-agent\b[^\r\n]*\bconnected\b') {
        throw "OpenCode did not connect to eda-agent. Isolated client files: $testRoot"
    }
    Write-Host "PASS: real OpenCode client connected. Isolated client files: $testRoot"
} finally {
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
