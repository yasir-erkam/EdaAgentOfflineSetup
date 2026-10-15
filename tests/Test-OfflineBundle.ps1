[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$BundlePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = Split-Path $PSScriptRoot -Parent
$BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path
$installer = Join-Path $BundlePath 'Install-Offline.ps1'
$testRoot = Join-Path $project ('.work\test-' + [Guid]::NewGuid().ToString('N'))
$install = Join-Path $testRoot 'Installed with spaces'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$oldPointer = $env:EDA_AGENT_POINTER_FILE
$env:EDA_AGENT_POINTER_FILE = Join-Path $testRoot 'pointer\workspace-path.txt'
try {
    $config = Join-Path $testRoot 'opencode.jsonc'
    $fixture = @'
{
  // Keep values even when strings contain comment-like characters.
  "provider": {"internal": {"options": {"apiKey": "test-key", "url": "https://example.invalid/a/*b*/,}"}}},
  "mcp": {"existing": {"type": "local", "command": ["example"], "enabled": false}},
  "description": "Quoted \"value\" // still a string",
}
'@
    [IO.File]::WriteAllText($config, $fixture, (New-Object Text.UTF8Encoding($false)))
    & $installer -BundlePath ($BundlePath + '\') -InstallDir $install -ConfigureOpenCode -OpenCodeConfig $config
    $result = Get-Content $config -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($result.provider.internal.options.apiKey -ne 'test-key') { throw 'API key changed.' }
    if ($result.provider.internal.options.url -ne 'https://example.invalid/a/*b*/,}') { throw 'URL changed.' }
    if ($result.mcp.existing.enabled -ne $false) { throw 'Unrelated MCP changed.' }
    if ($result.mcp.'eda-agent'.command[0] -ne "$install\runtime\python.exe") { throw 'Wrong launch path.' }
    if ($result.mcp.'eda-agent'.timeout -ne 60000) { throw 'Startup timeout missing.' }
    if (@(Get-ChildItem $testRoot -Filter '*.bak').Count -ne 1) { throw 'Backup missing.' }
    $badConfig = Join-Path $testRoot 'invalid.jsonc'
    [IO.File]::WriteAllText($badConfig, '{"broken": /*', (New-Object Text.UTF8Encoding($false)))
    $before = (Get-FileHash $badConfig).Hash
    & "$install\runtime\python.exe" "$install\configure_opencode.py" $badConfig "$install\opencode.mcp.json"
    if ($LASTEXITCODE -eq 0 -or (Get-FileHash $badConfig).Hash -ne $before) { throw 'Malformed config was not preserved.' }
    $pointerBefore = (Get-FileHash $env:EDA_AGENT_POINTER_FILE).Hash
    $rejected = $false
    try { & $installer -BundlePath $BundlePath -InstallDir "$testRoot\invalid-config-install" -ConfigureOpenCode -OpenCodeConfig $badConfig } catch { $rejected = $true }
    if (-not $rejected -or (Test-Path "$testRoot\invalid-config-install")) { throw 'Invalid config created a partial installation.' }
    if ((Get-FileHash $env:EDA_AGENT_POINTER_FILE).Hash -ne $pointerBefore) { throw 'Invalid config changed the workspace pointer.' }
    $readOnlyConfig = Join-Path $testRoot 'readonly.jsonc'
    [IO.File]::WriteAllText($readOnlyConfig, '{"provider":{"test":{"options":{"apiKey":"unchanged"}}}}')
    $originalHash = (Get-FileHash $readOnlyConfig).Hash
    (Get-Item $readOnlyConfig).IsReadOnly = $true
    try {
        $rejected = $false
        try { & $installer -BundlePath $BundlePath -InstallDir "$testRoot\rollback-install" -ConfigureOpenCode -OpenCodeConfig $readOnlyConfig } catch { $rejected = $true }
        if (-not $rejected -or (Test-Path "$testRoot\rollback-install")) { throw 'Failed installation was not rolled back.' }
        if ((Get-FileHash $readOnlyConfig).Hash -ne $originalHash) { throw 'Read-only config changed.' }
        if ((Get-FileHash $env:EDA_AGENT_POINTER_FILE).Hash -ne $pointerBefore) { throw 'Previous Altium pointer was not restored.' }
    } finally { (Get-Item $readOnlyConfig).IsReadOnly = $false }
    $rejected = $false
    try { & $installer -BundlePath $BundlePath -InstallDir $install } catch { $rejected = $true }
    if (-not $rejected) { throw 'Existing installation was overwritten.' }
    $tampered = Join-Path $testRoot 'tampered'
    New-Item -ItemType Directory -Path $tampered -Force | Out-Null
    Set-Content "$tampered\sample.txt" 'modified'
    [IO.File]::WriteAllText("$tampered\checksums.json", '[{"path":"sample.txt","sha256":"0000"}]')
    $rejected = $false
    try { & $installer -BundlePath $tampered -InstallDir "$testRoot\must-not-exist" } catch { $rejected = $true }
    if (-not $rejected -or (Test-Path "$testRoot\must-not-exist")) { throw 'Tampered bundle was not rejected before copying.' }
    & "$install\runtime\python.exe" "$PSScriptRoot\probe_mcp.py" "$install\launch.py"
    if ($LASTEXITCODE -ne 0) { throw 'MCP protocol probe failed.' }
    $health = & "$install\Start-EdaAgent.cmd" health
    $healthExit = $LASTEXITCODE
    $health | Write-Output
    if ($healthExit -ne 0 -or ($health -join "`n") -notmatch 'deployed scripts current') { throw 'Installed CMD launcher / deployed scripts health failed.' }
    # Upstream compares stamped deployment files against unstamped sources and
    # warns even on a clean install. Independently verify the expected stamp.
    & "$install\runtime\python.exe" "$PSScriptRoot\verify_scripts.py" "$install\scripts"
    if ($LASTEXITCODE -ne 0) { throw 'Deployed Altium script contents differ from the packaged release.' }
    & "$install\runtime\python.exe" "$PSScriptRoot\test_configure.py" "$install\configure_opencode.py"
    if ($LASTEXITCODE -ne 0) { throw 'JSONC regression tests failed.' }
    Write-Host "PASS: offline install, config merge/backup/preflight, rollback, existing destination, tamper rejection, MCP handshake without external network, CMD launcher. Test files: $testRoot"
} finally {
    if ($null -eq $oldPointer) { Remove-Item Env:EDA_AGENT_POINTER_FILE -ErrorAction SilentlyContinue } else { $env:EDA_AGENT_POINTER_FILE = $oldPointer }
}
