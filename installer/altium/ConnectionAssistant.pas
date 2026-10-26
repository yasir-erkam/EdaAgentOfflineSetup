{ Local offline integration. All manual menu entries use the external assistant. }
Procedure EdaAssistantInit(Dummy : Integer);
Begin
    If EdaMenuCaller <> '' Then Exit;
    InitDefaultConfig(0);
    EnsureWorkspaceDir(0);
    EdaMenuCaller := EdaMenuNewRevision(0);
    WriteFileContent(WorkspaceDir + 'eda-assistant-caller-' + EdaMenuCaller + '.json',
        '{"caller_id":"' + EdaMenuCaller + '"}');
End;

Procedure DispatchConnectionAssistant;
Var
    Intent, Nonce, Caller, Action, Reply : String;
Begin
    InitDefaultConfig(0);
    EnsureWorkspaceDir(0);
    If Not FileExists(WorkspaceDir + 'eda-assistant-launch.lock\intent.json') Then Exit;
    Intent := ReadFileContent(WorkspaceDir + 'eda-assistant-launch.lock\intent.json');
    Nonce := ExtractJsonValue(Intent, 'nonce');
    If (Length(Nonce) <> 32) Or (Pos('..', Nonce) > 0) Or
       (Pos('\', Nonce) > 0) Or (Pos('/', Nonce) > 0) Then Exit;
    If ExtractJsonValue(Intent, 'expires') < FormatDateTime('yyyymmddhhnnss', Now) Then Exit;
    Caller := ExtractJsonValue(Intent, 'caller_id');
    Action := ExtractJsonValue(Intent, 'action');
    { Consume before any state change; a replay cannot start a second bridge. }
    If Not DeleteFile(WorkspaceDir + 'eda-assistant-launch.lock\intent.json') Then Exit;
    Reply := '{"nonce":"' + Nonce + '","error":"Calling Altium context changed; reopen Connection Assistant."}';
    If (Action = 'prepare') And (Caller = '') Then EdaAssistantInit(0);
    If ((Action = 'prepare') And (Caller = '')) Or
       ((Caller <> '') And (Caller = EdaMenuCaller) And
        (ExtractJsonValue(Intent, 'session_id') = EdaMenuSession)) Then
    Begin
        If (Action = 'start') And (Not PumpInTick) Then StartMCPPump(0);
        If (Action = 'prepare') Or ((Action = 'start') And EdaMenuPumpActive(0)) Then
            Reply := '{"nonce":"' + Nonce + '","caller_id":"' + EdaMenuCaller
                + '","session_id":"' + EdaMenuSession + '","running":' + BoolToJsonStr(Running) + '}';
    End;
    WriteFileContent(WorkspaceDir + 'eda-assistant-launch.lock\response-' + Nonce + '.json', Reply);
End;

Procedure EdaAssistantLaunch(Action : String);
Var
    CommandLine : String;
    LaunchError : Integer;
Begin
    EdaAssistantInit(0);
    CommandLine := 'powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "'
        + WorkspaceDir + '..\Connection-Assistant.ps1" -CallerId "' + EdaMenuCaller
        + '" -Action ' + Action;
    If EdaMenuSession <> '' Then CommandLine := CommandLine + ' -SessionId "' + EdaMenuSession + '"';
    LaunchError := RunApplication(CommandLine);
    If LaunchError <> 0 Then ShowMessage('Connection Assistant could not be launched: ' + IntToStr(LaunchError));
End;

Procedure ShowConnectionAssistant;
Begin
    EdaAssistantLaunch('Show');
End;

Procedure StartConnectionAssistant;
Begin
    EdaAssistantLaunch('Start');
End;

Procedure StatusConnectionAssistant;
Begin
    EdaAssistantLaunch('Status');
End;

Procedure DisconnectConnectionAssistant;
Begin
    EdaAssistantLaunch('Disconnect');
End;

Procedure ReconnectConnectionAssistant;
Begin
    EdaAssistantLaunch('Reconnect');
End;
