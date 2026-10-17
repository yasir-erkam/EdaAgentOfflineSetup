{ Local EDA Agent offline integration, MIT. Form events live in this unit. }
Procedure EdaMenuRefresh(Dummy : Integer);
Var
    W : IWorkspace;
    P : IProject;
    D : IDocument;
    ActiveDoc : String;
    I : Integer;
Begin
    EdaMenuValidateTarget(0);
    cb_Projects.Items.Clear;
    W := GetWorkspace;
    If W <> Nil Then
        For I := 0 To W.DM_ProjectCount - 1 Do
        Begin
            P := W.DM_Projects(I);
            If P = Nil Then Continue;
            If UpperCase(ExtractFileExt(P.DM_ProjectFullPath)) = '.PRJPCB' Then
                cb_Projects.Items.Add(P.DM_ProjectFullPath);
        End;
    cb_Projects.ItemIndex := cb_Projects.Items.IndexOf(EdaMenuTarget);
    ActiveDoc := '';
    If W <> Nil Then
    Begin
        D := W.DM_FocusedDocument;
        If D <> Nil Then ActiveDoc := D.DM_FullPath;
    End;
    If Running Then
    Begin
        If EdaMenuPumpActive(0) Then memo_Status.Text := 'Bridge running / Kopru calisiyor'
        Else memo_Status.Text := 'Unknown: polling is inactive / Durum belirsiz: pompa etkin degil';
    End
    Else memo_Status.Text := 'Disconnected / Baglanti kapali';
    memo_Status.Text := memo_Status.Text + #13#10 + 'Target project / Hedef proje: ' + EdaMenuTarget
        + #13#10 + 'Session / Oturum: ' + EdaMenuSession
        + #13#10 + 'Active document / Aktif belge: ' + ActiveDoc
        + #13#10 + 'Checked / Kontrol: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
        + #13#10 + 'OpenCode client connection is not verified by this check.'
        + #13#10 + 'OpenCode istemci baglantisi bu kontrolle dogrulanmaz.';
End;

Procedure btn_StartClick(Sender : TObject);
Begin
    If PumpInTick Then Begin ShowMessage('EDA Agent: command in progress; retry after it finishes.'); Exit; End;
    If Not Running Then Begin InitDefaultConfig(0); EnsureWorkspaceDir(0); End;
    If Not FileExists(WorkspaceDir + 'eda-menu-enabled') Then
    Begin
        ShowMessage('Enable guarded Altium menu support in setup first.');
        Exit;
    End;
    StartMCPPump(0);
    EdaMenuRefresh(0);
End;

Procedure btn_StatusClick(Sender : TObject);
Begin
    If PumpInTick Then Begin ShowMessage('EDA Agent: command in progress.'); Exit; End;
    EdaMenuRefresh(0);
End;

Procedure btn_TargetClick(Sender : TObject);
Var
    Reply : String;
Begin
    If PumpInTick Then Begin ShowMessage('EDA Agent: command in progress; target was not changed.'); Exit; End;
    If Not Running Then Begin ShowMessage('Start the connection first.'); Exit; End;
    If cb_Projects.ItemIndex < 0 Then Begin ShowMessage('Select an open project by full path.'); Exit; End;
    Reply := EdaMenuSelect(cb_Projects.Text, EdaMenuRevision, 'menu');
    If ExtractJsonValue(Reply, 'success') = 'false' Then
        ShowMessage(ExtractJsonValue(Reply, 'message'));
    EdaMenuRefresh(0);
End;

Procedure btn_DisconnectClick(Sender : TObject);
Var
    Reply : String;
Begin
    If PumpInTick Then Begin ShowMessage('EDA Agent: command in progress; connection was not stopped.'); Exit; End;
    If Not EdaMenuEnabled Then Begin ShowMessage('Guarded menu mode is not enabled.'); Exit; End;
    If Not Running Then Begin memo_Status.Text := 'Disconnected / Baglanti kapali'; Exit; End;
    Reply := EdaMenuCommand('eda_menu.disconnect', '{}', 'menu');
    memo_Status.Text := 'Stopping without saving / Kaydetmeden kesiliyor. Check status again / Durumu tekrar kontrol edin.';
End;

Procedure btn_HelpClick(Sender : TObject);
Begin
    memo_Status.Text :=
        'Setup: View > Toolbars > Customize > New > ScriptingSystem:RunScript.' + #13#10 +
        'ProjectName=<installation>\scripts\Altium_API.PrjScr|ProcName=MenuForm.pas>ShowEdaAgentMenu' + #13#10 +
        'Remove only this custom command in Customize; never use Restore.' + #13#10 +
        'Reconnect: Disconnect, wait until stopped, then Start. No force or automatic save.' + #13#10 +
        'Open the installed Altium Connection Assistant for localized setup and troubleshooting.' + #13#10 +
        'Guarded mode currently supports PCB get_components, get_nets and move_component only.';
End;

Procedure ShowEdaAgentMenu;
Begin
    If Not Running Then Begin InitDefaultConfig(0); EnsureWorkspaceDir(0); End;
    EdaMenuRefresh(0);
    EdaMenuForm.Show;
End;
