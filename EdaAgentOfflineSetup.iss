#ifndef PayloadDir
  #error Build using Build-Installer.ps1
#endif
#ifndef SetupVersion
  #define SetupVersion "0.1.0"
#endif

[Setup]
AppId={{5CC17F09-79DA-4E93-8587-D5A16DD19AD6}
AppName=EDA Agent
AppVerName=EDA Agent Offline Setup {#SetupVersion}
AppVersion={#SetupVersion}
VersionInfoVersion={#SetupVersion}
AppCopyright=© 2026 Yasir Erkam ÖZDEMİR
AppPublisher=Yasir Erkam ÖZDEMİR
DefaultDirName={localappdata}\Programs\EdaAgent
DefaultGroupName=EDA Agent
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
MinVersion=10.0
OutputDir=dist
OutputBaseFilename=EdaAgentOfflineSetup-{#SetupVersion}-{#Backend}
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
SetupLogging=yes
LicenseFile={#PayloadDir}\upstream\LICENSE
UninstallDisplayIcon={app}\runtime\python.exe

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
turkish.WelcomeLabel2=Bu sihirbaz EDA Agent ve gerekli Python bileşenlerini internet bağlantısı gerektirmeden kuracaktır.%n%nBu kuruluma başlamadan önce OpenCode'u kurmanız gerekir. OpenCode bu pakete dahil değildir.%n%nKurulum paketi sürümü: {#SetupVersion}%n%nDevam etmeden önce OpenCode ve Altium Designer'ı kapatın.
english.WelcomeLabel2=This wizard will install EDA Agent and its Python runtime without an internet connection.%n%nYou must install OpenCode before starting this setup. OpenCode is not included in this package.%n%nSetup package version: {#SetupVersion}%n%nClose OpenCode and Altium Designer before continuing.
turkish.ReadyLabel2a=Kuruluma başlamak için Kur üzerine, ayarları gözden geçirmek için Önceki üzerine tıklayın.
turkish.ReadyLabel2b=Kuruluma başlamak için Kur üzerine tıklayın.

[CustomMessages]
turkish.IntegrationGroup=OpenCode bağlantısı:
english.IntegrationGroup=OpenCode integration:
turkish.RegisterOpenCode=EDA Agent'ı OpenCode'a otomatik ekle (önerilir)
english.RegisterOpenCode=Automatically add EDA Agent to OpenCode (recommended)
turkish.Assistant=Altium bağlantı yardımcısını aç
english.Assistant=Open the Altium connection assistant
turkish.AssistantShortcut=Altium Bağlantı Yardımcısı
english.AssistantShortcut=Altium Connection Assistant
turkish.Configuring=EDA Agent ve OpenCode bağlantısı yapılandırılıyor...
english.Configuring=Configuring EDA Agent and OpenCode integration...
turkish.ConfigurationFailed=Yapılandırma tamamlanamadı. Ayrıntılar: %1
english.ConfigurationFailed=Configuration could not be completed. Details: %1
turkish.ConfigurationFailedHeading=Yapılandırma tamamlanamadı
english.ConfigurationFailedHeading=Configuration was not completed
turkish.InvalidConfig=OpenCode ayar dosyası okunamadı veya geçerli JSON/JSONC değil: %1. Dosyayı düzeltin veya otomatik OpenCode bağlantısı seçeneğini kapatın.
english.InvalidConfig=The OpenCode configuration could not be read or is not valid JSON/JSONC: %1. Fix the file or disable automatic OpenCode integration.
turkish.UnregisterFailed=OpenCode bağlantısı kaldırılamadı. Ayar dosyasını kontrol edip yeniden deneyin.
english.UnregisterFailed=Could not remove the OpenCode integration. Check your configuration file and try again.
#if Backend == "altium"
turkish.FinishedLabel=EDA Agent kuruldu. Altium Designer'ı açtıktan sonra bağlantı yardımcısını kullanın. OpenCode'u yeniden başlatmanız gerekir.
english.FinishedLabel=EDA Agent is installed. Open Altium Designer, then use the connection assistant. Restart OpenCode to load the integration.
#else
turkish.FinishedLabel=EDA Agent kuruldu. KiCad 9 veya üzeri sürümde Preferences > Plugins > KiCad API server seçeneğini etkinleştirin. OpenCode'u yeniden başlatın.
english.FinishedLabel=EDA Agent is installed. In KiCad 9 or later, enable Preferences > Plugins > KiCad API server. Restart OpenCode.
#endif

[Tasks]
Name: "opencode"; Description: "{cm:RegisterOpenCode}"; GroupDescription: "{cm:IntegrationGroup}"

[Files]
Source: "{#PayloadDir}\runtime\python.exe"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\python313.*"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\python3.dll"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\vcruntime140*.dll"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\configure_opencode.py"; DestDir: "{tmp}\preflight"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installer\Connection-Assistant.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Unregister-Integration.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Invoke-Setup.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
#if Backend == "altium"
Name: "{group}\{cm:AssistantShortcut}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Connection-Assistant.ps1"" -Language {language}"; IconFilename: "{app}\runtime\python.exe"
#endif
Name: "{group}\EDA Agent - README"; Filename: "{app}\README.md"
Name: "{group}\{cm:UninstallProgram,EDA Agent}"; Filename: "{uninstallexe}"

[Run]
#if Backend == "altium"
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Connection-Assistant.ps1"" -Language {language}"; Description: "{cm:Assistant}"; Flags: postinstall nowait skipifsilent runhidden; Check: ConfigurationSucceeded
#endif

[UninstallDelete]
Type: filesandordirs; Name: "{app}\runtime"
Type: files; Name: "{app}\installation.json"
Type: files; Name: "{app}\setup-state.json"
Type: files; Name: "{app}\opencode.mcp.json"
Type: files; Name: "{app}\setup-configuration.log"
#include GeneratedFiles
Type: dirifempty; Name: "{app}\scripts"

[Code]
var
  CopyrightLabel: TNewStaticText;
  ConfigurationFailed: Boolean;

function ConfigurationSucceeded: Boolean;
begin
  Result := not ConfigurationFailed;
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := 0;
  if ConfigurationFailed then Result := 10;
end;

function PowerShellPath: String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

procedure InitializeWizard;
begin
  CopyrightLabel := TNewStaticText.Create(WizardForm);
  CopyrightLabel.Parent := WizardForm;
  CopyrightLabel.Caption := '© 2026 Yasir Erkam ÖZDEMİR';
  CopyrightLabel.SetBounds(ScaleX(12), WizardForm.CancelButton.Top + ScaleY(5), ScaleX(285), ScaleY(20));
  CopyrightLabel.Font.Size := 8;
  CopyrightLabel.Anchors := [akLeft, akBottom];
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then begin
    if ConfigurationFailed then begin
      WizardForm.FinishedHeadingLabel.Caption := CustomMessage('ConfigurationFailedHeading');
      WizardForm.FinishedLabel.Caption := FmtMessage(CustomMessage('ConfigurationFailed'), [ExpandConstant('{app}\setup-configuration.log')]);
    end else
      WizardForm.FinishedLabel.Caption := CustomMessage('FinishedLabel');
  end;
end;

function OpenCodeConfigPath: String;
begin
  Result := ExpandConstant('{param:OPENCODECONFIG|}');
  if Result = '' then begin
    Result := ExpandConstant('{userprofile}\.config\opencode\opencode.jsonc');
    if (not FileExists(Result)) and FileExists(ExpandConstant('{userprofile}\.config\opencode\opencode.json')) then
      Result := ExpandConstant('{userprofile}\.config\opencode\opencode.json');
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ConfigPath, Parameters: String;
  ResultCode: Integer;
begin
  Result := '';
  if WizardIsTaskSelected('opencode') then begin
    ConfigPath := OpenCodeConfigPath;
    ExtractTemporaryFiles('{tmp}\preflight\*');
    Parameters := '"' + ExpandConstant('{tmp}') + '\preflight\configure_opencode.py" "' + ConfigPath + '" --check';
    if not Exec(ExpandConstant('{tmp}\preflight\runtime\python.exe'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Result := FmtMessage(CustomMessage('InvalidConfig'), [ConfigPath])
    else if ResultCode <> 0 then
      Result := FmtMessage(CustomMessage('InvalidConfig'), [ConfigPath]);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Parameters, ConfigPath, LogFile: String;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    WizardForm.StatusLabel.Caption := CustomMessage('Configuring');
    LogFile := ExpandConstant('{app}\setup-configuration.log');
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Invoke-Setup.ps1') + '"';
    if WizardIsTaskSelected('opencode') then begin
      Parameters := Parameters + ' -ConfigureOpenCode';
      ConfigPath := OpenCodeConfigPath;
      if ConfigPath <> '' then
        Parameters := Parameters + ' -OpenCodeConfig "' + ConfigPath + '"';
    end;
    if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      ConfigurationFailed := True
    else if ResultCode <> 0 then
      ConfigurationFailed := True;
    if ConfigurationFailed then begin
      Log(FmtMessage(CustomMessage('ConfigurationFailed'), [LogFile]));
      if not WizardSilent then MsgBox(FmtMessage(CustomMessage('ConfigurationFailed'), [LogFile]), mbError, MB_OK);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Parameters: String;
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then begin
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Unregister-Integration.ps1') +
      '" -InstallDir "' + ExpandConstant('{app}') + '"';
    if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      RaiseException(CustomMessage('UnregisterFailed'));
    if ResultCode <> 0 then
      RaiseException(CustomMessage('UnregisterFailed'));
  end;
end;
