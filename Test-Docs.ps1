[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $node) { throw 'Node.js 20+ is required. Install Node.js, then run npm ci --prefix tools/docs from the repository root.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools\docs\node_modules\markdown-it\package.json'))) {
    throw 'Documentation dependencies are missing. Run: npm ci --prefix tools/docs'
}
& $node.Source (Join-Path $PSScriptRoot 'tools\docs\docs.mjs') check
if ($LASTEXITCODE -ne 0) { throw "Documentation link validation failed (exit $LASTEXITCODE). Fix the file:line errors above." }
