﻿unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.DateUtils, System.Variants,
  System.Classes,System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP,
  IdIOHandler, IdIOHandlerStream, Data.DBXOdbc, Data.FMTBcd, Data.SqlExpr,
  Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef,
  FireDAC.VCLUI.Wait, FireDAC.Comp.Client, Data.DBXMySQL, FireDAC.Phys.TDBXDef,
  FireDAC.Phys.TDBXBase, FireDAC.Phys.TDBX, Data.DBXPool, Data.DBXTrace,
  Data.DBXMSSQL, ZSqlUpdate, ZSqlMonitor, ZStoredProcedure, ZAbstractRODataset,
  ZAbstractDataset, ZDataset, ZAbstractConnection, ZConnection;

const CRLF=chr($0D)+chr($0A);
type
TParsedRec = record
  SKU, EAN, Description, Name, Color, Size, qty, price, assortment, product_type, manufacturer, category, image1, image2:UnicodeString;
end;
type
  TForm2 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    MemoLog: TMemo;
    OD: TOpenDialog;
    BitBtnGetXML: TBitBtn;
    IdHTTP: TIdHTTP;
    ProgressBar1: TProgressBar;
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    ZConnection1: TZConnection;
    ZQuery1: TZQuery;
    ZStoredProc1: TZStoredProc;
    ZSQLMonitor1: TZSQLMonitor;
    ZUpdateSQL1: TZUpdateSQL;
    MemoXML: TMemo;
    MemoOpen: TMemo;
    procedure IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64);
    procedure BitBtnGetXMLClick(Sender: TObject);
    procedure IdHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure BitBtn1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
  isFileTransferred:boolean;
  ProgramDir:string;
  public
  procedure Log(Msg:string);
  function GetXMLFile(FileName:string):boolean;
  procedure ConvertXMLToOpenCart(XMLName:string);
  function ParseLine(S:UnicodeString):TParsedRec;
  function SaveLine(R:TParsedRec):UnicodeString;
  procedure FindTag(const S:UnicodeString; const Tag:UnicodeString; var TagValue:UnicodeString);
  function ReplaceHTMLSymbols(const S:UnicodeString):Unicodestring;
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.BitBtn1Click(Sender: TObject);
var XMLName:string;
 Year, Month, Day: Word;
GotIt:boolean;
begin
DecodeDate(Now(), Year, Month, Day);
XMLName:=ExtractFilepath(Paramstr(0))+'get-'+IntToStr(Year)+IntToStr(Month)+IntToStr(Day)+'.xml';
if FileExists(XMLName)
  then Log('Обрабатываем '+XMLName)
  else
    begin
    GotIt:=GetXMLFile(ExtractFilepath(Paramstr(0))+'get.xml');
    if GotIt then Log('Обрабатываем '+XMLName)
    else Log('Невозможно скачать файл, отмена обработки '+XMLName);
    exit;
    end;
//ConvertXMLToOpenCart(XMLName);
ConvertXMLToOpenCart('20181219 — cutted.xml');
end;

procedure TForm2.BitBtnGetXMLClick(Sender: TObject);
var
 FGetStream:TFileStream;
 FXMLStream :TFileStream;
 GetName:string;
 XMLName:string;
 S:UnicodeString;
 sr:TSearchRec;
 Year, Month, Day: Word;
begin
Log('Очищаем после прошлого запуска...');
ProgramDir:=ExtractFilepath(Paramstr(0));
if FindFirst(ProgramDir+'\get*.xml', FaAnyFile, sr)=0 then
   repeat
    DeleteFile(ProgramDir+sr.Name);
    Sleep(1000);
    Log('Файл '+sr.Name+ ' удалён');
    until Findnext(sr)<>0;
