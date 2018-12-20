﻿unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.DateUtils, System.Variants,
  System.Classes,System.IOUtils, System.Rtti,
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
defaults = record
     UniSt : Unicodestring;
 end;

type
TParsedRec = record
  sku, ean, description, name, color,
  size, qty, price, assortment, product_type,
  manufacturer, category, image1, image2:UnicodeString;
end;
TProductRec = record
 product_id, model, sku, upc, ean, jan,
 isbn, mpn, location, quantity, stock_status_id,
 image, manufacturer, manufacturer_id, shipping, price, points,
 tax_class_id, date_available, weight, weight_class_id, length,
 width, height, length_class_id, subtract, minimum,
 sort_order, status, viewed, date_added, date_modified,
 import_batch, seo_keyword, link, store,
 name_ru, fimage_ru, video1_ru, html_product_shortdesc_ru, html_product_right_ru,
 html_product_tab_ru, tab_title_ru, description_ru, tag_ru,
 meta_title_ru, meta_description_ru, meta_keyword_ru, additional_images, product_filter,
 product_attribute, product_option, product_category, product_discount, product_special:UnicodeString;
end;
type
  TFormMain = class(TForm)
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
    MemoProduct: TMemo;
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
  procedure ParseLine(var R:TParsedRec; const S:UnicodeString);
  function SaveProduct(P:TProductRec):UnicodeString;
  procedure FindTag(const S:UnicodeString; const Tag:UnicodeString; var TagValue:UnicodeString);
  function SaveTag(TagName, TagValue:UnicodeString):UnicodeString;
  function ReplaceHTMLSymbols(const S:UnicodeString):Unicodestring;
  procedure ClearParsedRec(var R:TParsedRec);
  procedure ClearProductRec(var W:TProductRec);
  procedure CopyRecords(R:TParsedRec; var P:TProductRec);
  function Replace_Manufacture_ID(Name:UnicodeString):UnicodeString;
  function Replace_Manufacture(Name:UnicodeString):UnicodeString;
  function Replace_Category(CatName:UnicodeString):UnicodeString;
  function Replace_Color(ColorName:UnicodeString):UnicodeString;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.BitBtn1Click(Sender: TObject);
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
//  S:=StringReplace(S, '<![CDATA[', '', [rfReplaceAll, rfIgnoreCase]);
//  S:=StringReplace(S, ']]>', '', [rfReplaceAll, rfIgnoreCase]);
  FXMLStream.WriteBuffer(S[1], Length(S));
  finally
    FXMLStream.Free;
    FGetStream.Free;
  end;
if FileExists(GetName) then begin DeleteFile(GetName); Sleep(1000);end;
Log('Создаём новые файлы для загрузки ');
end;

procedure TFormMain.Button1Click(Sender: TObject);
var
//  Connection: TSQLConnection;
  rttiContext : TRttiContext;
  fld, fld2 : TRttiField;
  i:integer;
  S:UnicodeString;
  P:TProductRec;
//  myRec: defaults;
  rttiType: TRttiType;
  fields: TArray<TRttiField>;
begin
// myRec.dims := 10;
  P.product_id := 'PRODUCT';
  P.Name_ru := 'JUST NAME';

  (*
  fld := rttiContext.GetType(TypeInfo(defaults)).GetField('dims');
  i := fld.GetValue(@myRec).AsInteger;
  fld.SetValue(@myRec, 42);
  *)

//  fld := rttiContext.GetType(TypeInfo(defaults)).GetField('st');
//  S := fld.GetValue(@myRec).AsString;
//  ShowMessage(S);
//  fld.SetValue(@myRec, '42');

//ClearParsedRec(R);
//R.name:='Name';
for fld in rttiContext.GetType(TypeInfo(TProductRec)).GetFields do
    begin
    fld2 := rttiContext.GetType(TypeInfo(TProductRec)).GetField(fld.Name);
    S := fld2.GetValue(@P).AsString;
    //fld2.SetValue(@myrec, 42);
    MemoLog.Lines.Add('Field '+fld.Name+' = "'+S+'"');
    end;


// https://www.justsoftwaresolutions.co.uk/delphi/dbexpress_and_mysql_5.html
//  Connection := TSQLConnection.Create(nil);
//  Connection.DriverName := 'dbxmysql';
//  Connection.GetDriverFunc := 'getSQLDriverMYSQL50';
//  Connection.LibraryName := 'dbxopenmysql50.dll';
//  Connection.VendorLib := 'libmysql.dll';
//  Connection.Params.Append('Database=NAME_OF_DATABASE');
//  Connection.Params.Append('User_Name=NAME_OF_USER');
//  Connection.Params.Append('Password=PASSWORD');
//  Connection.Params.Append('HostName=localhost');
//  Connection.Open;
//  Connection.Free;
end;

procedure TFormMain.ClearParsedRec(var R: TParsedRec);
begin
R.sku:='';
R.ean:='';
R.description:='';
R.name:='';
R.color:='';
R.size:='';
R.qty:='';
R.price:='';
R.assortment:='';
R.product_type:='';
R.manufacturer:='';
R.category:='';
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
W.manufacturer:='';
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
FS:TFormatSettings;
begin
P.sku:=R.sku;
P.ean:=R.ean;
FS:=TFormatSettings.Create('en-US');
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
p.description_ru:=r.description;
p.name_ru:=r.name;
p.price:=r.price;
p.image:=r.image1;
p.additional_images:=r.image2;
p.date_available:=DateTimeToStr(Now, FS);
p.date_added:='';
p.date_modified:=DateTimeToStr(Now, FS);
p.manufacturer_id:=Replace_Manufacture_ID(r.manufacturer);
p.manufacturer:=Replace_Manufacture(r.manufacturer);
p.product_filter:=''; //TODO: Закончить фильтр
p.product_attribute:=''; //TODO: Закончить атрибуты
p.product_option:=Replace_Color(r.color)+':'+r.price+':'+'+'+r.qty+':0:+0.00000000:1';
p.product_category:=Replace_Category(r.category);
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

MemoProduct.Lines.Add('Запись скопирована: '+R.Name);
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

function TFormMain.GetXMLFile(FileName: string): boolean;
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

procedure TFormMain.IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCount: Int64);
begin
 ProgressBar1.Position := AWorkCount;
end;

procedure TFormMain.IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode;
  AWorkCountMax: Int64);
begin
ProgressBar1.Position := 0;
ProgressBar1.Max := AWorkcountMax;
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
var Str:UnicodeString;
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

function TFormMain.Replace_Manufacture(Name: UnicodeString): UnicodeString;
begin
// todo: Заменить Название производителя на польском языке на цифровой номер из русской таблицы
// соответствие ищем в manufacturer.xml
Result:='Canon';

end;

function TFormMain.Replace_Manufacture_ID(Name: UnicodeString): UnicodeString;
begin
// todo: Заменить Название производителя на польском языке на цифровой номер из русской таблицы
// соответствие ищем в manufacturer.xml
Result:='9';
end;

function TFormMain.SaveProduct(P: TProductRec):UnicodeString;
var S:UnicodeString;
 FS:TFormatSettings;
 rttiContext : TRttiContext;
 fld, fld2 : TRttiField;
begin
FS:=TFormatSettings.Create('en-US');
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
