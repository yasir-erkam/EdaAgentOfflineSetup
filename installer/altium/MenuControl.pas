{ Local EDA Agent offline integration. MIT; upstream units retain their license. }
{ Included in StatusForm after pump globals and before ProcessCommand. }

Function EdaMenuPumpActive(Dummy : Integer) : Boolean;
Begin
    Result := False;
    If Not Running Then Exit;
    Try Result := tmr_Poll.Enabled; Except End;
End;

Function EdaMenuNewRevision(Dummy : Integer) : String;
Begin
    Inc(EdaMenuCounter);
    Result := FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' + IntToStr(GetTickCount) + '-' + IntToStr(EdaMenuCounter);
End;

Procedure EdaMenuPublish(Dummy : Integer);
Begin
    WriteFileContent(WorkspaceDir + 'eda-menu-state.json',
        '{"revision":"' + EdaMenuRevision + '","target_project":"'
        + EscapeJsonString(EdaMenuTarget) + '","running":' + BoolToJsonStr(Running) + '}');
End;

Function EdaMenuProject(Path : String) : IProject;
Var
    W : IWorkspace;
    P : IProject;
    I : Integer;
Begin
    Result := Nil;
    If Path = '' Then Exit;
    W := GetWorkspace;
    If W = Nil Then Exit;
    For I := 0 To W.DM_ProjectCount - 1 Do
    Begin
        P := W.DM_Projects(I);
        If P = Nil Then Continue;
        If UpperCase(ExtractFileExt(P.DM_ProjectFullPath)) <> '.PRJPCB' Then Continue;
        If UpperCase(P.DM_ProjectFullPath) = UpperCase(Path) Then
        Begin
            Result := P;
            Exit;
        End;
    End;
End;

Procedure EdaMenuValidateTarget(Dummy : Integer);
Begin
    If EdaMenuTarget = '' Then Exit;
    If EdaMenuProject(EdaMenuTarget) <> Nil Then Exit;
    EdaMenuTarget := '';
    EdaMenuRevision := EdaMenuNewRevision(0);
    EdaMenuPublish(0);
End;

Function EdaMenuAcquire(Dummy : Integer) : Boolean;
Begin
    Result := True;
    EdaMenuEnabled := FileExists(WorkspaceDir + 'eda-menu-enabled');
    If Not EdaMenuEnabled Then Exit;
    Result := False;
    Try
        { MkDir is atomic and fails if another session (or a stale lease) exists. }
        { Avoid TStream descendants: Altium does not support their Int64 APIs. }
        MkDir(WorkspaceDir + 'eda-menu-session.lock');
        EdaMenuOwnsLease := True;
        EdaMenuTarget := '';
        EdaMenuCounter := 0;
        EdaMenuRevision := EdaMenuNewRevision(0);
        EdaMenuSession := EdaMenuRevision;
        Result := True;
    Except
        ShowMessage('EDA Agent: another bridge owns this workspace, or the session lock cannot be opened.');
    End;
End;

Procedure EdaMenuRelease(Dummy : Integer);
Begin
    If Not EdaMenuEnabled Then Exit;
    EdaMenuTarget := '';
    EdaMenuRevision := EdaMenuNewRevision(0);
    Try EdaMenuPublish(0); Except End;
    If EdaMenuOwnsLease Then
    Begin
        RmDir(WorkspaceDir + 'eda-menu-session.lock');
        EdaMenuOwnsLease := False;
    End;
End;

Function EdaMenuStatus(RequestId : String) : String;
Var
    W : IWorkspace;
    P : IProject;
    D : IDocument;
    Projects, ActiveDoc, FocusedProject : String;
    I : Integer;
Begin
    EdaMenuValidateTarget(0);
    Projects := '';
    ActiveDoc := '';
    FocusedProject := '';
    W := GetWorkspace;
    If W <> Nil Then
    Begin
        For I := 0 To W.DM_ProjectCount - 1 Do
        Begin
            P := W.DM_Projects(I);
            If P = Nil Then Continue;
            If UpperCase(ExtractFileExt(P.DM_ProjectFullPath)) <> '.PRJPCB' Then Continue;
            If Projects <> '' Then Projects := Projects + ',';
            Projects := Projects + '"' + EscapeJsonString(P.DM_ProjectFullPath) + '"';
        End;
        P := W.DM_FocusedProject;
        If P <> Nil Then FocusedProject := P.DM_ProjectFullPath;
        D := W.DM_FocusedDocument;
        If D <> Nil Then ActiveDoc := D.DM_FullPath;
    End;
    Result := BuildSuccessResponse(RequestId,
        '{"integration_version":1,"running":' + BoolToJsonStr(Running)
        + ',"session_id":"' + EdaMenuSession + '"'
        + ',"revision":"' + EdaMenuRevision + '","target_project":"'
        + EscapeJsonString(EdaMenuTarget) + '","focused_project":"'
        + EscapeJsonString(FocusedProject) + '","active_document":"'
        + EscapeJsonString(ActiveDoc) + '","projects":[' + Projects + ']}');
End;

