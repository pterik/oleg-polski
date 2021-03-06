﻿unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.DateUtils, System.Variants,
  System.Classes,System.IOUtils, System.Rtti, System.IniFiles,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP,
  IdIOHandler, IdIOHandlerStream, Data.DBXOdbc, Data.FMTBcd, Data.SqlExpr,
  Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef,
  FireDAC.VCLUI.Wait, FireDAC.Comp.Client, Data.DBXMySQL, FireDAC.Phys.TDBXDef,
  FireDAC.Phys.TDBXBase, FireDAC.Phys.TDBX, Data.DBXPool, Data.DBXTrace,
  Data.DBXMSSQL, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet;

const CRLF=chr($0D)+chr($0A);

type
defaults = record
     UniSt : Unicodestring;
 end;

type
TParsedRec = record
  sku, ean, description_pol, name_pol, color_pol,
  size, qty, price, assortment_pol, product_type_pol,
  manufacturer_pol, category_pol, image1, image2:UnicodeString;
end;
TProductRec = record
 product_id, model, sku, upc, ean, jan,
 isbn, mpn, location, quantity, stock_status_id,
 image, manufacturer_ru, manufacturer_pol, manufacturer_id, shipping, price, points,
 tax_class_id, date_available, weight, weight_class_id, length,
 width, height, length_class_id, subtract, minimum,
 sort_order, status, viewed, date_added, date_modified,
 import_batch, seo_keyword, link, store,
 name_ru, name_pol, fimage_ru, video1_ru, html_product_shortdesc_ru, html_product_right_ru,
 html_product_tab_ru, tab_title_ru, description_ru, description_pol, tag_ru,
 meta_title_ru, meta_description_ru, meta_keyword_ru, additional_images, product_filter,
 product_attribute, product_option, product_category, product_discount, product_special:UnicodeString;
end;
type
  TFormMain = class(TForm)
    BitBtnConvertXML: TBitBtn;
    BitBtn2: TBitBtn;
    MemoLog: TMemo;
    OD: TOpenDialog;
    BitBtnGetXML: TBitBtn;
    IdHTTP: TIdHTTP;
    PB: TProgressBar;
    ButtonCopyToDB: TButton;
    Label1: TLabel;
    Label2: TLabel;
    MemoXML: TMemo;
    MemoProduct: TMemo;
    SP_Save_Product: TFDStoredProc;
    FDQuery1: TFDQuery;
    FDCon: TFDConnection;
    procedure IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64);
    procedure BitBtnGetXMLClick(Sender: TObject);
    procedure IdHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure BitBtnConvertXMLClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ButtonCopyToDBClick(Sender: TObject);
  private
  isFileTransferred:boolean;
  ProgramDir:string;
  public
  FS:TFormatSettings;
  SiteUsername, SitePassword, SiteAddress:string;
  procedure Log(Msg:string);
  function GetXMLFile(FileName:string):boolean;
  procedure ConvertXMLToOpenCart(XMLName:string);
  procedure SaveXMLToDatabase(XMLName:string);
  procedure ParseLine(var R:TParsedRec; const S:UnicodeString);
  function  SaveProduct(P:TProductRec):UnicodeString;
  procedure FindTag(const S:UnicodeString; const Tag:UnicodeString; var TagValue:UnicodeString);
  function  SaveTag(TagName, TagValue:UnicodeString):UnicodeString;
  function  ReplaceHTMLSymbols(const S:UnicodeString):Unicodestring;
  procedure ClearParsedRec(var R:TParsedRec);
  procedure ClearProductRec(var W:TProductRec);
  procedure CopyRecords(R:TParsedRec; var P:TProductRec);
  function  Replace_Manufacturer_ID(Name:UnicodeString):UnicodeString;
  function  Replace_Manufacturer(Name:UnicodeString):UnicodeString;
  function  Replace_Category(CatName:UnicodeString):UnicodeString;
  function  Replace_Color(ColorName:UnicodeString):UnicodeString;
  function  SaveRecToDB(P: TParsedRec): boolean;
  function  PosR2L(const FindS, SrcS: UnicodeString): Integer;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.BitBtnConvertXMLClick(Sender: TObject);
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
ConvertXMLToOpenCart(XMLName);
end;

procedure TFormMain.BitBtnGetXMLClick(Sender: TObject);
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
if not GetXMLFile(ExtractFilepath(Paramstr(0))+'get.xml') then
  begin
  Log('Не могу получить файл');
  ShowMessage('Не могу получить файл');
  exit;
  end;
