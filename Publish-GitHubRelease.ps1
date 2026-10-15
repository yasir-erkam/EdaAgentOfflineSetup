[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+(\.\d+)?$')][string]$Tag,
    [string]$ReleaseDirectory = (Join-Path $PSScriptRoot 'dist\release')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest
function Get-HttpStatusCode([Exception]$Exception) {
    if ($Exception.PSObject.Properties['Response'] -and $null -ne $Exception.Response -and $Exception.Response.PSObject.Properties['StatusCode']) {
        return [int]$Exception.Response.StatusCode
    }
    return 0
}
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
    $release = Invoke-RestMethod -Uri "$releaseApi/tags/$Tag" -Headers $headers -TimeoutSec 60
} catch {
    # Preserve network/authentication errors; only a genuine 404 means absent.
    if ((Get-HttpStatusCode $_.Exception) -ne 404) { throw }
}
if ($release -and -not $release.draft) {
    Write-Host "Release already published: $($release.html_url)"
    return
}
if (-not $release) {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$env:GITHUB_REPOSITORY/git/ref/tags/$Tag" -Headers $headers -TimeoutSec 60 | Out-Null
    $body = @{ tag_name = $Tag; name = "EDA Agent Offline Setup $version"; body = $section.Groups[1].Value.Trim(); draft = $true } | ConvertTo-Json
    $release = Invoke-RestMethod -Uri $releaseApi -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
}
foreach ($file in $files) {
    $name = [IO.Path]::GetFileName($file)
    $uploadUrl = ($release.upload_url -replace '\{.*\}$', '') + '?name=' + [Uri]::EscapeDataString($name)
    $sizeMiB = [Math]::Round((Get-Item -LiteralPath $file).Length / 1MB, 1)
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        if ($attempt -gt 1) {
            # A disconnected POST can leave an uploaded or empty asset behind.
            $release = Invoke-RestMethod -Uri "$releaseApi/$($release.id)" -Headers $headers -TimeoutSec 60
        }
        if (-not $release.draft) { throw 'Release was published during upload; refusing to change its assets.' }
        foreach ($asset in @($release.assets | Where-Object { $_.name -eq $name })) {
            Invoke-RestMethod -Uri "$releaseApi/assets/$($asset.id)" -Method Delete -Headers $headers -TimeoutSec 60 | Out-Null
        }
        Write-Host "Uploading $name ($sizeMiB MiB), attempt $attempt/3..."
        $timer = [Diagnostics.Stopwatch]::StartNew()
        try {
            Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -ContentType 'application/octet-stream' -InFile $file -TimeoutSec 600 | Out-Null
            Write-Host "Uploaded $name in $([Math]::Round($timer.Elapsed.TotalSeconds, 1))s."
            break
        } catch {
            $status = Get-HttpStatusCode $_.Exception
            if ($attempt -eq 3 -or $status -notin @(0, 408, 429, 500, 502, 503, 504)) {
                throw "Upload failed for $name after $attempt attempt(s): $($_.Exception.Message)"
            }
            Write-Warning "Upload interrupted for $name (HTTP $status); retrying."
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}
Write-Host "All $($files.Count) assets uploaded. Publishing $Tag..."
$published = Invoke-RestMethod -Uri "$releaseApi/$($release.id)" -Method Patch -Headers $headers -ContentType 'application/json' -Body '{"draft":false}' -TimeoutSec 60
Write-Host "Release published: $($published.html_url)"
