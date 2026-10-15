[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
    [ValidatePattern('^v\d+\.\d+\.\d+(\.\d+)?$')][string]$Tag = 'v0.1.1'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$version = $Tag.Substring(1)
$fixture = Join-Path $projectRoot ('.work\release-test-' + [Guid]::NewGuid().ToString('N'))
$oldToken = $env:GITHUB_TOKEN
$oldRepository = $env:GITHUB_REPOSITORY
$global:edaReleaseTestCalls = [Collections.Generic.List[string]]::new()
$global:edaReleaseTestMode = 'success'
function Invoke-RestMethod {
    param($Uri, $Method = 'Get', $Headers, $ContentType, $Body, $InFile)
    if ($Headers.Authorization -ne 'Bearer fixture-token') { throw 'Unexpected token.' }
    $operation = if ($Uri -match '/releases/tags/') { 'lookup' }
        elseif ($Uri -match '/git/ref/tags/') { 'tag' }
        elseif ($Method -eq 'Delete') { 'delete' }
        elseif ($Uri -match '^https://uploads.github.com/') { 'upload' }
        elseif ($Method -eq 'Patch') { 'publish' }
        elseif ($Method -eq 'Post') { 'create' }
        else { throw "Unexpected API request: $Uri" }
    $global:edaReleaseTestCalls.Add($operation)
    if ($operation -eq 'lookup') {
        if ($global:edaReleaseTestMode -eq 'network') { throw 'Network unavailable.' }
        if ($global:edaReleaseTestMode -eq 'published') { return @{ draft = $false; html_url = 'https://example.invalid/release' } }
        if ($global:edaReleaseTestMode -eq 'draft') { return @{ draft = $true; id = 123; upload_url = 'https://uploads.github.com/repos/fixture/repo/releases/123/assets{?name,label}'; assets = @(@{ name = "EdaAgentOfflineSetup-$version-altium.exe"; id = 42 }) } }
        $missing = [Exception]::new('Not found')
        $missing | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = 404 })
        throw $missing
    }
    if ($operation -eq 'tag' -and $global:edaReleaseTestMode -eq 'missing-tag') { throw 'Tag not found.' }
    if ($operation -eq 'create') {
        $payload = [Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
        if (-not $payload.draft -or $payload.tag_name -ne $Tag -or -not $payload.body) { throw 'Wrong draft request.' }
        return @{ draft = $true; id = 123; upload_url = 'https://uploads.github.com/repos/fixture/repo/releases/123/assets{?name,label}'; assets = @() }
    }
    if ($operation -eq 'upload') {
        if (-not (Test-Path -LiteralPath $InFile) -or $Uri -match '\{' -or $ContentType -ne 'application/octet-stream') { throw 'Invalid upload.' }
        if ($global:edaReleaseTestMode -eq 'upload-failure') { throw 'Upload interrupted.' }
    }
    if ($operation -eq 'publish') {
        if (($Body | ConvertFrom-Json).draft -ne $false) { throw 'Expected final publication.' }
        return @{ html_url = 'https://example.invalid/release' }
    }
}
function Assert-Scenario {
    param([string]$Mode, [bool]$ShouldFail, [string]$ExpectedCalls)
    $global:edaReleaseTestMode = $Mode
    $global:edaReleaseTestCalls.Clear()
    $failed = $false
    try { & (Join-Path $projectRoot 'Publish-GitHubRelease.ps1') -Tag $Tag -ReleaseDirectory $fixture }
    catch { $failed = $true; Write-Host "Expected stop (${Mode}): $($_.Exception.Message)" }
    if ($failed -ne $ShouldFail -or ($global:edaReleaseTestCalls -join ',') -ne $ExpectedCalls) { throw "Unexpected result for ${Mode}: $($global:edaReleaseTestCalls -join ',')" }
    Write-Host "PASS: $Mode"
}
try {
    $env:GITHUB_TOKEN = 'fixture-token'
    $env:GITHUB_REPOSITORY = 'fixture/repo'
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    Copy-Item -Path (Join-Path $ReleaseDirectory '*') -Destination $fixture
    $uploads = (@('upload') * 8) -join ','
    Assert-Scenario success $false "lookup,tag,create,$uploads,publish"
    Assert-Scenario draft $false "lookup,delete,$uploads,publish"
    Assert-Scenario published $false 'lookup'
    Assert-Scenario network $true 'lookup'
    Assert-Scenario missing-tag $true 'lookup,tag'
    Assert-Scenario upload-failure $true 'lookup,tag,create,upload'
    $checksum = Join-Path $fixture "EdaAgentOfflineSetup-$version-kicad.exe.sha256"
    $originalChecksum = [IO.File]::ReadAllText($checksum)
    [IO.File]::WriteAllText($checksum, ('0' * 64) + "  EdaAgentOfflineSetup-$version-kicad.exe`r`n")
    Assert-Scenario tampered $true ''
    [IO.File]::WriteAllText($checksum, $originalChecksum)
    $manifest = Join-Path $fixture "EdaAgentOfflineSetup-$version-kicad.bundle.json"
    $metadata = Get-Content $manifest -Raw | ConvertFrom-Json
    $metadata.backend = 'altium'
    $metadata | ConvertTo-Json | Set-Content -LiteralPath $manifest
    Assert-Scenario wrong-backend $true ''
} finally {
    $env:GITHUB_TOKEN = $oldToken
    $env:GITHUB_REPOSITORY = $oldRepository
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $allowedParent = [IO.Path]::GetFullPath((Join-Path $projectRoot '.work')).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($allowedParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
