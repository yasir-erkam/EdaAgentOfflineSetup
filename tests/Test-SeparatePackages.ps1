[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AltiumInstaller,
    [Parameter(Mandatory = $true)][string]$KiCadInstaller
)
$ErrorActionPreference = 'Stop'
$AltiumInstaller = (Resolve-Path -LiteralPath $AltiumInstaller).Path
$KiCadInstaller = (Resolve-Path -LiteralPath $KiCadInstaller).Path
$project = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $project ('.work\separate-test-' + [Guid]::NewGuid().ToString('N'))
$registrations = @{
    altium = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{5CC17F09-79DA-4E93-8587-D5A16DD19AD6}_is1'
    kicad = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{D3D0D6D1-7F8A-4C2E-9A41-884C86E1506B}_is1'
}
foreach ($registration in $registrations.Values) {
    if (Test-Path $registration) { throw 'An EDA Agent wizard installation already exists. Use a disposable Windows account.' }
}
New-Item -ItemType Directory -Path $testRoot | Out-Null
$profileRoot = Join-Path $testRoot 'profile'
$config = Join-Path $profileRoot '.config\opencode\opencode.jsonc'
New-Item -ItemType Directory -Path (Split-Path $config -Parent) -Force | Out-Null
[IO.File]::WriteAllText($config, '{"provider":{"test":{"options":{"apiKey":"preserve-this"}}},"mcp":{"other":{"enabled":false}}}')
$oldPointer = $env:EDA_AGENT_POINTER_FILE
$oldProfile = $env:USERPROFILE
$env:USERPROFILE = $profileRoot
$env:EDA_AGENT_POINTER_FILE = Join-Path $testRoot 'pointer\workspace-path.txt'
$locations = @{ altium = "$testRoot\Altium install"; kicad = "$testRoot\KiCad install" }
function Read-Config {
    $data = Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.provider.test.options.apiKey -ne 'preserve-this' -or $data.mcp.other.enabled -ne $false) {
        throw 'Unrelated provider or MCP settings changed.'
    }
    return $data
}
function Invoke-Installer([string]$Installer, [string]$Destination, [string]$Language, [string]$LogName) {
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOICONS', '/TASKS=opencode', "/LANG=$Language",
        ('/DIR="' + $Destination + '"'), ('/LOG="' + "$testRoot\$LogName.log" + '"'))
    $process = Start-Process -FilePath $Installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    return $process.ExitCode
}
try {
    $exitCode = Invoke-Installer $AltiumInstaller $locations.altium 'turkish' 'install-altium'
    if ($exitCode -ne 0) { throw "Altium installation failed: $exitCode. Logs: $testRoot" }
    $pointerHash = (Get-FileHash -LiteralPath $env:EDA_AGENT_POINTER_FILE).Hash
    $configHash = (Get-FileHash -LiteralPath $config).Hash
    $rejected = Invoke-Installer $KiCadInstaller $locations.altium 'english' 'reject-shared-directory'
    if ($rejected -eq 0 -or (Test-Path $registrations.kicad)) { throw 'KiCad accepted an Altium installation directory.' }
    if ((Get-FileHash -LiteralPath $config).Hash -ne $configHash) { throw 'Rejected installation modified OpenCode settings.' }
    $exitCode = Invoke-Installer $KiCadInstaller $locations.kicad 'english' 'install-kicad'
    if ($exitCode -ne 0) { throw "KiCad installation failed: $exitCode. Logs: $testRoot" }
    $data = Read-Config
    if (-not $data.mcp.'eda-agent'.enabled -or -not $data.mcp.'eda-agent-kicad'.enabled) { throw 'Both MCP entries were not registered.' }
    if ((Get-FileHash -LiteralPath $env:EDA_AGENT_POINTER_FILE).Hash -ne $pointerHash) { throw 'KiCad setup changed the Altium pointer.' }
    foreach ($backend in @('altium', 'kicad')) {
        $location = $locations[$backend]
        if (-not (Test-Path $registrations[$backend])) { throw "Missing $backend uninstall registration." }
        $metadata = Get-Content "$location\installation.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($metadata.backend -ne $backend) { throw "Wrong installed backend: $backend" }
        [IO.File]::WriteAllText("$location\workspace\preserve-user-data.txt", 'keep')
        & "$location\runtime\python.exe" "$PSScriptRoot\probe_mcp.py" "$location\launch.py"
        if ($LASTEXITCODE -ne 0) { throw "$backend offline MCP probe failed." }
    }
    if ((Get-FileHash -LiteralPath $env:EDA_AGENT_POINTER_FILE).Hash -ne $pointerHash) { throw 'MCP startup changed the Altium pointer.' }
    if (-not (Test-Path "$($locations.altium)\Connection-Assistant.ps1") -or -not (Test-Path "$($locations.altium)\scripts\Altium_API.PrjScr")) { throw 'Altium assistant or scripts missing.' }
    if ((Test-Path "$($locations.kicad)\Connection-Assistant.ps1") -or (Test-Path "$($locations.kicad)\scripts")) { throw 'KiCad deployed Altium helpers.' }
    foreach ($backend in @('kicad', 'altium')) {
        $location = $locations[$backend]
        $process = Start-Process -FilePath "$location\unins000.exe" -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/LOG="' + "$testRoot\uninstall-$backend.log" + '"')) -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw "$backend uninstall failed: $($process.ExitCode)" }
        if ((Test-Path "$location\runtime\python.exe") -or (Test-Path $registrations[$backend])) { throw "$backend uninstall left runtime or registration." }
        if ([IO.File]::ReadAllText("$location\workspace\preserve-user-data.txt") -ne 'keep') { throw 'Uninstall removed workspace data.' }
        $data = Read-Config
        $names = @($data.mcp.PSObject.Properties.Name)
        if ($backend -eq 'kicad') {
            if ($names -contains 'eda-agent-kicad' -or $names -notcontains 'eda-agent') { throw 'KiCad uninstall removed the wrong integration.' }
            if (-not (Test-Path "$($locations.altium)\runtime\python.exe") -or -not (Test-Path $registrations.altium)) { throw 'KiCad uninstall damaged Altium.' }
            if ((Get-FileHash -LiteralPath $env:EDA_AGENT_POINTER_FILE).Hash -ne $pointerHash) { throw 'KiCad uninstall changed the Altium pointer.' }
        } elseif ($names -contains 'eda-agent' -or (Test-Path $env:EDA_AGENT_POINTER_FILE)) { throw 'Altium uninstall left its integration or pointer.' }
    }
    Write-Host "PASS: default USERPROFILE config path, distinct products, shared-directory rejection, both offline MCP servers, independent uninstall, preserved provider/other MCP/workspaces. Logs: $testRoot"
} finally {
    if ($null -eq $oldProfile) { Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue } else { $env:USERPROFILE = $oldProfile }
    if ($null -eq $oldPointer) { Remove-Item Env:EDA_AGENT_POINTER_FILE -ErrorAction SilentlyContinue } else { $env:EDA_AGENT_POINTER_FILE = $oldPointer }
}