Function EdaMenuSelect(Path : String; Revision : String; RequestId : String) : String;
Begin
    If Revision <> EdaMenuRevision Then
    Begin
        Result := BuildErrorResponse(RequestId, 'STALE_MENU_STATE', 'Refresh connection status before changing the target.');
        Exit;
    End;
    If EdaMenuProject(Path) = Nil Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_NOT_OPEN', 'Select an open PCB design project by its full path.');
        Exit;
    End;
    EdaMenuTarget := Path;
    EdaMenuRevision := EdaMenuNewRevision(0);
    EdaMenuPublish(0);
    Result := EdaMenuStatus(RequestId);
End;

Function EdaMenuOwnsDocument(Path : String) : Boolean;
Var
    W : IWorkspace;
    P : IProject;
    D : IDocument;
    I, J, Owners : Integer;
Begin
    Result := False;
    W := GetWorkspace;
    If (W = Nil) Or (Path = '') Then Exit;
    Owners := 0;
    For I := 0 To W.DM_ProjectCount - 1 Do
    Begin
        P := W.DM_Projects(I);
        If P = Nil Then Continue;
        For J := 0 To P.DM_LogicalDocumentCount - 1 Do
        Begin
            D := P.DM_LogicalDocuments(J);
            If D = Nil Then Continue;
            If UpperCase(D.DM_FullPath) <> UpperCase(Path) Then Continue;
            Inc(Owners);
            If UpperCase(P.DM_ProjectFullPath) = UpperCase(EdaMenuTarget) Then Result := True;
            Break;
        End;
    End;
    { A shared document is ambiguous even when one owner is selected. }
    If Owners <> 1 Then Result := False;
End;

Function EdaMenuGuard(Command : String; Params : String; RequestId : String) : String;
Var
    W : IWorkspace;
    P : IProject;
    D : IDocument;
    Path : String;
Begin
    Result := '';
    If Not EdaMenuEnabled Then Exit;
    EdaMenuValidateTarget(0);
    If (Command = 'application.ping') Or (Command = 'application.get_version') Or
       (Command = 'application.get_unit_stamps') Or (Command = 'eda_menu.status') Then Exit;
    If ExtractJsonValue(Params, '_eda_menu_revision') <> EdaMenuRevision Then
    Begin
        Result := BuildErrorResponse(RequestId, 'STALE_MENU_STATE', 'Target changed or bridge restarted; refresh and retry explicitly.');
        Exit;
    End;
    If (Command = 'eda_menu.select') Or (Command = 'eda_menu.disconnect') Then Exit;
    If EdaMenuTarget = '' Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_REQUIRED', 'Use EDA Agent > Target project before design commands.');
        Exit;
    End;
    { Reviewed scope table: no arbitrary scripts, processes, libraries or save-all. }
    If (Command <> 'pcb.get_components') And (Command <> 'pcb.get_nets') And
       (Command <> 'pcb.batch_move_components') Then
    Begin
        Result := BuildErrorResponse(RequestId, 'UNREVIEWED_TARGET_SCOPE',
            'This command is not yet supported in guarded menu mode. See the target scope table.');
        Exit;
    End;
    Path := ExtractJsonValue(Params, 'project_path');
    If (Path <> '') And (UpperCase(Path) <> UpperCase(EdaMenuTarget)) Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'Explicit project path differs from the selected target.');
        Exit;
    End;
    W := GetWorkspace;
    If W = Nil Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'No focused workspace.');
        Exit;
    End;
    P := W.DM_FocusedProject;
    D := W.DM_FocusedDocument;
    If (P = Nil) Or (D = Nil) Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'Focus a PCB document in the selected project.');
        Exit;
    End;
    If (UpperCase(P.DM_ProjectFullPath) <> UpperCase(EdaMenuTarget)) Or
       (UpperCase(D.DM_DocumentKind) <> 'PCB') Or (Not EdaMenuOwnsDocument(D.DM_FullPath)) Then
    Begin
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'Focused PCB must belong only to the selected project.');
        Exit;
    End;
    { These three handlers use GetPCBBoardAnywhere: require its fast path and }
    { verify the board identity, so its cross-project fallback is never used. }
    If PCBServer.GetCurrentPCBBoard = Nil Then
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'No current PCB board.')
    Else If UpperCase(PCBServer.GetCurrentPCBBoard.FileName) <> UpperCase(D.DM_FullPath) Then
        Result := BuildErrorResponse(RequestId, 'TARGET_MISMATCH', 'Current board does not match the focused document.');
End;

Function EdaMenuCommand(Command : String; Params : String; RequestId : String) : String;
Begin
    If Not EdaMenuEnabled Then
    Begin
        Result := BuildErrorResponse(RequestId, 'MENU_NOT_ENABLED', 'Enable guarded Altium menu support in setup first.');
        Exit;
    End;
    If Command = 'eda_menu.status' Then Result := EdaMenuStatus(RequestId)
    Else If Command = 'eda_menu.select' Then
        Result := EdaMenuSelect(ExtractJsonValue(Params, 'project_path'),
            ExtractJsonValue(Params, '_eda_menu_revision'), RequestId)
    Else If Command = 'eda_menu.disconnect' Then
    Begin
        { Executed serially by the pump after the previous handler returned. }
        Running := False;
        EdaMenuTarget := '';
        EdaMenuRevision := EdaMenuNewRevision(0);
        EdaMenuPublish(0);
        Result := BuildSuccessResponse(RequestId, '{"stopping":true,"saved":false}');
    End
    Else Result := BuildErrorResponse(RequestId, 'UNKNOWN_COMMAND', 'Unknown EDA menu command.');
End;
