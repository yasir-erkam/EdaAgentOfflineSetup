[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+(\.\d+)?$')][string]$Tag,
    [string]$ReleaseDirectory = (Join-Path $PSScriptRoot 'dist\release')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $env:GITHUB_TOKEN -or $env:GITHUB_REPOSITORY -notmatch '^[\w.-]+/[\w.-]+$') {
    throw 'GITHUB_TOKEN and GITHUB_REPOSITORY are required.'
}
$version = $Tag.Substring(1)
$config = Get-Content (Join-Path $PSScriptRoot 'release-source.json') -Raw | ConvertFrom-Json
$files = @()
foreach ($backend in @('altium', 'kicad')) {
    $name = "EdaAgentOfflineSetup-$version-$backend"
    $installer = Get-Item -LiteralPath (Join-Path $ReleaseDirectory "$name.exe")
    if ($installer.VersionInfo.ProductVersion.Trim() -ne $version) { throw "Wrong installer version: $backend" }
    $checksum = Join-Path $ReleaseDirectory "$name.exe.sha256"
    $expected = ((Get-Content -LiteralPath $checksum -Raw).Trim() -split '\s+')
    if ($expected.Count -ne 2 -or $expected[1] -ne "$name.exe" -or $expected[0] -ne (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash) { throw "Installer checksum mismatch: $backend" }
    $manifestFile = Join-Path $ReleaseDirectory "$name.bundle.json"
    $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
    if ($manifest.backend -ne $backend -or $manifest.sourceCommit -ne $config.sourceCommit -or $manifest.pythonVersion -ne $config.pythonVersion) { throw "Wrong bundle metadata: $backend" }
    $lockFile = Join-Path $ReleaseDirectory "$name.packages.lock.txt"
    if (-not (Test-Path -LiteralPath $lockFile -PathType Leaf)) { throw "Missing package lock: $backend" }
    $files += @($installer.FullName, $checksum, $manifestFile, $lockFile)
}
$changelog = Get-Content (Join-Path $PSScriptRoot 'CHANGELOG.md') -Raw -Encoding UTF8
$section = [Regex]::Match($changelog, ('(?ms)^## ' + [Regex]::Escape($version) + '\s*\r?\n(.*?)(?=^## |\z)'))
if (-not $section.Success) { throw "Missing CHANGELOG section for $version." }
$headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$releaseApi = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/releases"
$release = $null
try {
    $release = Invoke-RestMethod -Uri "$releaseApi/tags/$Tag" -Headers $headers
} catch {
    # Preserve network/authentication errors; only a genuine 404 means absent.
    if (-not $_.Exception.PSObject.Properties['Response'] -or [int]$_.Exception.Response.StatusCode -ne 404) { throw }
}
if ($release -and -not $release.draft) {
    Write-Host "Release already published: $($release.html_url)"
    return
}
if (-not $release) {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$env:GITHUB_REPOSITORY/git/ref/tags/$Tag" -Headers $headers | Out-Null
    $body = @{ tag_name = $Tag; name = "EDA Agent Offline Setup $version"; body = $section.Groups[1].Value.Trim(); draft = $true } | ConvertTo-Json
    $release = Invoke-RestMethod -Uri $releaseApi -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
}
foreach ($file in $files) {
    $name = [IO.Path]::GetFileName($file)
    foreach ($asset in @($release.assets | Where-Object { $_.name -eq $name })) {
        Invoke-RestMethod -Uri "$releaseApi/assets/$($asset.id)" -Method Delete -Headers $headers | Out-Null
    }
    $uploadUrl = ($release.upload_url -replace '\{.*\}$', '') + '?name=' + [Uri]::EscapeDataString($name)
    Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -ContentType 'application/octet-stream' -InFile $file | Out-Null
}
$published = Invoke-RestMethod -Uri "$releaseApi/$($release.id)" -Method Patch -Headers $headers -ContentType 'application/json' -Body '{"draft":false}'
Write-Host "Release published: $($published.html_url)"
