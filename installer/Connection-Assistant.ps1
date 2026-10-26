param(
    [ValidateSet('turkish', 'english')][string]$Language = 'turkish',
    [string]$CallerId = '',
    [string]$SessionId = '',
    [ValidateSet('Show', 'Start', 'Status', 'Disconnect', 'Reconnect')][string]$Action = 'Show'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$tr = $Language -eq 'turkish'
function Text-For([string]$Turkish, [string]$English) { if ($tr) { $Turkish } else { $English } }
$root = $PSScriptRoot
. (Join-Path $root 'setup_logging.ps1')
$script:pending = $null
$script:callerId = $CallerId
$script:sessionId = $SessionId
$script:processIdentity = ''
$script:queuedAction = if ($Action -eq 'Show') { '' } else { $Action.ToLowerInvariant() }
$form = New-Object Windows.Forms.Form
$form.Text = Text-For 'EDA Agent - Bağlantı Yardımcısı' 'EDA Agent - Connection Assistant'
$form.ClientSize = New-Object Drawing.Size(900, 690)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.AutoScaleMode = 'Dpi'
$instructions = New-Object Windows.Forms.Label
$instructions.SetBounds(18, 16, 860, 82)
$instructions.Text = Text-For "Altium'u açın, bağlantıyı başlatın ve hedef projeyi seçin. OpenCode'u yeniden başlatın.`r`nMenü desteği seçildiyse komut Altium'a bir kez elle eklenir. Korumalı modda yalnız belgelenmiş PCB komutları kullanılabilir; canlı Altium doğrulaması bekliyor." "Open Altium, start the connection and select a target project. Restart OpenCode.`r`nRegister the menu command once in Altium. Guarded mode supports only the documented PCB commands; live Altium validation is pending."
$form.Controls.Add($instructions)
$start = New-Object Windows.Forms.Button
$start.Text = Text-For 'Bağlantıyı başlat' 'Start connection'
$status = New-Object Windows.Forms.Button
$status.Text = Text-For 'Bağlantı durumu' 'Connection status'
$disconnect = New-Object Windows.Forms.Button
$disconnect.Text = Text-For 'Bağlantıyı kes' 'Disconnect'
$help = New-Object Windows.Forms.Button
$help.Text = Text-For 'Yardım ve sorun giderme…' 'Help and troubleshooting…'
$buttons = @($start, $status, $disconnect, $help)
for ($i = 0; $i -lt $buttons.Count; $i++) {
    $buttons[$i].SetBounds((18 + 218 * $i), 104, 208, 42)
    $form.Controls.Add($buttons[$i])
}
$projects = New-Object Windows.Forms.ComboBox
$projects.SetBounds(18, 164, 640, 32)
$projects.DropDownStyle = 'DropDownList'
$target = New-Object Windows.Forms.Button
$target.SetBounds(672, 160, 208, 40)
$target.Text = Text-For 'Hedef proje…' 'Target project…'
$form.Controls.AddRange(@($projects, $target))
$output = New-Object Windows.Forms.TextBox
$output.SetBounds(18, 218, 862, 350)
$output.Multiline = $true
$output.ReadOnly = $true
$output.ScrollBars = 'Both'
$form.Controls.Add($output)
$reconnect = New-Object Windows.Forms.Button
$reconnect.SetBounds(18, 586, 208, 36)
$reconnect.Text = Text-For 'Yeniden bağlan' 'Reconnect'
$reconnect.Visible = $false
$form.Controls.Add($reconnect)
$footer = New-Object Windows.Forms.Label
$footer.SetBounds(250, 592, 630, 28)
$footer.Text = '© 2026 Yasir Erkam ÖZDEMİR'
$form.Controls.Add($footer)
$openLogs = New-Object Windows.Forms.Button
$openLogs.SetBounds(18, 636, 260, 36)
$openLogs.Text = Text-For 'Log klasörünü aç' 'Open log folder'
$exportLogs = New-Object Windows.Forms.Button
$exportLogs.SetBounds(296, 636, 290, 36)
$exportLogs.Text = Text-For 'Logları masaüstüne kopyala' 'Copy logs to desktop'
$form.Controls.AddRange(@($openLogs, $exportLogs))
$openLogs.Add_Click({
    try {
        $directory = Join-Path $env:LOCALAPPDATA 'EdaAgentOfflineSetup\Logs'
        [void][IO.Directory]::CreateDirectory($directory)
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $directory + '"')
    } catch { $output.Text = $_.Exception.Message }
})
$exportLogs.Add_Click({
    try {
        $destination = Export-SetupLogs -DestinationDirectory ([Environment]::GetFolderPath('DesktopDirectory'))
        $output.Text = if ($destination) { (Text-For 'Loglar kopyalandı: ' 'Logs copied: ') + $destination } else { Text-For 'Kopyalanacak kurulum veya kaldırma logu yok.' 'No installation or uninstall logs to copy.' }
    } catch { $output.Text = $_.Exception.Message }
})