try
  DecodeDate(Now(), Year, Month, Day);
  XMLName:=ExtractFilepath(Paramstr(0))+'get-'+IntToStr(Year)+IntToStr(Month)+IntToStr(Day)+'.xml';
  FXMLStream := TFileStream.Create(XMLName, fmCreate);
  GetName:=ExtractFilepath(Paramstr(0))+'get.xml';
  FGetStream := TFileStream.Create(GetName, fmOpenRead);
  SetLength(S, FGetStream.Size);
  FGetStream.ReadBuffer(S[1], FGetStream.Size);
  S:=StringReplace(S, UnicodeString('</product>'),UnicodeString('</product>'+Char($0D)+Char($0A)),[rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, UnicodeString('&lt;'), UnicodeString('<'), [rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, UnicodeString('&gt;'), UnicodeString('>'), [rfReplaceAll, rfIgnoreCase]);
//  S:=StringReplace(S, '<![CDATA[', '', [rfReplaceAll, rfIgnoreCase]);
//  S:=StringReplace(S, ']]>', '', [rfReplaceAll, rfIgnoreCase]);
  FXMLStream.WriteBuffer(S[1], Length(S));
  finally
    FXMLStream.Free;
    FGetStream.Free;
  end;
//if FileExists(GetName) then begin DeleteFile(GetName); Sleep(1000);end;
Log('Создаём новые файлы для загрузки ');
end;

procedure TFormMain.ButtonCopyToDBClick(Sender: TObject);
var XMLName:string;
 Year, Month, Day: Word;
GotIt:boolean;
begin
DecodeDate(Now(), Year, Month, Day);
XMLName:=ExtractFilepath(Paramstr(0))+'get-'+IntToStr(Year)+IntToStr(Month)+IntToStr(Day)+'.xml';
if FileExists(XMLName)
  then
    begin
    Log('Обрабатываем '+XMLName);
    SaveXMLToDatabase(XMLName);
    end
  else
    begin
    Log('Скачиваю файл '+XMLName);
    GotIt:=GetXMLFile(ExtractFilepath(Paramstr(0))+'get.xml');
//    if GotIt then Log('Обрабатываем '+XMLName)
//    else Log('Невозможно скачать файл, отмена обработки '+XMLName);
    exit;
    end;
end;

procedure TFormMain.ClearParsedRec(var R: TParsedRec);
begin
R.sku:='';
R.ean:='';
R.description_pol:='';
R.name_pol:='';
R.color_pol:='';
R.size:='';
R.qty:='';
R.price:='';
R.assortment_pol:='';
R.product_type_pol:='';
R.manufacturer_pol:='';
R.category_pol:='';
R.image1:='';
R.image2:='';
end;

procedure TFormMain.ClearProductRec(var W: TProductRec);
begin
W.product_id:='';
W.model:='';
W.sku:='';
W.upc:='';
W.ean:='';
W.jan:='';
W.isbn:='';
W.mpn:='';
W.location:='';
W.quantity:='';
W.stock_status_id:='';
W.image:='';
W.manufacturer_id:='';
W.shipping:='';
W.price:='';
W.points:='';
W.tax_class_id:='';
W.date_available:='';
W.weight:='';
W.weight_class_id:='';
W.length:='';
W.width:='';
W.height:='';
W.length_class_id:='';
W.subtract:='';
W.minimum:='';
W.sort_order:='';
W.status:='';
W.viewed:='';
W.date_added:='';
W.date_modified:='';
W.import_batch:='';
W.manufacturer_pol:='';
W.manufacturer_ru:='';
W.seo_keyword:='';
W.link:='';
W.store:='';
W.name_ru:='';
W.fimage_ru:='';
W.video1_ru:='';
W.html_product_shortdesc_ru:='';
W.html_product_right_ru:='';
W.html_product_tab_ru:='';
W.tab_title_ru:='';
W.description_ru:='';
W.tag_ru:='';
W.meta_title_ru:='';
W.meta_description_ru:='';
W.meta_keyword_ru:='';
W.additional_images:='';
W.product_filter:='';
W.product_attribute:='';
W.product_option:='';
W.product_category:='';
W.product_discount:='';
W.product_special:='';
end;

procedure TFormMain.ConvertXMLToOpenCart(XMLName: string);
var OpenName:String;
 S:UnicodeString;
 FOpenText:TextFile;
 FXMLtext :TextFile;
 R:TParsedRec;
 P:TProductRec;
begin
OpenName:=StringReplace(XMLName, '.xml', '_oc.xml', [rfIgnoreCase]);
try
AssignFile(FOpenText, OpenName);
AssignFile(FXMLText, XMLName);
FileMode:=0;
Reset(FXMLText);
FileMode:=2;
Rewrite(FOpenText);
Writeln(FOpentext, '<?xml version="1.0"?> <itemlist> <title>XML Export - '+DateTimeToStr(Now, FS)+' </title>');
while not EOF(FXMLText) do
  begin
  Readln(FXMLText, S);
  S:=StringReplace(S, '<![CDATA[', '', [rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, ']]>', '', [rfReplaceAll, rfIgnoreCase]);
  MemoXML.Lines.Add(S);
  if Pos('xml version=', S) >0 then continue;
  if Pos('</products>', S) >0 then continue;
  if (Pos('<product>', S) >0) and (Pos('</product>', S)>0) then
    begin
    ClearParsedRec(R);
    ParseLine(R, S);
    ClearProductRec(P);
    CopyRecords(R, P);
    Writeln(FOpenText, SaveProduct(P));
    end;

  end;
Writeln(FOpentext, '</itemlist>');
finally
    CloseFile(FXMLtext);
    CloseFile(FOpenText);
  end;
end;

procedure TFormMain.CopyRecords(R: TParsedRec; var P: TProductRec);
var quantity:real;
begin
P.sku:=R.sku;
P.ean:=R.ean;
Quantity:=StrToFloatDef(R.qty, 0, FS);
if Quantity>0
then
  begin
  p.quantity:=R.qty;
  p.status := '1';
  end
else
  begin
  p.quantity:='0';
  p.status := '';
  end;
p.description_pol:=r.description_pol;
p.name_pol:=r.name_pol;
p.price:=r.price;
p.image:=r.image1;
p.additional_images:=r.image2;
p.date_available:=DateTimeToStr(Now, FS);
p.date_added:='';
p.date_modified:=DateTimeToStr(Now, FS);
p.manufacturer_pol:=r.manufacturer_pol;
p.manufacturer_id:=Replace_Manufacturer_ID(r.manufacturer_pol);
p.manufacturer_ru:=Replace_Manufacturer(r.manufacturer_pol);
p.product_filter:=''; //TODO: Закончить фильтр
p.product_attribute:=''; //TODO: Закончить атрибуты
p.product_option:=Replace_Color(r.color_pol)+':'+r.price+':'+'+'+r.qty+':0:+0.00000000:1';
p.product_category:=Replace_Category(r.category_pol);
// Исходный
//  sku, ean, description, name, color,
//  size, qty, price, assortment, product_type,
//  manufacturer, category, image1, image2:UnicodeString;
// Переписать опции в вид
// 	<product_option><![CDATA[select:Color:Black:+25.1000:4:1:+1.10000000:1|select:Color:Blue:+26.1000:3:1:+1.00000000:1|select:Color:Red:+28.1000:2:0:+1.20000000:1]]></product_option>
//  select:Color:Black:+25.1000:4:1:+1.10000000:1|
//  select:Color:Blue:+26.1000:3:1:+1.00000000:1|
//  select:Color:Red:+28.1000:2:0:+1.20000000:1
// Color Red: Price +28.100: Quantity 2: Stock 0: Weight 1.2 : Unknown 1

MemoProduct.Lines.Add('Запись скопирована: '+R.Name_pol);
end;

procedure TFormMain.SaveXMLToDatabase(XMLName: string);
var
 S:UnicodeString;
 FXMLtext :TextFile;
 R:TParsedRec;
 Err_cntr:integer;
begin
PB.Position:=0;
try
AssignFile(FXMLText, XMLName);
FileMode:=0;
Reset(FXMLText);
FileMode:=2;
while not EOF(FXMLText) do
  begin
  Readln(FXMLText, S);
  S:=StringReplace(S, '<![CDATA[', '', [rfReplaceAll, rfIgnoreCase]);
  S:=StringReplace(S, ']]>', '', [rfReplaceAll, rfIgnoreCase]);
  MemoXML.Lines.Add(S);
  if Pos('xml version=', S) >0 then continue;
  if Pos('</products>', S) >0 then continue;
  if (Pos('<product>', S) >0) and (Pos('</product>', S)>0) then
    begin
    ClearParsedRec(R);
    ParseLine(R, S);
    Err_Cntr:=0;
    if not SaveRecToDB(R) then
      begin
        inc(Err_cntr);
        if Err_Cntr<5 then Log('Ошибка записи №' +IntToStr(Err_Cntr)+' не могу записать в базу "'+R.name_pol+'"');
      end
      else Log('Запись в базу name="'+R.name_pol+'"');
    end;
  PB.StepIt;
  end;
finally
    CloseFile(FXMLtext);
  end;
PB.Position:=PB.Max;
end;

procedure TFormMain.FindTag(const S:UnicodeString; const Tag:UnicodeString;  var TagValue:UnicodeString);
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

procedure TFormMain.FormCreate(Sender: TObject);
var Ini:TINIFile;
I:integer;
Database, UserNAme, Host, Password, Port, DriverID:string;
begin
FS:=TFormatSettings.Create('en-US');
Ini:=TiniFile.Create(ExtractFilePath(paramstr(0))+'parameters.ini');
// SourceWebsite
SiteUsername:=Ini.ReadString('SourceWebsite','SiteUsername','admin');
SitePassword:=Ini.ReadString('SourceWebsite','SitePassword','skirawroclaw');
SiteAddress:=Ini.ReadString('SourceWebsite','SiteAddress','http://pro101.golddragon.info/data/get.xml');
Log('SiteUsername ='+SiteUserName);
Log('SitePassword='+SitePassword);
Log('SiteAddress ='+SiteAddress);
DriverID:=Ini.ReadString('MySQLDB','DriverID','MYSQL');
Host:=Ini.ReadString('MySQLDB','Host','localhost');
Database:=Ini.ReadString('MySQLDB','Database','');
Username:=Ini.ReadString('MySQLDB','UserName','');
Password:=Ini.ReadString('MySQLDB','Password','');
Port:=Ini.ReadString('MySQLDB','Port','3306');
Log('DriverID='+DriverID);
Log('Host='+Host);
Log('Database='+Database);
Log('Username='+UserName);
Log('Password='+Password);
Log('Port='+Port);
Ini.Free;
//FDCon.Params.Clear;
//FDCon.Params.Add('DriverID='+DriverID);
FDCon.Params.Add('Server='+Host);
FDCon.Params.Add('Database='+Database);
FDCon.Params.Add('User='+UserName);
FDCon.Params.Add('Password='+Password);
FDCon.Params.Add('Port='+Port);
FDCon.Open;
end;

function TFormMain.GetXMLFile(FileName: string): boolean;
var  FGetStream:TFileStream;
begin
FGetStream := TFileStream.Create(FileName, fmCreate);
isFileTransferred:=false;
try
Log('Подключаемся....');
idHTTP.Request.BasicAuthentication:=true;
idHTTP.Request.Username:=SiteUserName;
idHTTP.Request.Password:=SitePassword;
IdHTTP.Get(SiteAddress, FGetStream);
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

procedure TFormMain.IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
 PB.Position := AWorkCount;
end;

procedure TFormMain.IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
PB.Position := 0;
PB.Max := AWorkcountMax;
end;

procedure TFormMain.IdHTTPWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
isFileTransferred:=true;
end;

procedure TFormMain.Log(Msg: string);
begin
MemoLog.Lines.Add(Msg);
end;

procedure TFormMain.ParseLine(var R: TParsedRec; const S: UnicodeString);
var Str, LastRpl:UnicodeString;
begin
Str:=ReplaceHTMLSymbols(S);
Str:=StringReplace(Str,UnicodeString('<products>'), '',[rfReplaceAll, rfIgnoreCase]);
Str:=StringReplace(Str,UnicodeString('</products>'), '',[rfReplaceAll, rfIgnoreCase]);
FindTag(Str, 'sku', r.sku);
FindTag(Str, 'ean', r.ean);
FindTag(Str, 'description', r.description_pol);
FindTag(Str, 'name', r.name_pol);
FindTag(Str, 'color', r.color_pol);
FindTag(Str, 'size', r.size);
FindTag(Str, 'qty', r.qty);
FindTag(Str, 'price', r.price);
FindTag(Str, 'assortment', r.assortment_pol);
FindTag(Str, 'type', r.product_type_pol);
FindTag(Str, 'manufacturer', r.manufacturer_pol);
FindTag(Str, 'category', r.category_pol);
FindTag(Str, 'image1', r.image1);
FindTag(Str, 'image2', r.image2);
if PosR2L(r.color_pol,r.name_pol)>0
  then r.name_pol:=trim(Copy(r.name_pol, 1, PosR2L(r.color_pol,r.name_pol)-1));
if PosR2L(r.size,r.name_pol)>0
  then r.name_pol:=trim(Copy(r.name_pol, 1, PosR2L(r.size,r.name_pol)-1));
end;

function TFormMain.PosR2L(const FindS, SrcS: UnicodeString): Integer;
{Функция возвращает начало последнего вхождения
 подстроки FindS в строку SrcS, т.е. первое с конца.
 Если возвращает ноль, то подстрока не найдена.
 Можно использовать в текстовых редакторах
 при поиске текста вверх от курсора ввода.}

  function InvertS(const S: UnicodeString): UnicodeString;
    {Инверсия строки S}
  var
    i, Len: Integer;
  begin
    Len := Length(S);
    SetLength(Result, Len);
    for i := 1 to Len do
      Result[i] := S[Len - i + 1];
  end;

var
  ps: Integer;
begin
  {Например: нужно найти последнее вхождение
   строки 'ро' в строке 'пирожок в коробке'.
   Инвертируем обе строки и получаем
     'ор' и 'екборок в кожорип',
   а затем ищем первое вхождение с помощью стандартной
   функции Pos(Substr, S: string): string;
   Если подстрока Substr есть в строке S, то
   эта функция возвращает позицию первого вхождения,
   а иначе возвращает ноль.}
  ps := Pos(InvertS(FindS), InvertS(SrcS));
  {Если подстрока найдена определяем её истинное положение
   в строке, иначе возвращаем ноль}
  if ps <> 0 then
    Result := Length(SrcS) - Length(FindS) - ps + 2
  else
    Result := 0;
end;

function TFormMain.ReplaceHTMLSymbols(const S: UnicodeString):UnicodeString;
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

function TFormMain.Replace_Category(CatName: UnicodeString): UnicodeString;
begin
// TODO: Преарвтить категории
//<category>Gorteks,Bielizna,Bielizna damska,Biustonosze</category>
// В значения
// Аксессуары>Вставки|Аксессуары>Оболочки
// Согласно файлу category.xml или его аналогу category.csv
// Например
// <category>Gorteks,Bielizna,Bielizna damska,Biustonosze</category>
// раскладывается в
// Нижнее бельё>Дамское бельё>Бесшовное бельё    короткое поле Бесшовное бельё
// Находим в коротком пути и выставляем длинный путь
Result:='';
end;

function TFormMain.replace_Color(ColorName: UnicodeString): UnicodeString;
begin
// TODO: Перевести цвет с польского и поставить его на русском
// Проверить чтобы он был указан в options на сайте
Result:='Black';
end;

function TFormMain.Replace_Manufacturer(Name: UnicodeString): UnicodeString;
begin
// todo: Заменить Название производителя на польском языке на цифровой номер из русской таблицы
// соответствие ищем в manufacturer.xml
Result:='Canon';

end;

function TFormMain.Replace_Manufacturer_ID(Name: UnicodeString): UnicodeString;
begin
// todo: Заменить Название производителя на польском языке на цифровой номер из русской таблицы
// соответствие ищем в manufacturer.xml
Result:='9';
end;

function TFormMain.SaveRecToDB(P: TParsedRec): boolean;
begin
Try
with SP_Save_Product do
  begin
  Params[0].AsString:=P.name_pol;
  Params[1].AsString:=P.sku;
  Params[2].AsString:=P.ean;
  Params[3].AsString:=P.description_pol;
  Params[4].AsString:=P.Assortment_pol;
  Params[5].AsString:=p.product_type_pol;
  Params[6].AsString:=P.manufacturer_pol;
  Params[7].AsString:=P.category_pol;
  Params[8].AsString:=p.color_pol;
  Params[9].AsString:=P.Size;
  Params[10].AsString:=P.qty;
  Params[11].AsString:=P.price;
  Params[12].AsString:=P.image1;
  Params[13].AsString:=P.image2;
  end;
//FDConn.StartTransaction;
  //ParamCheck:=true;
  //Prepare;
SP_Save_product.Execute;
Result:=true;
except on E:Exception do Result:=false;
end;
end;

function TFormMain.SaveProduct(P: TProductRec):UnicodeString;
var S:UnicodeString;
 rttiContext : TRttiContext;
 fld, fld2 : TRttiField;
begin

S:='<item> '+CRLF;

for fld in rttiContext.GetType(TypeInfo(TProductRec)).GetFields do
    begin
    fld2 := rttiContext.GetType(TypeInfo(TProductRec)).GetField(fld.Name);
    S:=S+SaveTag(fld.Name,fld2.GetValue(@P).AsString);
    end;
S:=S+'</item>';
MemoProduct.Lines.Add(S);
Result:=S;
end;

function TFormMain.SaveTag(TagName, TagValue: UnicodeString): UnicodeString;
begin
if TagName='' then begin Result:=''; exit;end;
if TagValue<>''
  then Result:= chr($09)+'<'+TagName+'><![CDATA['+TagValue+']]></'+TagName+'>'+CRLF
  else Result:=chr($09)+'</'+TagName+'>'+CRLF;
end;

end.
