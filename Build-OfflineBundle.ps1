[CmdletBinding()]
param(
    [ValidatePattern('^3\.13\.\d+$')][string]$PythonVersion = '3.13.16',
    [ValidatePattern('^[a-fA-F0-9]{40}$')][string]$SourceCommit,
    [ValidateSet('altium', 'kicad')][string]$Backend = 'altium'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$headers = @{ 'User-Agent' = 'EdaAgentOfflineSetup' }
if (-not $SourceCommit) {
    $SourceCommit = (Invoke-RestMethod 'https://api.github.com/repos/salitronic/eda-agent/commits/main' -Headers $headers).sha
}
if ($SourceCommit -notmatch '^[a-fA-F0-9]{40}$') { throw 'Invalid upstream commit.' }
$buildId = '{0}-{1}-{2}' -f $Backend, $SourceCommit.Substring(0, 12), (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
$work = Join-Path $PSScriptRoot ".work\$buildId"
$bundle = Join-Path $PSScriptRoot "dist\EdaAgent-$buildId"
$runtime = Join-Path $bundle 'runtime'
$wheels = Join-Path $work 'wheels'
New-Item -ItemType Directory -Path $work, $runtime, $wheels -Force | Out-Null
function Invoke-Python {
    param([string[]]$Arguments)
    & "$runtime\python.exe" @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Python failed (exit $LASTEXITCODE). Bundle is incomplete: $bundle" }
}
Write-Host "Downloading Python $PythonVersion and eda-agent $SourceCommit..."
$pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
Invoke-WebRequest $pythonUrl -UseBasicParsing -OutFile "$work\python.zip"
Expand-Archive "$work\python.zip" $runtime
# Explicit paths keep the embedded runtime independent of PATH and system Python.
[IO.File]::WriteAllText("$runtime\python313._pth", "python313.zip`n.`nLib/site-packages`nimport site`n", [Text.Encoding]::ASCII)
New-Item -ItemType Directory -Path "$runtime\Lib\site-packages" -Force | Out-Null
Copy-Item "$PSScriptRoot\payload\sitecustomize.py" "$runtime\Lib\site-packages\sitecustomize.py"
Invoke-WebRequest 'https://bootstrap.pypa.io/get-pip.py' -UseBasicParsing -OutFile "$work\get-pip.py"
Invoke-Python -Arguments @("$work\get-pip.py", '--disable-pip-version-check', '--no-warn-script-location')
Invoke-WebRequest "https://codeload.github.com/salitronic/eda-agent/zip/$SourceCommit" -UseBasicParsing -OutFile "$work\source.zip"
Expand-Archive "$work\source.zip" "$work\source"
$source = Join-Path $work "source\eda-agent-$SourceCommit"
$extras = if ($Backend -eq 'kicad') { '[render,web,kicad]' } else { '[render,web]' }
# Build only upstream from source; all third-party dependencies must have Windows wheels.
# Embedded Python ignores the PYTHONPATH used by pip's build isolation.
Invoke-Python -Arguments @('-m', 'pip', 'install', '--disable-pip-version-check', '--only-binary=:all:', '--no-warn-script-location', 'hatchling')
Invoke-Python -Arguments @('-m', 'pip', 'wheel', '--disable-pip-version-check', '--no-build-isolation', '--no-deps', '--wheel-dir', $wheels, $source)
$edaWheel = @(Get-ChildItem $wheels -Filter 'eda_agent-*.whl')
if ($edaWheel.Count -ne 1) { throw 'Expected exactly one eda-agent wheel.' }
Invoke-Python -Arguments @('-m', 'pip', 'download', '--disable-pip-version-check', '--only-binary=:all:', '--dest', $wheels, ($edaWheel[0].FullName + $extras))
Invoke-Python -Arguments @('-m', 'pip', 'install', '--disable-pip-version-check', '--no-index', '--find-links', $wheels, '--no-compile', '--no-warn-script-location', ($edaWheel[0].FullName + $extras))
Invoke-Python -Arguments @('-m', 'pip', 'check')
Invoke-Python -Arguments @('-c', 'import eda_agent.server, win32api, pythoncom, comtypes, numpy, scipy, matplotlib, flask')
Write-Host 'Runtime imports OK'
Copy-Item "$PSScriptRoot\payload\*" $bundle -Exclude 'sitecustomize.py'
Copy-Item "$PSScriptRoot\Install-Offline.ps1", "$PSScriptRoot\Install.cmd", "$PSScriptRoot\README.md" $bundle
$notices = New-Item -ItemType Directory -Path "$bundle\upstream" -Force
Copy-Item "$source\LICENSE", "$source\NOTICE", "$source\README.md" $notices.FullName
$manifest = [ordered]@{
    schemaVersion = 1; backend = $Backend; sourceCommit = $SourceCommit
    sourceUrl = 'https://github.com/salitronic/eda-agent'; pythonVersion = $PythonVersion
    pythonUrl = $pythonUrl; createdUtc = [DateTime]::UtcNow.ToString('o')
    pythonArchiveSha256 = (Get-FileHash "$work\python.zip" -Algorithm SHA256).Hash.ToLowerInvariant()
    sourceArchiveSha256 = (Get-FileHash "$work\source.zip" -Algorithm SHA256).Hash.ToLowerInvariant()
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText("$bundle\bundle.json", ($manifest | ConvertTo-Json -Depth 8), $utf8)
$packages = & "$runtime\python.exe" -m pip list --format=freeze --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { throw 'Could not record installed packages.' }
[IO.File]::WriteAllLines("$bundle\packages.lock.txt", [string[]]$packages, $utf8)
$files = @(Get-ChildItem $bundle -Recurse -File | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($bundle.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
[IO.File]::WriteAllText("$bundle\checksums.json", (ConvertTo-Json -InputObject $files -Depth 5), $utf8)
Write-Host "Ready. Copy this entire folder to the offline PC: $bundle"