FindClose(sr);
if not GetXMLFile(ExtractFilepath(Paramstr(0))+'get.xml') then exit;
try
  DecodeDate(Now(), Year, Month, Day);
  XMLName:=ExtractFilepath(Paramstr(0))+'get-'+IntToStr(Year)+IntToStr(Month)+IntToStr(Day)+'.xml';
  FXMLStream := TFileStream.Create(XMLName, fmCreate);
  GetName:=ExtractFilepath(Paramstr(0))+'get.xml';
  FGetStream := TFileStream.Create(GetName, fmOpenRead);
  SetLength(S, FGetStream.Size);
  FGetStream.ReadBuffer(S[1], FGetStream.Size);
  S:=StringReplace(S, '</product>','</product>'+Char($0D)+Char($0A),[rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  FXMLStream.WriteBuffer(S[1], Length(S));
  finally
    FXMLStream.Free;
    FGetStream.Free;
  end;
if FileExists(GetName) then begin DeleteFile(GetName); Sleep(1000);end;
Log('Создаём новые файлы для загрузки ');
end;

procedure TForm2.Button1Click(Sender: TObject);
var
  Connection: TSQLConnection;
begin
// https://www.justsoftwaresolutions.co.uk/delphi/dbexpress_and_mysql_5.html
  Connection := TSQLConnection.Create(nil);
  Connection.DriverName := 'dbxmysql';
  Connection.GetDriverFunc := 'getSQLDriverMYSQL50';
  Connection.LibraryName := 'dbxopenmysql50.dll';
  Connection.VendorLib := 'libmysql.dll';
  Connection.Params.Append('Database=NAME_OF_DATABASE');
  Connection.Params.Append('User_Name=NAME_OF_USER');
  Connection.Params.Append('Password=PASSWORD');
  Connection.Params.Append('HostName=localhost');
  Connection.Open;

  // ... do stuff

  Connection.Free;
end;

procedure TForm2.ConvertXMLToOpenCart(XMLName: string);
var OpenName:String;
 S:UnicodeString;
 FOpenText:TextFile;
 FXMLtext :TextFile;
 R:TParsedRec;
 FS:TFormatSettings;
begin
OpenName:=StringReplace(XMLName, '.xml', '_oc.xml', [rfIgnoreCase]);
try
AssignFile(FOpenText, OpenName);
AssignFile(FXMLText, XMLName);
FileMode:=0;
Reset(FXMLText);
FileMode:=2;
Rewrite(FOpenText);
FS:=TFormatSettings.Create('en-US');
Writeln(FOpentext, '<?xml version="1.0"?> <itemlist> <title>XML Export - '+DateTimeToStr(Now, FS)+' </title>');
while not EOF(FXMLText) do
  begin
  Readln(FXMLText, S);
  MemoXML.Lines.Add(S);
  if Pos('xml version=', S) >0 then continue;
  if Pos('</products>', S) >0 then continue;
  if (Pos('<product>', S) >0) and (Pos('</product>', S)>0) then
    begin
    R:=ParseLine(S);
    MemoOpen.Lines.Add(
    'sku="'+r.sku+
    '" ean="'+r.ean+
    '" name="'+r.name+
    '" color="'+r.color+
    '" size="'+r.size+
    '" qty="'+r.qty+
    '" price="'+r.price+
    '" assortment="'+r.assortment+
    '" type="'+r.product_type+
    '" manufacturer="'+r.manufacturer+
    '" category="'+r.category+
    '" image1="'+r.image1+
    '" image2="'+r.image2+
    '"');
    MemoOpen.Lines.Add('description="'+r.description);
    Writeln(FOpenText, SaveLine(R));
    end;

  end;
Writeln(FOpentext, '</itemlist>');
finally
    CloseFile(FXMLtext);
    CloseFile(FOpenText);
  end;
end;

procedure TForm2.FindTag(const S:UnicodeString; const Tag:UnicodeString;  var TagValue:UnicodeString);
var Tag1, Tag2:UnicodeString;
Pos1, Pos2:integer;
begin
if Tag='' then begin TagValue:=''; exit; end;
Tag1:='<'+trim(lowercase(Tag))+'>';
Tag2:='</'+trim(lowercase(Tag))+'>';
if tag='image1' then begin Tag1:='<image>'; Tag2:='</image>'; end;
if tag='image2' then begin Tag1:='</image><image>'; Tag2:='</image></media>'; end;
if (Pos(Tag1, lowercase(S))>0) and  (Pos(Tag2, lowercase(S))>0) then
  begin
  Pos1:=Pos(Tag1, lowercase(S));
  Pos2:=Pos(Tag2, lowercase(S), pos1+1);
  TagValue:=Trim(Copy(S,Pos1+length(Tag1),1+Pos2-Pos1-Length(Tag2)));
  end
  else TagValue:='';
end;

function TForm2.GetXMLFile(FileName: string): boolean;
var  FGetStream:TFileStream;
begin
FGetStream := TFileStream.Create(FileName, fmCreate);
isFileTransferred:=false;
try
Log('Подключаемся....');
idHTTP.Request.BasicAuthentication:=true;
idHTTP.Request.Username:='admin';
idHTTP.Request.Password:='skirawroclaw';
IdHTTP.Get('http://pro101.golddragon.info/data/get.xml', FGetStream);
except on E:Exception do
  begin
  Log('Ошибка при получении XML файла, не могу связаться с сайтом-источником '+E.Message);
  isFileTransferred:=false;
  end;
end;
FGetStream.Free;
// isFileTransferred =true получаем при событии IDHttp.OnWorkEnd
if not IsFileTransferred then
  begin
  Log('Не могу скачать файл с сайта ');
  Result:=false;
  end
else
  begin
  Log('Файл успешно скачан с сайта ');
  Result:=true;
  end;
end;

procedure TForm2.IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
 ProgressBar1.Position := AWorkCount;
end;

procedure TForm2.IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
ProgressBar1.Position := 0;
ProgressBar1.Max := AWorkcountMax;
end;

procedure TForm2.IdHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
isFileTransferred:=true;
end;

procedure TForm2.Log(Msg: string);
begin
MemoLog.Lines.Add(Msg);
end;

function TForm2.ParseLine(S: UnicodeString): TParsedRec;
var Str:UnicodeString;
R:TParsedRec;
begin
Str:=ReplaceHTMLSymbols(S);
Str:=StringReplace(Str,UnicodeString('<products>'), '',[rfReplaceAll, rfIgnoreCase]);
Str:=StringReplace(Str,UnicodeString('</products>'), '',[rfReplaceAll, rfIgnoreCase]);
FindTag(Str, 'sku', r.sku);
FindTag(Str, 'ean', r.ean);
FindTag(Str, 'description', r.description);
FindTag(Str, 'name', r.name);
FindTag(Str, 'color', r.color);
FindTag(Str, 'size', r.size);
FindTag(Str, 'qty', r.qty);
FindTag(Str, 'price', r.price);
FindTag(Str, 'assortment', r.assortment);
FindTag(Str, 'type', r.product_type);
FindTag(Str, 'manufacturer', r.manufacturer);
FindTag(Str, 'category', r.category);
FindTag(Str, 'image1', r.image1);
FindTag(Str, 'image2', r.image2);
Result:=R;
end;

function TForm2.ReplaceHTMLSymbols(const S: UnicodeString):UnicodeString;
var SR:UnicodeString;
begin
SR:=UnicodeString(S);
if Pos('&#x', SR)>0 then
  begin
  if Pos('&#x104;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x104;'), UnicodeString('Ą'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x105;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x105;'), UnicodeString('ą'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x106;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x106;'), UnicodeString('Ć'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x107;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x107;'), UnicodeString('ć'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x118;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x118;'), UnicodeString('Ę'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x119;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x119;'), UnicodeString('ę'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x15a;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x15a;'), UnicodeString('Ś'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x15b;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x15b;'), UnicodeString('ś'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x141;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x141;'), UnicodeString('Ł'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x142;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x142;'), UnicodeString('ł'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x143;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x143;'), UnicodeString('Ń'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x144;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x144;'), UnicodeString('ń'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x15a;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x15a;'), UnicodeString('Ś'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x15b;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x15b;'), UnicodeString('ś'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x179;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x179;'), UnicodeString('Ź'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x17a;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x17a;'), UnicodeString('ź'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x17b;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x17b;'), UnicodeString('Ż'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#x17c;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#x17c;'), UnicodeString('ż'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#xd3;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#xd3;'), UnicodeString('Ó'), [rfReplaceAll, rfIgnoreCase]);
  if Pos('&#xf3;', Lowercase(SR))>0 then
    SR:=StringReplace(SR, UnicodeString('&#xf3;'), UnicodeString('ó'), [rfReplaceAll, rfIgnoreCase]);
  end;
Result:=SR;
end;

function TForm2.SaveLine(R: TParsedRec):UnicodeString;
var St:UnicodeString;
 FS:TFormatSettings;
begin
FS:=TFormatSettings.Create('en-US');
St:='<item> '+CRLF+'	<category_id><![CDATA[17]]></category_id> '+CRLF;
if R.image1=''
  then St:=St+'	<image/> '
  else
    begin
    St:=St+'	<image><![CDATA['+R.image1;
    St:=St+']]></image>'+CRLF;
    end;
St:=St+'	<parent_id><![CDATA[52]]></parent_id> '+CRLF;
St:=St+'	<top><![CDATA[1]]></top> '+CRLF;
St:=St+'	<column><![CDATA[1]]></column> '+CRLF;
St:=St+'	<sort_order><![CDATA[4]]></sort_order> '+CRLF;
St:=St+'	<status><![CDATA[1]]></status> '+CRLF;
St:=St+'	<date_added><![CDATA['+DateTimeToStr(Now, FS)+']]></date_added> '+CRLF;
St:=St+'	<date_modified><![CDATA['+DateTimeToStr(Now, FS)+']]></date_modified> '+CRLF;
St:=St+'	<store><![CDATA[Интернет магазин Opencart "Русская сборка"]]></store> '+CRLF;
St:=St+'	<full_path_ru><![CDATA['+r.category+']]></full_path_ru> '+CRLF;
St:=St+'	<name_ru><![CDATA['+r.name+']]></name_ru> '+CRLF;
St:=St+'	<description_ru><![CDATA['+r.description+']]></description_ru> '+CRLF;
St:=St+'	<meta_title_ru><![CDATA['+r.name+']]></meta_title_ru> '+CRLF;
St:=St+'	<meta_description_ru/> '+CRLF;
St:=St+'	<meta_keyword_ru/> '+CRLF;
St:=St+'</item>';
Result:=St;
end;

end.