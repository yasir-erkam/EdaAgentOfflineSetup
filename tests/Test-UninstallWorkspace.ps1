[CmdletBinding()]
param([string]$IsccPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = Split-Path $PSScriptRoot -Parent
if (-not $IsccPath) { $IsccPath = Join-Path $project '.tools\InnoSetup\ISCC.exe' }
$testRoot = Join-Path $project ('.work\uninstall-workspace-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$source = [IO.File]::ReadAllText((Join-Path $project 'EdaAgentOfflineSetup.iss'))
$section = [regex]::Match($source, '(?ms)^\[UninstallDelete\]\s*\r?\n(.*?)(?=^\[)').Groups[1].Value
if (-not $section) { throw 'Missing uninstall cleanup section.' }
# Exercise the real cleanup rules without packaging the runtime or touching product registrations.
$rules = ($section -split '\r?\n' | Where-Object { $_ -notmatch '^#include ' }) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $testRoot 'payload.txt'), 'fixture')
function Invoke-FixtureProcess([string]$Executable, [string[]]$Arguments) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Fixture process failed: $Executable ($($process.ExitCode))" }
}
foreach ($backend in @('altium', 'kicad')) {
$fixture = @"
[Setup]
AppName=EDA Agent workspace cleanup fixture
AppVersion=1.0
AppId=EdaAgentWorkspaceFixture-$([Guid]::NewGuid().ToString('N'))
DefaultDirName=$testRoot\installed
PrivilegesRequired=lowest
CreateUninstallRegKey=no
DisableProgramGroupPage=yes
OutputDir=$testRoot
OutputBaseFilename=workspace-fixture
Compression=none
[Files]
Source: "$testRoot\payload.txt"; DestDir: "{app}"
[UninstallDelete]
$rules
"@
$fixturePath = Join-Path $testRoot 'fixture.iss'
[IO.File]::WriteAllText($fixturePath, $fixture, (New-Object Text.UTF8Encoding($true)))
& $IsccPath '/Q' ('/DBackend=' + $backend) $fixturePath
if ($LASTEXITCODE -ne 0) { throw "Fixture compilation failed: $LASTEXITCODE" }
foreach ($scenario in @('empty', 'menu-markers', 'user-data')) {
    $installed = Join-Path $testRoot ($backend + '-' + $scenario)
    Invoke-FixtureProcess (Join-Path $testRoot 'workspace-fixture.exe') @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', ('/DIR="' + $installed + '"'))
    $workspace = Join-Path $installed 'workspace'
    [void][IO.Directory]::CreateDirectory($workspace)
    if ($scenario -eq 'menu-markers') {
        [IO.File]::WriteAllText((Join-Path $workspace 'eda-menu-enabled'), '1')
        [IO.File]::WriteAllText((Join-Path $workspace 'eda-menu-state.json'), '{}')
        [void][IO.Directory]::CreateDirectory((Join-Path $workspace 'eda-menu-session.lock'))
        if ($backend -eq 'kicad') {
            # KiCad never owns Altium markers; they must prevent directory removal.
            [IO.File]::WriteAllText((Join-Path $installed 'user-notes.txt'), 'user notes')
        }
    }
    if ($scenario -eq 'user-data') {
        [void][IO.Directory]::CreateDirectory((Join-Path $workspace 'designs'))
        [IO.File]::WriteAllText((Join-Path $workspace 'designs\board.kicad_pcb'), 'user design')
        [IO.File]::WriteAllText((Join-Path $workspace 'hidden.txt'), 'hidden user file')
        [IO.File]::SetAttributes((Join-Path $workspace 'hidden.txt'), [IO.FileAttributes]::Hidden)
        [IO.File]::WriteAllText((Join-Path $installed 'user-notes.txt'), 'user notes')
    }
    Invoke-FixtureProcess (Join-Path $installed 'unins000.exe') @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
    if ($scenario -eq 'user-data') {
        if ([IO.File]::ReadAllText((Join-Path $workspace 'designs\board.kicad_pcb')) -ne 'user design' -or
            [IO.File]::ReadAllText((Join-Path $workspace 'hidden.txt')) -ne 'hidden user file' -or
            [IO.File]::ReadAllText((Join-Path $installed 'user-notes.txt')) -ne 'user notes') { throw 'Uninstall changed user content.' }
    } elseif ($scenario -eq 'menu-markers' -and $backend -eq 'kicad') {
        if (-not (Test-Path -LiteralPath (Join-Path $workspace 'eda-menu-enabled'))) { throw 'KiCad removed Altium markers.' }
    } elseif (Test-Path -LiteralPath $installed) { throw "Uninstall left an empty installation: $scenario" }
    Write-Host "PASS: $backend $scenario"
}
}
Write-Host "PASS: actual Inno cleanup removes empty workspace/install folders, removes known menu markers, preserves nested/hidden workspace files and unrelated install files. Fixtures: $testRoot"
