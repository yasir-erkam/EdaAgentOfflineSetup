[CmdletBinding()]
param(
    [string]$BundlePath = $PSScriptRoot,
    [string]$InstallDir,
    [switch]$ConfigureOpenCode,
    [string]$OpenCodeConfig,
    [switch]$ConfigureExisting,
    [switch]$EnableAltiumMenu,
    [string]$LogPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$loggingHelper = Join-Path $PSScriptRoot 'setup_logging.ps1'
if (-not (Test-Path -LiteralPath $loggingHelper)) { $loggingHelper = Join-Path $PSScriptRoot 'payload\setup_logging.ps1' }
. $loggingHelper
$ownsLog = -not $LogPath
if ($ownsLog) { $LogPath = New-SetupLog -Operation install }
try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Windows x64 is required.' }
    if ($OpenCodeConfig -and -not $ConfigureOpenCode) { throw '-OpenCodeConfig requires -ConfigureOpenCode.' }
    $BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path
    $bundlePrefix = $BundlePath.TrimEnd('\') + '\'
    if (-not (Test-Path -LiteralPath "$BundlePath\checksums.json")) { throw 'Prepared bundle missing. Run Build-OfflineBundle.ps1 on an online PC first.' }
    $manifest = Get-Content -LiteralPath "$BundlePath\bundle.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $manifest.backend -notin @('altium', 'kicad')) { throw 'Unsupported bundle.' }
    Write-SetupLog -Path $LogPath -Event ('backend-' + $manifest.backend)
    if ($EnableAltiumMenu -and $manifest.backend -ne 'altium') { throw 'Altium menu support is only available in the Altium package.' }
    if ($EnableAltiumMenu -and (Get-Process -Name X2,DXP -ErrorAction SilentlyContinue)) { throw 'Close all Altium sessions before preparing guarded menu support.' }
    if (-not $InstallDir) {
        $directoryName = if ($manifest.backend -eq 'kicad') { 'EdaAgentKiCad' } else { 'EdaAgent' }
        $InstallDir = Join-Path $env:LOCALAPPDATA $directoryName
    }
    $InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
    if ($ConfigureExisting) {
        if ($InstallDir -ne $BundlePath.TrimEnd('\')) { throw 'ConfigureExisting requires BundlePath and InstallDir to be the same directory.' }
    } else {
        if ($InstallDir.StartsWith($bundlePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'InstallDir must be outside the source bundle.' }
        if (Test-Path -LiteralPath $InstallDir) { throw "Destination already exists. Choose a new -InstallDir: $InstallDir" }
    }
    Write-Host 'Verifying offline bundle...'
    Write-SetupLog -Path $LogPath -Event bundle-verification
    $checksums = Get-Content -LiteralPath "$BundlePath\checksums.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $checksums = @($checksums)
    if ($checksums.Count -eq 0) { throw 'Empty checksum manifest.' }
    foreach ($item in $checksums) {
        $file = [IO.Path]::GetFullPath((Join-Path $BundlePath $item.path))
        if (-not $file.StartsWith($bundlePrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe manifest path.' }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing bundle file: $($item.path)" }
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $item.sha256) { throw "Checksum mismatch: $($item.path)" }
    }
    # Refuse extra Python files as well as missing or altered files.
    $known = @{}
    foreach ($item in $checksums) { $known[$item.path.Replace('/', '\')] = $true }
    if (-not $ConfigureExisting) {
        foreach ($file in Get-ChildItem -LiteralPath $BundlePath -Recurse -File) {
            $relative = $file.FullName.Substring($bundlePrefix.Length)
            if ($relative -eq 'checksums.json') { continue }
            if (-not $known.ContainsKey($relative)) { throw "Unexpected bundle file: $relative" }
        }
    }
    if ($ConfigureOpenCode) {
        if (-not $OpenCodeConfig) {
            $configDir = Join-Path $env:USERPROFILE '.config\opencode'
            $OpenCodeConfig = Join-Path $configDir 'opencode.jsonc'
            if (-not (Test-Path -LiteralPath $OpenCodeConfig) -and (Test-Path -LiteralPath "$configDir\opencode.json")) {
                $OpenCodeConfig = Join-Path $configDir 'opencode.json'
            }
        }
        $OpenCodeConfig = [IO.Path]::GetFullPath($OpenCodeConfig)
        & "$BundlePath\runtime\python.exe" "$BundlePath\configure_opencode.py" $OpenCodeConfig --check
        if ($LASTEXITCODE -ne 0) { throw 'Invalid OpenCode configuration; installation was not started.' }
        if ($OpenCodeConfig.StartsWith($InstallDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'OpenCodeConfig must be outside the installation directory.'
        }
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    $pointer = if ($env:EDA_AGENT_POINTER_FILE) { $env:EDA_AGENT_POINTER_FILE } else { 'C:\ProgramData\eda-agent\workspace-path.txt' }
    $pointerExisted = $false
    $pointerBytes = $null
    if ($manifest.backend -eq 'altium') {
        $pointerExisted = Test-Path -LiteralPath $pointer -PathType Leaf
        if ($pointerExisted) { $pointerBytes = [IO.File]::ReadAllBytes($pointer) }
    }
    $createdInstall = $false
    $pointerAttempted = $false
    $previousGenerated = @{}
    if ($ConfigureExisting) {
        foreach ($name in @('installation.json', 'opencode.mcp.json', 'setup-state.json', 'workspace\eda-menu-enabled', 'Altium-Menu-Commands.txt')) {
            $file = Join-Path $InstallDir $name
            $previousGenerated[$name] = if (Test-Path -LiteralPath $file) { [IO.File]::ReadAllBytes($file) } else { $null }
        }
    }
    try {
        if (-not $ConfigureExisting) {
            New-Item -ItemType Directory -Path $InstallDir | Out-Null
            $createdInstall = $true
            Copy-Item -LiteralPath "$BundlePath\runtime" -Destination $InstallDir -Recurse
            Write-SetupLog -Path $LogPath -Event copying-files
            foreach ($name in @('launch.py', 'Start-EdaAgent.cmd', 'configure_opencode.py', 'setup_logging.ps1', 'bundle.json', 'packages.lock.txt', 'README.md', 'LICENSE', 'upstream', 'docs')) {
                Copy-Item -LiteralPath (Join-Path $BundlePath $name) -Destination $InstallDir -Recurse
            }
            if ($manifest.backend -eq 'altium') {
                Copy-Item -LiteralPath (Join-Path $BundlePath 'altium_menu.py') -Destination $InstallDir
                Copy-Item -LiteralPath (Join-Path $BundlePath 'Connection-Assistant.ps1') -Destination $InstallDir
            }
        }
        Write-SetupLog -Path $LogPath -Event configuring
        [IO.File]::WriteAllText("$InstallDir\installation.json", (@{ backend = $manifest.backend } | ConvertTo-Json), $utf8)
        $python = Join-Path $InstallDir 'runtime\python.exe'
        $launcher = Join-Path $InstallDir 'launch.py'
        & $python -c 'import eda_agent.server, win32api, pythoncom, comtypes, numpy, scipy'
        if ($LASTEXITCODE -ne 0) { throw 'Runtime check failed.' }
        if ($manifest.backend -eq 'kicad') {
            & $python -c 'import kipy'
            if ($LASTEXITCODE -ne 0) { throw 'KiCad IPC client is missing.' }
        }
        New-Item -ItemType Directory -Path "$InstallDir\workspace" -Force | Out-Null
        if ($manifest.backend -eq 'altium') {
            $pointerAttempted = $true
            & $python $launcher install-scripts --dest "$InstallDir\scripts" --force
            if ($LASTEXITCODE -ne 0) { throw 'Altium script deployment failed.' }
            if (-not (Test-Path -LiteralPath $pointer -PathType Leaf)) { throw "Cannot write Altium workspace pointer: $pointer. Ask IT to grant write access." }
            $actualPointer = [IO.File]::ReadAllText($pointer, [Text.Encoding]::Default).TrimEnd('\')
            if ($actualPointer -ne "$InstallDir\workspace") { throw "Altium workspace pointer was not updated: $pointer" }
        }
        $entry = [ordered]@{ type = 'local'; command = @($python, $launcher); enabled = $true; timeout = 60000 }
        $mcpName = if ($manifest.backend -eq 'kicad') { 'eda-agent-kicad' } else { 'eda-agent' }
        $snippet = @{ mcp = @{ $mcpName = $entry } } | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText("$InstallDir\opencode.mcp.json", $snippet, $utf8)
        # Record only the integration location; never duplicate provider/API key settings.
        $registeredConfig = if ($ConfigureOpenCode) { $OpenCodeConfig } else { $null }
        if (-not $ConfigureOpenCode -and (Test-Path -LiteralPath "$InstallDir\setup-state.json")) {
            $previousState = Get-Content -LiteralPath "$InstallDir\setup-state.json" -Raw -Encoding UTF8 | ConvertFrom-Json
            $registeredConfig = $previousState.configPath
        }
        $newState = if (Test-Path -LiteralPath "$InstallDir\setup-state.json") {
            Get-Content -LiteralPath "$InstallDir\setup-state.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        } else { [pscustomobject]@{} }
        $newState | Add-Member -NotePropertyName schemaVersion -NotePropertyValue 2 -Force
        $newState | Add-Member -NotePropertyName configPath -NotePropertyValue $registeredConfig -Force
        if ($EnableAltiumMenu) {
            # Profiles are deliberately untouched. Customize registration remains manual.
            $installationId = if ($newState.PSObject.Properties['altiumMenu']) { $newState.altiumMenu.installationId } else { [Guid]::NewGuid().ToString('N') }
            $menuState = [ordered]@{ schemaVersion = 1; installationId = $installationId; mode = 'manual'; status = 'pending-user-registration'; profileModified = $false }
            $newState | Add-Member -NotePropertyName altiumMenu -NotePropertyValue $menuState -Force
            [IO.File]::WriteAllText("$InstallDir\workspace\eda-menu-enabled", '1', $utf8)
            $commands = @(
                'EDA Agent - Altium menu / menu kurulumu',
                'View > Toolbars > Customize > New',
                'Add each desired command separately with Process: ScriptingSystem:RunScript. No profile or menu is changed automatically.',
                'Istenen her komutu ayri ekleyin: Process: ScriptingSystem:RunScript. Profil/menu otomatik degistirilmez.'
            )
            foreach ($entry in @(
                @{ Procedure = 'ShowConnectionAssistant'; Caption = 'EDA Agent - Connection Assistant / Baglanti Yardimcisi'; Detail = 'Open only; does not start the bridge / Yalniz acar; kopruyu baslatmaz.' },
                @{ Procedure = 'StartConnectionAssistant'; Caption = 'EDA Agent - Start / Baslat'; Detail = 'Start and show the result / Baslatir ve sonucu gosterir.' },
                @{ Procedure = 'StatusConnectionAssistant'; Caption = 'EDA Agent - Status / Durum'; Detail = 'Check only; never starts a stopped bridge / Yalniz kontrol eder; duran kopruyu baslatmaz.' },
                @{ Procedure = 'DisconnectConnectionAssistant'; Caption = 'EDA Agent - Disconnect / Baglantiyi kes'; Detail = 'Disconnect without saving; projects remain open / Kaydetmeden keser; projeler acik kalir.' },
                @{ Procedure = 'ReconnectConnectionAssistant'; Caption = 'EDA Agent - Reconnect / Yeniden baglan'; Detail = 'Start only after confirmed safe stop / Yalniz guvenli durdurma dogrulandiktan sonra baslatir.' }
            )) {
                $commands += @(
                    '',
                    ('Caption: ' + $entry.Caption),
                    'Process: ScriptingSystem:RunScript',
                    ('Parameters: ProjectName=' + $InstallDir + '\scripts\Altium_API.PrjScr|ProcName=ConnectionAssistant.pas>' + $entry.Procedure),
                    $entry.Detail
                )
            }
            $commands += @(
                '',
                'Drag each command to a menu or toolbar. Repeat for each editor you use.',
                'Her komutu menuye/arac cubuguna surukleyin; kullandiginiz her editor icin tekrarlayin.',
                'All results and errors appear in the same external Connection Assistant.',
                'Tum sonuclar ve hatalar ayni harici Baglanti Yardimcisinda gosterilir.',
                'Remove only these custom commands in Customize before uninstall. Never use Restore.',
                'Kaldirmadan once Customize icinde yalniz bu ozel komutlari silin. Restore kullanmayin.',
                'Guarded mode: pcb.get_components, pcb.get_nets, pcb.batch_move_components only. Other design commands are refused.',
                'Canli Altium dogrulamasi bekliyor / Live Altium validation pending.'
            )
            [IO.File]::WriteAllLines("$InstallDir\Altium-Menu-Commands.txt", [string[]]$commands, $utf8)
        }
        [IO.File]::WriteAllText("$InstallDir\setup-state.json", ($newState | ConvertTo-Json -Depth 8), $utf8)
        if ($ConfigureOpenCode) {
            & $python "$InstallDir\configure_opencode.py" $OpenCodeConfig "$InstallDir\opencode.mcp.json"
            if ($LASTEXITCODE -ne 0) { throw 'OpenCode configuration failed; existing configuration was preserved.' }
        }
    } catch {
        $failure = $_
        $canRemove = $true
        try {
            if ($ConfigureExisting) {
                foreach ($name in $previousGenerated.Keys) {
                    $file = Join-Path $InstallDir $name
                    if ($null -eq $previousGenerated[$name]) {
                        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
                    } else {
                        $before = [Convert]::ToBase64String([byte[]]$previousGenerated[$name])
                        $after = if (Test-Path -LiteralPath $file) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) } else { '' }
                        if ($before -ne $after) { [IO.File]::WriteAllBytes($file, [byte[]]$previousGenerated[$name]) }
                    }
                }
            }
            if ($pointerAttempted -and (Test-Path -LiteralPath $pointer -PathType Leaf)) {
                $currentPointer = [IO.File]::ReadAllText($pointer, [Text.Encoding]::Default).TrimEnd('\')
                if ($currentPointer -eq "$InstallDir\workspace") {
                    if ($pointerExisted) { [IO.File]::WriteAllBytes($pointer, $pointerBytes) }
                    else { Remove-Item -LiteralPath $pointer }
                }
            }
        } catch {
            $canRemove = $false
            Write-Warning "Could not restore the Altium workspace pointer. Installation retained at $InstallDir. $($_.Exception.Message)"
        }
        if ($createdInstall -and $canRemove -and (Test-Path -LiteralPath $InstallDir)) {
            # Remove only the new directory created by this invocation, never an existing install.
            $cleanupPath = (Resolve-Path -LiteralPath $InstallDir).Path.TrimEnd('\')
            if ($cleanupPath -ne $InstallDir -or (((Get-Item -LiteralPath $cleanupPath).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                Write-Warning "Cleanup path could not be verified: $InstallDir"
            } else {
                Remove-Item -LiteralPath $cleanupPath -Recurse -Force
            }
        }
        throw $failure
    }
    Write-Host "Installed offline: $InstallDir"
    Write-Host "OpenCode MCP settings: $InstallDir\opencode.mcp.json"
    if ($manifest.backend -eq 'altium') {
        Write-Host "In Altium: Preferences > Scripting System > Global Projects > Install from file > $InstallDir\scripts\Altium_API.PrjScr"
        Write-Host 'Then: File > Run Script > ConnectionAssistant.pas > ShowConnectionAssistant > Run'
    } else {
        Write-Host 'In KiCad 9+: Preferences > Plugins > enable KiCad API server.'
    }
    Write-SetupLog -Path $LogPath -Event configuration-complete
    if ($ownsLog) { Write-SetupLog -Path $LogPath -Event completed }
} catch {
    Write-SetupLog -Path $LogPath -Event failed -Code $_.Exception.HResult
    throw
} finally {
    if ($LogPath) { Write-Host "Setup log: $LogPath" }
}
