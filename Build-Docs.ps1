[CmdletBinding()]
param(
    [string]$EdgePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js 20+ is required. Install Node.js, then run npm ci --prefix tools/docs from the repository root.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools\docs\node_modules\markdown-it\package.json'))) {
    throw 'Documentation dependencies are missing. Run: npm ci --prefix tools/docs'
}
if (-not $EdgePath) {
    $candidates = @()
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if ($base) { $candidates += Join-Path $base 'Microsoft\Edge\Application\msedge.exe' }
    }
    $EdgePath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $EdgePath -or -not (Test-Path -LiteralPath $EdgePath -PathType Leaf)) {
    throw 'Microsoft Edge is required for headless PDF rendering. Install Edge or supply -EdgePath C:\path\to\msedge.exe.'
}
& $node.Source (Join-Path $PSScriptRoot 'tools\docs\docs.mjs') build $EdgePath
if ($LASTEXITCODE -ne 0) { throw "Documentation PDF generation failed (exit $LASTEXITCODE). See the renderer error above." }
