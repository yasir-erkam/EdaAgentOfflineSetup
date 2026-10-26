[CmdletBinding()]
param(
    [string]$BundlePath,
    [ValidateSet('altium', 'kicad')][string]$Backend = 'altium',
    [ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')][string]$SetupVersion = '0.1.7',
    [string]$IsccPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $BundlePath) {
    $candidates = @(Get-ChildItem (Join-Path $PSScriptRoot 'dist') -Directory -Filter "EdaAgent-$Backend-*" |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'checksums.json') } | Sort-Object LastWriteTime -Descending)
    if ($candidates.Count -eq 0) { throw 'No prepared bundle. Run Build-OfflineBundle.ps1 first.' }
    $BundlePath = $candidates[0].FullName
}
$BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path.TrimEnd('\')
$rows = Get-Content -LiteralPath "$BundlePath\checksums.json" -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($row in $rows) {
    $path = [IO.Path]::GetFullPath((Join-Path $BundlePath $row.path))
    if (-not $path.StartsWith($BundlePath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe bundle path.' }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $row.sha256) { throw "Bundle checksum mismatch: $($row.path)" }
}
# Refuse a stale bundle when packaging recently changed runtime/setup helpers.
foreach ($name in @('Install-Offline.ps1', 'README.md', 'LICENSE')) {
    if ((Get-FileHash (Join-Path $PSScriptRoot $name)).Hash -ne (Get-FileHash (Join-Path $BundlePath $name)).Hash) { throw "Stale bundle: $name. Prepare a new bundle." }
}
foreach ($name in @('launch.py', 'configure_opencode.py', 'Start-EdaAgent.cmd', 'setup_logging.ps1')) {
    if ((Get-FileHash (Join-Path $PSScriptRoot "payload\$name")).Hash -ne (Get-FileHash (Join-Path $BundlePath $name)).Hash) { throw "Stale bundle: $name. Prepare a new bundle." }
}
if (-not $IsccPath) {
    $found = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($found) { $IsccPath = $found.Source }
    else {
        $locations = @(
            (Join-Path $PSScriptRoot '.tools\InnoSetup\ISCC.exe'),
            (Join-Path (Split-Path $PSScriptRoot -Parent) 'OpencodeSetup\.tools\InnoSetup\ISCC.exe'),
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        )
        $IsccPath = $locations | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
}
if (-not $IsccPath) { throw 'Inno Setup 6 compiler not found. Supply -IsccPath.' }
$metadata = Get-Content -LiteralPath "$BundlePath\bundle.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($metadata.backend -notin @('altium', 'kicad')) { throw 'Unsupported backend.' }
if ($metadata.backend -eq 'altium') {
    if ((Get-FileHash (Join-Path $PSScriptRoot 'payload\altium\altium_menu.py')).Hash -ne (Get-FileHash (Join-Path $BundlePath 'altium_menu.py')).Hash) { throw 'Stale Altium menu controller. Prepare a new bundle.' }
    if ((Get-FileHash (Join-Path $PSScriptRoot 'installer\Connection-Assistant.ps1')).Hash -ne (Get-FileHash (Join-Path $BundlePath 'Connection-Assistant.ps1')).Hash) { throw 'Stale Connection Assistant. Prepare a new bundle.' }
    & "$BundlePath\runtime\python.exe" (Join-Path $PSScriptRoot 'installer\apply_altium_menu.py') "$BundlePath\runtime\Lib\site-packages\eda_agent\scripts" --verify
    if ($LASTEXITCODE -ne 0) { throw 'Altium menu patch is stale or modified. Prepare a new bundle.' }
}
foreach ($file in @(Get-ChildItem (Join-Path $PSScriptRoot 'docs') -File | Where-Object Extension -in @('.md', '.pdf')) + @(Get-ChildItem (Join-Path $PSScriptRoot 'docs\images') -File -Recurse -ErrorAction SilentlyContinue)) {
    $relative = $file.FullName.Substring((Join-Path $PSScriptRoot 'docs').Length + 1)
    $bundled = Join-Path $BundlePath "docs\$relative"
    if (-not (Test-Path -LiteralPath $bundled -PathType Leaf) -or (Get-FileHash $file.FullName).Hash -ne (Get-FileHash $bundled).Hash) {
        throw "Stale bundle documentation: $relative. Prepare a new bundle."
    }
}
if ($PSBoundParameters.ContainsKey('Backend') -and $metadata.backend -ne $Backend) { throw 'BundlePath does not match the requested backend.' }
$generated = Join-Path $PSScriptRoot "dist\installer-uninstall-files-$($metadata.backend).iss"
$lines = @(Get-ChildItem "$BundlePath\runtime\Lib\site-packages\eda_agent\scripts" -File | Where-Object Extension -in @('.pas', '.dfm', '.PrjScr') | ForEach-Object {
    'Type: files; Name: "{app}\scripts\' + $_.Name + '"'
})
[IO.File]::WriteAllLines($generated, [string[]]$lines, (New-Object Text.UTF8Encoding($true)))
& $IsccPath "/DPayloadDir=$BundlePath" "/DSetupVersion=$SetupVersion" "/DBackend=$($metadata.backend)" "/DGeneratedFiles=$generated" (Join-Path $PSScriptRoot 'EdaAgentOfflineSetup.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup build failed: $LASTEXITCODE" }
$outputFile = Join-Path $PSScriptRoot "dist\EdaAgentOfflineSetup-$SetupVersion-$($metadata.backend).exe"
if (-not (Test-Path -LiteralPath $outputFile)) { throw 'Installer output missing.' }
$hash = (Get-FileHash $outputFile -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($outputFile + '.sha256', "$hash  $([IO.Path]::GetFileName($outputFile))`r`n", [Text.Encoding]::ASCII)
Write-Host "Installer ready: $outputFile"
