#ifndef PayloadDir
  #error Build using Build-Installer.ps1
#endif
#ifndef SetupVersion
  #define SetupVersion "0.1.6"
#endif
#if Backend == "altium"
  #define ProductName "EDA Agent for Altium"
  #define ProductFolder "EdaAgent"
  #define ProductId "{{5CC17F09-79DA-4E93-8587-D5A16DD19AD6}"
  #define EdaName "Altium Designer"
#else
  #define ProductName "EDA Agent for KiCad"
  #define ProductFolder "EdaAgentKiCad"
  #define ProductId "{{D3D0D6D1-7F8A-4C2E-9A41-884C86E1506B}"
  #define EdaName "KiCad"
#endif

[Setup]
AppId={#ProductId}
AppName={#ProductName}
AppVerName={#ProductName} Offline Setup {#SetupVersion}
AppVersion={#SetupVersion}
VersionInfoVersion={#SetupVersion}
AppCopyright=© 2026 Yasir Erkam ÖZDEMİR
AppPublisher=Yasir Erkam ÖZDEMİR
DefaultDirName={localappdata}\Programs\{#ProductFolder}
DefaultGroupName={#ProductName}
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
turkish.WelcomeLabel2=Bu paket {#EdaName} için EDA Agent ve gerekli Python bileşenlerini internet bağlantısı gerektirmeden kuracaktır.%n%nBu kuruluma başlamadan önce OpenCode'u kurmanız gerekir. OpenCode bu pakete dahil değildir.%n%nKurulum paketi sürümü: {#SetupVersion}%n%nDevam etmeden önce OpenCode ve {#EdaName} uygulamalarını kapatın.
english.WelcomeLabel2=This package will install EDA Agent for {#EdaName} and its Python runtime without an internet connection.%n%nYou must install OpenCode before starting this setup. OpenCode is not included in this package.%n%nSetup package version: {#SetupVersion}%n%nClose OpenCode and {#EdaName} before continuing.
turkish.ReadyLabel2a=Kuruluma başlamak için Kur üzerine, ayarları gözden geçirmek için Önceki üzerine tıklayın.
turkish.ReadyLabel2b=Kuruluma başlamak için Kur üzerine tıklayın.

[CustomMessages]
turkish.AltiumMenu=Altium menü komutunu hazırla (elle eklenir; korumalı mod, sınırlı araç desteği)
english.AltiumMenu=Prepare the Altium menu command (manual registration; guarded mode, limited tool support)
turkish.IntegrationGroup=OpenCode bağlantısı:
english.IntegrationGroup=OpenCode integration:
turkish.RegisterOpenCode={#EdaName} bağlantısını OpenCode'a otomatik ekle (önerilir)
english.RegisterOpenCode=Automatically add the {#EdaName} integration to OpenCode (recommended)
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
turkish.WrongDirectory=Seçilen dizinde başka bir EDA Agent paketi veya okunamayan kurulum bilgisi var. {#EdaName} paketi için farklı bir kurulum dizini seçin.
english.WrongDirectory=The selected folder contains a different EDA Agent package or unreadable setup information. Choose a different installation folder for {#EdaName}.
turkish.UnregisterFailed=OpenCode bağlantısı kaldırılamadı. Ayar dosyasını kontrol edip yeniden deneyin.
english.UnregisterFailed=Could not remove the OpenCode integration. Check your configuration file and try again.
turkish.DiagnosticDetails=Tanı günlüğü: %1
english.DiagnosticDetails=Diagnostic log: %1
turkish.CloseAltium=Menü desteğini hazırlamadan önce tüm Altium oturumlarını kapatın ve yeniden deneyin.
english.CloseAltium=Close all Altium sessions before preparing menu support, then try again.
#if Backend == "altium"
turkish.FinishedLabel=EDA Agent kuruldu. Altium Designer'ı açtıktan sonra bağlantı yardımcısını kullanın. OpenCode'u yeniden başlatmanız gerekir.
english.FinishedLabel=EDA Agent is installed. Open Altium Designer, then use the connection assistant. Restart OpenCode to load the integration.
#else
turkish.FinishedLabel=EDA Agent kuruldu. KiCad 9 veya üzeri sürümde Preferences > Plugins > KiCad API server seçeneğini etkinleştirin. OpenCode'u yeniden başlatın.
english.FinishedLabel=EDA Agent is installed. In KiCad 9 or later, enable Preferences > Plugins > KiCad API server. Restart OpenCode.
#endif

[Tasks]
Name: "opencode"; Description: "{cm:RegisterOpenCode}"; GroupDescription: "{cm:IntegrationGroup}"
#if Backend == "altium"
Name: "altiummenu"; Description: "{cm:AltiumMenu}"; Flags: unchecked
#endif

[Files]
Source: "{#PayloadDir}\runtime\python.exe"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\python313.*"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\python3.dll"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\runtime\vcruntime140*.dll"; DestDir: "{tmp}\preflight\runtime"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\configure_opencode.py"; DestDir: "{tmp}\preflight"; Flags: dontcopy noencryption
Source: "installer\check_install_target.py"; DestDir: "{tmp}\preflight"; Flags: dontcopy noencryption
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#if Backend == "altium"
Source: "installer\Connection-Assistant.ps1"; DestDir: "{app}"; Flags: ignoreversion
#endif
Source: "installer\Unregister-Integration.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Invoke-Setup.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
#if Backend == "altium"
Name: "{group}\{cm:AssistantShortcut}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Connection-Assistant.ps1"" -Language {language}"; IconFilename: "{app}\runtime\python.exe"
#endif
Name: "{group}\{#ProductName} - README"; Filename: "{app}\README.md"
Name: "{group}\{#ProductName} - Logs"; Filename: "{localappdata}\EdaAgentOfflineSetup\Logs"
Name: "{group}\{cm:UninstallProgram,{#ProductName}}"; Filename: "{uninstallexe}"

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
#if Backend == "altium"
Type: files; Name: "{app}\Altium-Menu-Commands.txt"
Type: files; Name: "{app}\workspace\eda-menu-enabled"
Type: files; Name: "{app}\workspace\eda-menu-state.json"
Type: dirifempty; Name: "{app}\workspace\eda-menu-session.lock"
#endif
#include GeneratedFiles
Type: dirifempty; Name: "{app}\scripts"

[Code]
var
  CopyrightLabel: TNewStaticText;
  ConfigurationFailed: Boolean;
  PreflightReady: Boolean;
  DiagnosticLogFile: String;
  OperationCompleted: Boolean;

procedure DiagnosticEvent(const EventName: String; Code: Integer);
begin
  { Only fixed events and numeric codes are persisted. No config or child output. }
  if DiagnosticLogFile <> '' then
    if not SaveStringToFile(DiagnosticLogFile, Utf8Encode(
        GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') +
        ' event=' + EventName + ' code=' + IntToStr(Code) + #13#10), True) then
      Log('Could not update the diagnostic log.');
end;

function CreateDiagnosticLog(const Directory, Operation: String): Boolean;
var
  Name: String;
begin
  Result := False;
  if not ForceDirectories(Directory) then Exit;
  Name := Operation + '-{#Backend}-' + GetDateTimeString('yyyymmdd-hhnnss', '-', '-') +
    '-' + IntToStr(Random(2147483647)) + '.log';
  DiagnosticLogFile := AddBackslash(Directory) + Name;
  while FileExists(DiagnosticLogFile) do
    DiagnosticLogFile := AddBackslash(Directory) + Operation + '-{#Backend}-' +
      GetDateTimeString('yyyymmdd-hhnnss', '-', '-') + '-' + IntToStr(Random(2147483647)) + '.log';
  Result := SaveStringToFile(DiagnosticLogFile, '', False);
  if not Result then DiagnosticLogFile := '';
end;

procedure StartDiagnosticLog(const Operation: String);
var
  Created: Boolean;
begin
  Created := CreateDiagnosticLog(ExpandConstant('{localappdata}\EdaAgentOfflineSetup\Logs'), Operation);
  if not Created then
    Created := CreateDiagnosticLog(ExpandConstant('{%TEMP}\EdaAgentOfflineSetup\Logs'), Operation);
  if Created then begin
    DiagnosticEvent('started', 0);
    DiagnosticEvent('version-{#SetupVersion}', 0);
  end else Log('Could not create a diagnostic log.');
end;

function InitializeSetup: Boolean;
begin
  StartDiagnosticLog('install');
  Result := True;
end;

procedure DeinitializeSetup;
begin
  if not OperationCompleted then DiagnosticEvent('not-completed', 1);
  DiagnosticEvent('closed', 0);
end;

function InitializeUninstall: Boolean;
begin
  StartDiagnosticLog('uninstall');
  Result := True;
end;

procedure DeinitializeUninstall;
begin
  if not OperationCompleted then DiagnosticEvent('not-completed', 1);
  DiagnosticEvent('closed', 0);
end;

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
      WizardForm.FinishedLabel.Caption := FmtMessage(CustomMessage('ConfigurationFailed'), [DiagnosticLogFile]);
    end else
      WizardForm.FinishedLabel.Caption := CustomMessage('FinishedLabel');
  end;
end;

function OpenCodeConfigPath: String;
begin
  Result := ExpandConstant('{param:OPENCODECONFIG|}');
  if Result = '' then begin
    Result := ExpandConstant('{%USERPROFILE}\.config\opencode\opencode.jsonc');
    if (not FileExists(Result)) and FileExists(ExpandConstant('{%USERPROFILE}\.config\opencode\opencode.json')) then
      Result := ExpandConstant('{%USERPROFILE}\.config\opencode\opencode.json');
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ConfigPath, Parameters: String;
  ResultCode: Integer;
begin
  Result := '';
  DiagnosticEvent('preflight', 0);
#if Backend == "altium"
  if WizardIsTaskSelected('altiummenu') then begin
    Parameters := '-NoProfile -NonInteractive -Command "if (Get-Process -Name X2,DXP -ErrorAction SilentlyContinue) { exit 1 }"';
    ResultCode := -1;
    if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Result := CustomMessage('CloseAltium')
    else if ResultCode <> 0 then
      Result := CustomMessage('CloseAltium');
    if Result <> '' then begin
      DiagnosticEvent('altium-preflight-failed', ResultCode);
      Result := Result + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]);
      Exit;
    end;
  end;
#endif
  if not PreflightReady then begin
    ExtractTemporaryFiles('{tmp}\preflight\*');
    PreflightReady := True;
  end;
  Parameters := '"' + ExpandConstant('{tmp}') + '\preflight\check_install_target.py" "' + ExpandConstant('{app}') + '" {#Backend}';
  if not Exec(ExpandConstant('{tmp}\preflight\runtime\python.exe'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
    Result := CustomMessage('WrongDirectory');
    DiagnosticEvent('target-preflight-failed', -1);
    Result := Result + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]);
    Exit;
  end;
  if ResultCode <> 0 then begin
    Result := CustomMessage('WrongDirectory');
    DiagnosticEvent('target-preflight-failed', ResultCode);
    Result := Result + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]);
    Exit;
  end;
  if WizardIsTaskSelected('opencode') then begin
    ConfigPath := OpenCodeConfigPath;
    Parameters := '"' + ExpandConstant('{tmp}') + '\preflight\configure_opencode.py" "' + ConfigPath + '" --check';
    if not Exec(ExpandConstant('{tmp}\preflight\runtime\python.exe'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Result := FmtMessage(CustomMessage('InvalidConfig'), [ConfigPath])
    else if ResultCode <> 0 then
      Result := FmtMessage(CustomMessage('InvalidConfig'), [ConfigPath]);
  end;
  if Result <> '' then begin
    DiagnosticEvent('config-preflight-failed', ResultCode);
    Result := Result + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Parameters, ConfigPath, LogFile: String;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then DiagnosticEvent('copying-files', 0);
  if CurStep = ssDone then begin
    OperationCompleted := True;
    if ConfigurationFailed then DiagnosticEvent('failed', 10)
    else DiagnosticEvent('completed', 0);
  end;
  if CurStep = ssPostInstall then begin
    WizardForm.StatusLabel.Caption := CustomMessage('Configuring');
    LogFile := DiagnosticLogFile;
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Invoke-Setup.ps1') + '" -LogPath "' + LogFile + '"';
#if Backend == "altium"
    if WizardIsTaskSelected('altiummenu') then
      Parameters := Parameters + ' -EnableAltiumMenu';
#endif
    if WizardIsTaskSelected('opencode') then begin
      Parameters := Parameters + ' -ConfigureOpenCode';
      ConfigPath := OpenCodeConfigPath;
      if ConfigPath <> '' then
        Parameters := Parameters + ' -OpenCodeConfig "' + ConfigPath + '"';
    end;
    ResultCode := -1;
    if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      ConfigurationFailed := True
    else if ResultCode <> 0 then
      ConfigurationFailed := True;
    if ConfigurationFailed then begin
      DiagnosticEvent('configuration-failed', ResultCode);
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
  if CurUninstallStep = usDone then begin
    OperationCompleted := True;
    DiagnosticEvent('completed', 0);
  end;
  if CurUninstallStep = usUninstall then begin
    DiagnosticEvent('removing-files', 0);
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\Unregister-Integration.ps1') +
      '" -InstallDir "' + ExpandConstant('{app}') + '" -LogPath "' + DiagnosticLogFile + '"';
    ResultCode := -1;
    if not Exec(PowerShellPath, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
      DiagnosticEvent('integration-removal-failed', ResultCode);
      RaiseException(CustomMessage('UnregisterFailed') + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]));
    end;
    if ResultCode <> 0 then begin
      DiagnosticEvent('integration-removal-failed', ResultCode);
      RaiseException(CustomMessage('UnregisterFailed') + #13#10 + FmtMessage(CustomMessage('DiagnosticDetails'), [DiagnosticLogFile]));
    end;
  end;
end;
