param([ValidateSet('turkish', 'english')][string]$Language = 'turkish')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$tr = $Language -eq 'turkish'
function Text-For([string]$Turkish, [string]$English) { if ($tr) { $Turkish } else { $English } }
$root = $PSScriptRoot
$form = New-Object Windows.Forms.Form
$form.Text = Text-For 'EDA Agent - Bağlantı Yardımcısı' 'EDA Agent - Connection Assistant'
$form.Size = New-Object Drawing.Size(760, 580)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.AutoScaleMode = 'Dpi'
$instructions = New-Object Windows.Forms.Label
$instructions.SetBounds(20, 18, 700, 100)
$instructions.Text = Text-For "1. Altium Designer'ı açın ve projenizi yükleyin.`r`n2. Altium'a bağlan düğmesine basın.`r`n3. OpenCode'u yeniden başlatın ve EDA araçlarını kullanın." "1. Open Altium Designer and load your project.`r`n2. Click Connect to Altium.`r`n3. Restart OpenCode and use the EDA tools."
$form.Controls.Add($instructions)
$connect = New-Object Windows.Forms.Button
$connect.Text = Text-For "Altium'a bağlan" 'Connect to Altium'
$connect.SetBounds(20, 122, 210, 38)
$diagnose = New-Object Windows.Forms.Button
$diagnose.Text = Text-For 'Bağlantıyı denetle' 'Check connection'
$diagnose.SetBounds(245, 122, 210, 38)
$folder = New-Object Windows.Forms.Button
$folder.Text = Text-For 'Script klasörünü aç' 'Open script folder'
$folder.SetBounds(470, 122, 230, 38)
$form.Controls.AddRange(@($connect, $diagnose, $folder))
$manual = New-Object Windows.Forms.Label
$manual.SetBounds(20, 178, 700, 80)
$manual.Text = Text-For "Bağlantı başlamazsa Altium'da DXP > Preferences > Scripting System > Global Projects > Install from file ile aşağıdaki dosyayı ekleyin. Ardından File > Run Script > Dispatcher.pas > StartMCPServer > Run seçin." 'If the connection does not start, add the file below in Altium: DXP > Preferences > Scripting System > Global Projects > Install from file. Then select File > Run Script > Dispatcher.pas > StartMCPServer > Run.'
$form.Controls.Add($manual)
$projectPath = New-Object Windows.Forms.TextBox
$projectPath.SetBounds(20, 264, 570, 30)
$projectPath.ReadOnly = $true
$projectPath.Text = Join-Path $root 'scripts\Altium_API.PrjScr'
$copy = New-Object Windows.Forms.Button
$copy.SetBounds(600, 262, 100, 32)
$copy.Text = Text-For 'Kopyala' 'Copy'
$copy.Add_Click({ [Windows.Forms.Clipboard]::SetText($projectPath.Text) })
$form.Controls.AddRange(@($projectPath, $copy))
$output = New-Object Windows.Forms.TextBox
$output.SetBounds(20, 310, 680, 185)
$output.Multiline = $true
$output.ReadOnly = $true
$output.ScrollBars = 'Vertical'
$output.Text = Text-For 'Altium hazır olduğunda bağlantıyı başlatabilirsiniz.' 'You can connect when Altium is ready.'
$form.Controls.Add($output)
function Invoke-Agent([string]$Command) {
    $connect.Enabled = $false
    $diagnose.Enabled = $false
    $form.UseWaitCursor = $true
    $output.Text = Text-For 'İşlem sürüyor...' 'Working...'
    $form.Refresh()
    try {
        $savedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $result = & "$root\runtime\python.exe" "$root\launch.py" $Command 2>&1 | ForEach-Object { $_.ToString() } | Out-String
            $agentExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $savedPreference }
        if ($agentExit -eq 0) {
            $output.Text = (Text-For 'İşlem tamamlandı.' 'Completed.') + "`r`n`r`n" + $result
        } else {
            $output.Text = (Text-For "Bağlantı kurulamadı. Altium'un açık olduğunu kontrol edin ve yukarıdaki elle kurulum adımlarını uygulayın." 'Connection failed. Make sure Altium is running and follow the manual steps above.') + "`r`n`r`n" + $result
        }
    } catch { $output.Text = $_.Exception.Message }
    finally { $form.UseWaitCursor = $false; $connect.Enabled = $true; $diagnose.Enabled = $true }
}
$connect.Add_Click({ Invoke-Agent 'relaunch' })
$diagnose.Add_Click({ Invoke-Agent 'doctor' })
$folder.Add_Click({ Start-Process -FilePath explorer.exe -ArgumentList ('"' + (Join-Path $root 'scripts') + '"') })
$footer = New-Object Windows.Forms.Label
$footer.SetBounds(20, 510, 690, 24)
$footer.Text = '© 2026 Yasir Erkam ÖZDEMİR'
$form.Controls.Add($footer)
[void]$form.ShowDialog()
$form.Dispose()
