$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$project = Split-Path $PSScriptRoot -Parent
. (Join-Path $project 'payload\setup_logging.ps1')
$testRoot = Join-Path $project ('.work\logging-test-' + [Guid]::NewGuid().ToString('N'))
$previousLocal = $env:LOCALAPPDATA
$env:LOCALAPPDATA = Join-Path $testRoot 'local'
try {
    $first = New-SetupLog -Operation install -Backend altium
    $second = New-SetupLog -Operation uninstall -Backend kicad
    if (-not $first -or -not $second -or $first -eq $second) { throw 'Log files must be unique.' }
    Write-SetupLog -Path $first -Event configuring
    Write-SetupLog -Path $first -Event failed -Code -7
    Write-SetupLog -Path $second -Event completed
    $content = [IO.File]::ReadAllText($first)
    if ($content -notmatch 'event=started code=0' -or $content -notmatch 'event=failed code=-7') { throw 'Missing diagnostic events.' }
    $rejected = $false
    try { Write-SetupLog -Path $first -Event 'apiKey=secret-value' } catch { $rejected = $true }
    if (-not $rejected -or [IO.File]::ReadAllText($first).Contains('secret-value')) { throw 'Arbitrary content was accepted as a diagnostic event.' }
    [IO.File]::WriteAllText((Join-Path (Split-Path $first) 'private-config.json'), 'secret-value')
    [IO.File]::WriteAllText((Join-Path (Split-Path $first) 'notes.log'), 'secret-value')
    $desktop = Join-Path $testRoot 'desktop'
    $export = Export-SetupLogs -DestinationDirectory $desktop
    $files = @(Get-ChildItem -LiteralPath $export -File)
    if ($files.Count -ne 2) { throw 'Export included unrelated files or omitted diagnostics.' }
    foreach ($file in $files) {
        if ((Get-FileHash $file.FullName).Hash -ne (Get-FileHash (Join-Path (Split-Path $first) $file.Name)).Hash) { throw 'Export changed the log.' }
    }
    $again = Export-SetupLogs -DestinationDirectory $desktop
    if ($again -eq $export -or -not (Test-Path -LiteralPath $first)) { throw 'Export overwrote an earlier copy or removed the original.' }
    # Diagnostic failure must not turn an otherwise successful install into a failure.
    Write-SetupLog -Path (Join-Path $testRoot 'missing\cannot-write.log') -Event failed -WarningAction SilentlyContinue
    $rejected = $false
    try { & (Join-Path $project 'Install-Offline.ps1') -BundlePath (Join-Path $testRoot 'missing-bundle') } catch { $rejected = $true }
    if (-not $rejected) { throw 'Invalid bundle was accepted.' }
    $failedLog = Get-ChildItem -LiteralPath (Split-Path $first) -Filter 'install-unknown-*.log' -File | Select-Object -Last 1
    if (-not $failedLog -or [IO.File]::ReadAllText($failedLog.FullName) -notmatch 'event=failed code=-') { throw 'Early setup failure was not logged.' }
    $installed = Join-Path $testRoot 'installed'
    [void][IO.Directory]::CreateDirectory($installed)
    Copy-Item -LiteralPath (Join-Path $project 'installer\Unregister-Integration.ps1'), (Join-Path $project 'payload\setup_logging.ps1') -Destination $installed
    [IO.File]::WriteAllText((Join-Path $installed 'installation.json'), '{"backend":"kicad"}')
    & (Join-Path $installed 'Unregister-Integration.ps1') -InstallDir $installed
    $uninstallLog = Get-ChildItem -LiteralPath (Split-Path $first) -Filter 'uninstall-unknown-*.log' -File | Select-Object -Last 1
    if (-not $uninstallLog -or [IO.File]::ReadAllText($uninstallLog.FullName) -notmatch 'event=integration-removed') { throw 'Direct integration removal was not logged.' }
    Write-Host 'PASS: unique persistent logs, safe events, filtered desktop export, preserved originals, nonfatal logging failure.'
} finally { $env:LOCALAPPDATA = $previousLocal }
