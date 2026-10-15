[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$InstallerPath)
$ErrorActionPreference = 'Stop'
$InstallerPath = (Resolve-Path -LiteralPath $InstallerPath).Path
$project = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $project ('.work\wizard-test-' + [Guid]::NewGuid().ToString('N'))
$install = Join-Path $testRoot 'Installed EDA'
$registration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{5CC17F09-79DA-4E93-8587-D5A16DD19AD6}_is1'
if (Test-Path $registration) { throw 'An EDA Agent wizard installation already exists. Use a disposable Windows account for this test.' }
New-Item -ItemType Directory -Path $testRoot | Out-Null
$config = Join-Path $testRoot 'opencode.jsonc'
$original = '{"provider":{"test":{"options":{"apiKey":"preserve-this"}}},"mcp":{"other":{"enabled":false,"type":"local","command":["other.exe"]}}}'
[IO.File]::WriteAllText($config, $original, (New-Object Text.UTF8Encoding($false)))
$oldPointer = $env:EDA_AGENT_POINTER_FILE
$env:EDA_AGENT_POINTER_FILE = Join-Path $testRoot 'pointer\workspace-path.txt'
function Invoke-Wizard([string]$Language, [string]$Destination, [string]$ConfigFile) {
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOICONS', '/TASKS=opencode', "/LANG=$Language",
        ('/DIR="' + $Destination + '"'), ('/OPENCODECONFIG="' + $ConfigFile + '"'), ('/LOG="' + "$testRoot\setup-$Language.log" + '"'))
    $process = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    return $process.ExitCode
}
try {
    $bad = Join-Path $testRoot 'invalid.jsonc'
    [IO.File]::WriteAllText($bad, '{broken')
    $badExit = Invoke-Wizard 'english' "$testRoot\Invalid install" $bad
    if ($badExit -eq 0 -or (Test-Path "$testRoot\Invalid install\runtime\python.exe")) { throw 'Invalid config was not rejected before copying files.' }
    if (Test-Path $registration) { throw 'Failed preflight registered an installation.' }
    $installExit = Invoke-Wizard 'turkish' $install $config
    if ($installExit -ne 0) { throw "Wizard installation failed: $installExit. Logs: $testRoot" }
    $result = Get-Content $config -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($result.provider.test.options.apiKey -ne 'preserve-this' -or $result.mcp.other.enabled -ne $false -or -not $result.mcp.'eda-agent'.enabled) { throw 'Wizard configuration merge failed.' }
    if (-not (Test-Path "$install\Connection-Assistant.ps1") -or -not (Test-Path "$install\scripts\Altium_API.PrjScr")) { throw 'Assistant or Altium project missing.' }
    if (-not (Test-Path $registration)) { throw 'Windows uninstall registration missing.' }
    $sentinel = Join-Path $install 'workspace\preserve-user-data.txt'
    [IO.File]::WriteAllText($sentinel, 'keep')
    $secondExit = Invoke-Wizard 'english' $install $config
    if ($secondExit -ne 0) { throw "Wizard reinstallation failed: $secondExit" }
    if ([IO.File]::ReadAllText($sentinel) -ne 'keep') { throw 'Reinstallation changed workspace data.' }
    $stateBefore = (Get-FileHash "$install\setup-state.json").Hash
    $locked = Join-Path $testRoot 'readonly-other-config.jsonc'
    [IO.File]::WriteAllText($locked, '{"mcp":{}}')
    (Get-Item $locked).IsReadOnly = $true
    try {
        $failedUpdate = Invoke-Wizard 'english' $install $locked
        if ($failedUpdate -eq 0) { throw 'Read-only configuration was silently accepted.' }
        if (-not (Test-Path "$install\runtime\python.exe") -or -not (Test-Path $registration)) { throw 'Failed update removed the existing application.' }
        if ((Get-FileHash "$install\setup-state.json").Hash -ne $stateBefore) { throw 'Failed update did not restore integration ownership.' }
    } finally { (Get-Item $locked).IsReadOnly = $false }
    & "$install\runtime\python.exe" "$PSScriptRoot\probe_mcp.py" "$install\launch.py"
    if ($LASTEXITCODE -ne 0) { throw 'Installed GUI package failed the offline MCP probe.' }
    $uninstall = Start-Process -FilePath "$install\unins000.exe" -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/LOG="' + "$testRoot\uninstall.log" + '"')) -WindowStyle Hidden -PassThru -Wait
    if ($uninstall.ExitCode -ne 0) { throw "Uninstall failed: $($uninstall.ExitCode)" }
    $remaining = Get-Content $config -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($remaining.mcp.PSObject.Properties.Name -contains 'eda-agent') { throw 'Uninstall left the owned MCP entry.' }
    if ($remaining.provider.test.options.apiKey -ne 'preserve-this' -or $remaining.mcp.other.enabled -ne $false) { throw 'Uninstall changed unrelated settings.' }
    if (Test-Path "$install\runtime\python.exe") { throw 'Uninstall left the Python runtime.' }
    if (Test-Path $env:EDA_AGENT_POINTER_FILE) { throw 'Uninstall left its workspace pointer.' }
    if ([IO.File]::ReadAllText($sentinel) -ne 'keep') { throw 'Uninstall removed workspace data.' }
    if (Test-Path $registration) { throw 'Uninstall registration was not removed.' }
    Write-Host "PASS: GUI invalid-config preflight, TR install, EN reinstall, offline MCP, uninstall, preserved API key/other MCP/workspace. Logs: $testRoot"
} finally {
    if ($null -eq $oldPointer) { Remove-Item Env:EDA_AGENT_POINTER_FILE -ErrorAction SilentlyContinue } else { $env:EDA_AGENT_POINTER_FILE = $oldPointer }
}