function Set-Controls([bool]$Enabled) {
    foreach ($button in @($start, $status, $disconnect, $help, $target, $reconnect)) { $button.Enabled = $Enabled }
    $projects.Enabled = $Enabled
    if ($Enabled -and -not (Test-Path -LiteralPath "$root\workspace\eda-menu-enabled")) {
        $target.Enabled = $false
        $disconnect.Enabled = $false
        $reconnect.Enabled = $false
    }
}

function Invoke-Menu([string]$Command, [string]$Project = '') {
    if ($null -ne $script:pending) { return }
    if ($Command -ne 'prepare' -and -not $script:processIdentity) {
        $script:queuedAction = $Command
        $Command = 'prepare'
    }
    Set-Controls $false
    $output.Text = Text-For 'İşlem sürüyor…' 'Working…'
    try {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = Join-Path $root 'runtime\python.exe'
        $info.Arguments = '-X utf8 "' + (Join-Path $root 'altium_menu.py') + '" ' + $Command
        if ($Project) { $info.Arguments += ' --project "' + $Project + '"' }
        if ($script:callerId) { $info.Arguments += ' --caller-id "' + $script:callerId + '"' }
        if ($script:sessionId) { $info.Arguments += ' --session-id "' + $script:sessionId + '"' }
        if ($script:processIdentity) { $info.Arguments += ' --process-identity "' + $script:processIdentity + '"' }
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.StandardOutputEncoding = [Text.Encoding]::UTF8
        $info.StandardErrorEncoding = [Text.Encoding]::UTF8
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $info
        [void]$process.Start()
        $script:pending = @{ Process = $process; Output = $process.StandardOutput.ReadToEndAsync(); Error = $process.StandardError.ReadToEndAsync(); Command = $Command }
    } catch {
        $script:queuedAction = ''
        $output.Text = $_.Exception.Message
        Set-Controls $true
    }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
    if ($null -eq $script:pending -or -not $script:pending.Process.HasExited) { return }
    $operation = $script:pending
    $script:pending = $null
    $nextAction = ''
    try {
        $raw = $operation.Output.Result
        $stderr = $operation.Error.Result
        $data = $raw | ConvertFrom-Json
        if ($operation.Process.ExitCode -ne 0) {
            $output.Text = (Text-For 'İşlem doğrulanamadı: ' 'Operation was not confirmed: ') + $data.error + "`r`n" + $stderr
            $script:queuedAction = ''
        } elseif ($operation.Command -eq 'prepare') {
            if (-not $data.process_identity) { throw 'Altium process identity was not confirmed.' }
            $script:callerId = [string]$data.caller_id
            $script:sessionId = [string]$data.session_id
            $script:processIdentity = [string]$data.process_identity
            $output.Text = Text-For 'Altium oturumu bağlandı. Başlat veya bağlantı durumu seçin.' 'Altium session bound. Choose Start or Connection status.'
            $nextAction = $script:queuedAction
            $script:queuedAction = ''
        } elseif ($operation.Command -eq 'disconnect') {
            $projects.Items.Clear()
            $output.Text = Text-For 'Bağlantı kesildi. Belgeler kaydedilmedi; projeler açık bırakıldı.' 'Disconnected. Documents were not saved; projects were left open.'
        } else {
            $projects.Items.Clear()
            if ($data.PSObject.Properties['caller_id']) { $script:callerId = [string]$data.caller_id }
            if ($data.PSObject.Properties['session_id']) { $script:sessionId = [string]$data.session_id }
            if ($data.PSObject.Properties['projects']) { foreach ($path in $data.projects) { [void]$projects.Items.Add([string]$path) } }
            $selected = if ($data.PSObject.Properties['target_project']) { [string]$data.target_project } else { '' }
            $projects.SelectedIndex = $projects.Items.IndexOf($selected)
            $active = if ($data.PSObject.Properties['active_document']) { [string]$data.active_document } else { '' }
            $session = if ($data.PSObject.Properties['session_id']) { [string]$data.session_id } else { Text-For 'Doğrulanmadı' 'Not verified' }
            $output.Text = (Text-For 'Köprü yanıt veriyor.' 'Bridge is responding.') + "`r`n" +
                (Text-For 'Oturum: ' 'Session: ') + $session + "`r`n" +
                (Text-For 'Hedef proje: ' 'Target project: ') + $selected + "`r`n" +
                (Text-For 'Aktif belge: ' 'Active document: ') + $active + "`r`n" +
                (Text-For 'Kontrol zamanı: ' 'Checked at: ') + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "`r`n" +
                (Text-For 'OpenCode bağlantısı bu kontrolle doğrulanmaz. Proje listesini yenilemek için Bağlantı durumu seçin.' 'This check does not verify the OpenCode connection. Refresh Connection status to reload projects.')
        }
    } catch {
        $script:queuedAction = ''
        $output.Text = $_.Exception.Message + "`r`n" + $operation.Output.Result
    }
    finally { $operation.Process.Dispose(); Set-Controls $true }
    if ($nextAction) { Invoke-Menu $nextAction }
})
$timer.Start()
$start.Add_Click({ Invoke-Menu 'start' })
$status.Add_Click({ Invoke-Menu 'status' })
$disconnect.Add_Click({ Invoke-Menu 'disconnect' })
$target.Add_Click({ if ($projects.SelectedIndex -ge 0) { Invoke-Menu 'select' ([string]$projects.SelectedItem) } })
$reconnect.Add_Click({ Invoke-Menu 'reconnect' })
$help.Add_Click({
    $reconnect.Visible = $true
    $output.Text = Text-For "Menü kurulumu: kurucuyu yeniden çalıştırıp Altium menü desteğini seçin. Altium'da View > Toolbars > Customize > New ile komutu elle ekleyin.`r`nKaldırma: Customize içinde yalnız EDA Agent komutunu silin; Restore kullanmayın.`r`nYeniden bağlan, güvenli kesme doğrulanmadan yeniden başlatmaz. Altium zorla sonlandırılmaz.`r`nKilit kaldıysa tüm Altium oturumlarını kapatın; workspace\eda-menu-session.lock boş klasörünü kaldırıp yeniden deneyin.`r`nKorumalı mod: pcb.get_components, pcb.get_nets, pcb.batch_move_components. Diğer tasarım komutları engellenir." "Menu setup: select Altium menu support in setup, then register the command in View > Toolbars > Customize > New.`r`nRemoval: delete only the EDA Agent command in Customize; do not use Restore.`r`nReconnect requires confirmed safe disconnection. It never kills Altium.`r`nFor a stale lease, close all Altium sessions, remove the empty workspace\eda-menu-session.lock directory, then retry.`r`nGuarded mode: pcb.get_components, pcb.get_nets, pcb.batch_move_components. Other design commands are refused."
    $commandFile = Join-Path $root 'Altium-Menu-Commands.txt'
    if (Test-Path -LiteralPath $commandFile) { $output.AppendText("`r`n`r`n" + [IO.File]::ReadAllText($commandFile, [Text.Encoding]::UTF8)) }
})
$form.Add_FormClosing({ param($sender, $eventArgs) if ($null -ne $script:pending) { $eventArgs.Cancel = $true } })
Set-Controls $true
$output.Text = Text-For 'Başlat veya bağlantı durumu işlemini seçin. Menü kaydı elle tamamlanır.' 'Choose Start or Connection status. Menu registration is completed manually.'
$form.Add_Shown({ Invoke-Menu 'prepare' })
[void]$form.ShowDialog()
$timer.Dispose()
$form.Dispose()
