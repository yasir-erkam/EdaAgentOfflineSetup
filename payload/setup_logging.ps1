# Log only fixed event names and numeric codes, never configuration or child output.
function Write-SetupLog {
    [CmdletBinding()]
    param(
        [string]$Path,
        [ValidatePattern('^[a-z][a-z0-9-]{0,63}$')][string]$Event,
        [int]$Code = 0
    )
    if (-not $Path) { return }
    try {
        $line = '{0} event={1} code={2}' -f [DateTime]::UtcNow.ToString('o'), $Event, $Code
        [IO.File]::AppendAllText($Path, $line + "`r`n", (New-Object Text.UTF8Encoding($false)))
    } catch { Write-Warning 'Could not update the setup diagnostic log.' }
}

function New-SetupLog {
    [CmdletBinding()]
    param(
        [ValidateSet('install', 'uninstall')][string]$Operation,
        [ValidateSet('altium', 'kicad', 'unknown')][string]$Backend = 'unknown'
    )
    $name = '{0}-{1}-{2}-{3}.log' -f $Operation, $Backend, (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), [Guid]::NewGuid().ToString('N')
    foreach ($base in @($env:LOCALAPPDATA, [IO.Path]::GetTempPath())) {
        if (-not $base) { continue }
        try {
            $directory = Join-Path $base 'EdaAgentOfflineSetup\Logs'
            [void][IO.Directory]::CreateDirectory($directory)
            $path = Join-Path $directory $name
            $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
            $stream.Dispose()
            Write-SetupLog -Path $path -Event started
            return $path
        } catch { }
    }
    Write-Warning 'Could not create a setup diagnostic log.'
    return ''
}

function Export-SetupLogs {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DestinationDirectory)
    $source = Join-Path $env:LOCALAPPDATA 'EdaAgentOfflineSetup\Logs'
    $files = @(Get-ChildItem -LiteralPath $source -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(install|uninstall)-(altium|kicad|unknown)-[0-9-]+(?:-[a-f0-9]+)?\.log$' })
    if ($files.Count -eq 0) { return '' }
    # A unique folder avoids overwriting any previous support export.
    $destination = Join-Path $DestinationDirectory ('EdaAgent-Logs-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($destination)
    foreach ($file in $files) { Copy-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop }
    return $destination
}
