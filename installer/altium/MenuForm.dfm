object EdaMenuForm: TEdaMenuForm
  Left = 250
  Top = 200
  Caption = 'EDA Agent'
  ClientHeight = 420
  ClientWidth = 760
  Position = poScreenCenter
  Font.Name = 'Segoe UI'
  Font.Height = -13
  object btn_Start: TButton
    Left = 16
    Top = 16
    Width = 230
    Height = 38
    Caption = 'Ba'#287'lant'#305'y'#305' ba'#351'lat / Start connection'
    OnClick = btn_StartClick
  end
  object btn_Status: TButton
    Left = 262
    Top = 16
    Width = 230
    Height = 38
    Caption = 'Ba'#287'lant'#305' durumu / Connection status'
    OnClick = btn_StatusClick
  end
  object btn_Disconnect: TButton
    Left = 508
    Top = 16
    Width = 236
    Height = 38
    Caption = 'Ba'#287'lant'#305'y'#305' kes / Disconnect'
    OnClick = btn_DisconnectClick
  end
  object cb_Projects: TComboBox
    Left = 16
    Top = 72
    Width = 476
    Height = 28
    Style = csDropDownList
    TabOrder = 3
  end
  object btn_Target: TButton
    Left = 508
    Top = 68
    Width = 236
    Height = 38
    Caption = 'Hedef proje / Target project'
    OnClick = btn_TargetClick
  end
  object btn_Help: TButton
    Left = 16
    Top = 120
    Width = 728
    Height = 38
    Caption = 'Yard'#305'm ve sorun giderme / Help and troubleshooting'
    OnClick = btn_HelpClick
  end
  object memo_Status: TMemo
    Left = 16
    Top = 176
    Width = 728
    Height = 228
    ReadOnly = True
    ScrollBars = ssBoth
    WordWrap = True
    TabOrder = 5
  end
end
