[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$BundlePath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path
$project = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $project ('.work\menu-setup-test-' + [Guid]::NewGuid().ToString('N'))
$working = Join-Path $testRoot 'Türkçe kurulum alanı'
New-Item -ItemType Directory -Path $testRoot | Out-Null
Copy-Item -LiteralPath $BundlePath -Destination $working -Recurse
$oldPointer = $env:EDA_AGENT_POINTER_FILE
$env:EDA_AGENT_POINTER_FILE = Join-Path $testRoot 'pointer\workspace-path.txt'
$utf8 = New-Object Text.UTF8Encoding($false)
try {
    # Full bundle integrity is covered by Test-OfflineBundle. This fixture
    # exercises state migration/rollback and intentionally keeps a small
    # ConfigureExisting manifest, avoiding four rehashes of 7,000+ runtime files.
    $fixtureRows = @(foreach ($name in @('Install-Offline.ps1', 'launch.py', 'altium_menu.py', 'configure_opencode.py', 'runtime/python.exe')) {
        [ordered]@{ path = $name; sha256 = (Get-FileHash -LiteralPath (Join-Path $working $name)).Hash.ToLowerInvariant() }
    })
    [IO.File]::WriteAllText("$working\checksums.json", (ConvertTo-Json -InputObject $fixtureRows -Depth 5), $utf8)
    [IO.File]::WriteAllText("$working\setup-state.json", '{"configPath":null,"futureField":"preserve"}', $utf8)
    & "$working\Install-Offline.ps1" -BundlePath $working -InstallDir $working -ConfigureExisting -EnableAltiumMenu
    $state = Get-Content "$working\setup-state.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.schemaVersion -ne 2 -or $state.futureField -ne 'preserve' -or
        $state.altiumMenu.status -ne 'pending-user-registration' -or $state.altiumMenu.profileModified) { throw 'Invalid menu state migration.' }
    if (-not (Test-Path "$working\scripts\ConnectionAssistant.pas") -or -not (Test-Path "$working\workspace\eda-menu-enabled")) { throw 'Menu files were not prepared.' }
    $commands = [IO.File]::ReadAllText("$working\Altium-Menu-Commands.txt", [Text.Encoding]::UTF8)
    $parameterLines = @($commands -split '\r?\n' | Where-Object { $_.StartsWith('Parameters: ') })
    $expectedProcedures = @('ShowConnectionAssistant', 'StartConnectionAssistant', 'StatusConnectionAssistant', 'DisconnectConnectionAssistant', 'ReconnectConnectionAssistant')
    if ($parameterLines.Count -ne $expectedProcedures.Count) { throw 'Command file must expose exactly five manual commands.' }
    foreach ($procedure in $expectedProcedures) {
        $expected = 'Parameters: ProjectName=' + $working + '\scripts\Altium_API.PrjScr|ProcName=ConnectionAssistant.pas>' + $procedure
        if (@($parameterLines | Where-Object { $_ -eq $expected }).Count -ne 1) { throw "Missing or duplicate manual command: $procedure" }
    }
    $owner = $state.altiumMenu.installationId
    # Omitting the option preserves an earlier manually registered integration.
    & "$working\Install-Offline.ps1" -BundlePath $working -InstallDir $working -ConfigureExisting
    $state = Get-Content "$working\setup-state.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.altiumMenu.installationId -ne $owner -or $state.futureField -ne 'preserve' -or
        -not (Test-Path "$working\workspace\eda-menu-enabled")) { throw 'Reinstallation lost menu state.' }
    $before = @{}
    foreach ($name in @('setup-state.json', 'Altium-Menu-Commands.txt', 'workspace\eda-menu-enabled')) {
        $before[$name] = (Get-FileHash -LiteralPath (Join-Path $working $name)).Hash
    }
    $config = Join-Path $testRoot 'readonly.jsonc'
    [IO.File]::WriteAllText($config, '{"mcp":{}}', $utf8)
    (Get-Item $config).IsReadOnly = $true
    try {
        $rejected = $false
        try { & "$working\Install-Offline.ps1" -BundlePath $working -InstallDir $working -ConfigureExisting -EnableAltiumMenu -ConfigureOpenCode -OpenCodeConfig $config } catch { $rejected = $true }
        if (-not $rejected) { throw 'Read-only config update was not rejected.' }
        foreach ($name in $before.Keys) {
            if ((Get-FileHash -LiteralPath (Join-Path $working $name)).Hash -ne $before[$name]) { throw "Rollback lost menu state: $name" }
        }
    } finally { (Get-Item $config).IsReadOnly = $false }
    & "$working\runtime\python.exe" "$PSScriptRoot\verify_scripts.py" "$working\scripts"
    if ($LASTEXITCODE -ne 0) { throw 'Deployed menu overlay/stamps differ.' }
    & "$working\runtime\python.exe" "$PSScriptRoot\probe_mcp.py" "$working\launch.py"
    if ($LASTEXITCODE -ne 0) { throw 'Guarded menu launcher failed the offline MCP probe.' }
    Write-Host "PASS: manual menu preparation, old-state migration, ownership preservation, rollback, Turkish path, script stamps. Files: $testRoot"
} finally {
    if ($null -eq $oldPointer) { Remove-Item Env:EDA_AGENT_POINTER_FILE -ErrorAction SilentlyContinue } else { $env:EDA_AGENT_POINTER_FILE = $oldPointer }
}
