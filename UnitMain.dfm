object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 565
  ClientWidth = 966
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    966
    565)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 56
    Top = 240
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label2: TLabel
    Left = 56
    Top = 280
    Width = 31
    Height = 13
    Caption = 'Label2'
  end
  object BitBtn1: TBitBtn
    Left = 200
    Top = 520
    Width = 145
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = '&Convert XML file'
    Kind = bkRetry
    NumGlyphs = 2
    TabOrder = 0
    OnClick = BitBtn1Click
  end
  object BitBtn2: TBitBtn
    Left = 864
    Top = 520
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Kind = bkClose
    NumGlyphs = 2
    TabOrder = 1
  end
  object MemoLog: TMemo
    Left = 8
    Top = 8
    Width = 942
    Height = 169
    ScrollBars = ssBoth
    TabOrder = 2
  end
  object BitBtnGetXML: TBitBtn
    Left = 32
    Top = 520
    Width = 153
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Get XML from website'
    Kind = bkOK
    NumGlyphs = 2
    TabOrder = 3
    OnClick = BitBtnGetXMLClick
  end
  object ProgressBar1: TProgressBar
    Left = 32
    Top = 472
    Width = 907
    Height = 17
    TabOrder = 4
  end
  object Button1: TButton
    Left = 456
    Top = 520
    Width = 171
    Height = 25
    Caption = '111'
    TabOrder = 5
    OnClick = Button1Click
  end
  object MemoXML: TMemo
    Left = 8
    Top = 192
    Width = 489
    Height = 265
    Lines.Strings = (
      'MemoXML')
    ScrollBars = ssBoth
    TabOrder = 6
  end
  object MemoOpen: TMemo
    Left = 512
    Top = 192
    Width = 438
    Height = 265
    ScrollBars = ssBoth
    TabOrder = 7
  end
  object OD: TOpenDialog
    DefaultExt = '*.xml'
    Filter = 'XML files|*.xml'
    Left = 88
    Top = 376
  end
  object IdHTTP: TIdHTTP
    OnWork = IdHTTPWork
    OnWorkBegin = IdHTTPWorkBegin
    OnWorkEnd = IdHTTPWorkEnd
    AllowCookies = True
    ProxyParams.BasicAuthentication = False
    ProxyParams.ProxyPort = 0
    Request.ContentLength = -1
    Request.ContentRangeEnd = -1
    Request.ContentRangeStart = -1
    Request.ContentRangeInstanceLength = -1
    Request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    Request.BasicAuthentication = True
    Request.Password = 'skirawroclaw'
    Request.UserAgent = 'Mozilla/3.0 (compatible; Indy Library)'
    Request.Username = 'admin'
    Request.Ranges.Units = 'bytes'
    Request.Ranges = <>
    HTTPOptions = [hoForceEncodeParams]
    Left = 40
    Top = 320
  end
  object ZConnection1: TZConnection
    ControlsCodePage = cCP_UTF16
    Catalog = ''
    HostName = 'localhost'
    Port = 0
    Database = ''
    User = ''
    Password = ''
    Protocol = ''
    Left = 312
    Top = 248
  end
  object ZQuery1: TZQuery
    Params = <>
    Left = 408
    Top = 376
  end
  object ZStoredProc1: TZStoredProc
    Params = <>
    Left = 680
    Top = 272
  end
  object ZSQLMonitor1: TZSQLMonitor
    MaxTraceCount = 100
    Left = 832
    Top = 280
  end
  object ZUpdateSQL1: TZUpdateSQL
    UseSequenceFieldForRefreshSQL = False
    Left = 296
    Top = 352
  end
end