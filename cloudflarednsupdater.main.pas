unit cloudflarednsupdater.main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Menus, fpjson, jsonparser, opensslsockets, fphttpclient, IniFiles, RegExpr,
  DateUtils;

type

  { TMainForm }

  TMainForm = class(TForm)
    btnCheckDNSZone: TButton;
    btnCheckIP: TButton;
    btnSave: TButton;
    btnCheckZones: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    labelNext: TLabel;
    memoResult: TMemo;
    textAPIKey: TEdit;
    textAPIZoneID: TEdit;
    textAPIEmail: TEdit;
    textAPIDNSZoneID: TEdit;
    TimerUpdater: TTimer;
    TrayIcon1: TTrayIcon;

    procedure btnCheckDNSZoneClick(Sender: TObject);
    procedure btnCheckIPClick(Sender: TObject);
    procedure btnCheckZonesClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure TimerUpdaterTimer(Sender: TObject);
    procedure TrayIcon1Click(Sender: TObject);
  private
    FAPI_KEY, FAPI_EMAIL, FAPI_ZONE_ID, FAPI_DOMAIN_ID: String;

    function FormatJson(AJson: String): String;
    function GetExternalIPAddress: string;
    procedure LoadConfig();
    procedure Log(AMessage: String);
    procedure LogMemo(AMessage: String);
    function PerformGET(aURL: String): String;
    function PerformPUT(AURL: String; AJson: TJsonData): String;
    procedure SaveConfig(API_KEY, API_EMAIL, API_ZONE_ID,
      API_DOMAIN_ID: string);


  public
    procedure UpdateLabel;

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }
function TmainForm.FormatJson(AJson:String):String;
var
   Parser:TJSONParser;

begin
   Parser:=TJSONParser.Create(AJson);
   Result:=Parser.Parse.FormatJSON;
   Parser.free;
end;

function TMainForm.PerformGET(aURL:String):String;
var
  client: TFPHTTPClient;
  response: TStringStream;
begin
  Result:='';
  client := TFPHTTPClient.Create(nil);
  response := TStringStream.Create;
  try
    client.AddHeader('X-Auth-Key', FAPI_KEY);
    client.AddHeader('X-Auth-Email', FAPI_EMAIL);

    try
      client.Get(aurl, response);
      result:=response.DataString;
    except
      on E: Exception do
        WriteLn('Error: ', E.Message);
    end;
  finally
    response.Free;
    client.Free;
  end;
end;
function TMainForm.PerformPUT(AURL:String;AJson:TJsonData):String;
var
  client: TFPHTTPClient;
  response: TStringStream;
begin
  Result:='';
  client := TFPHTTPClient.Create(nil);
  response := TStringStream.Create;
  try
    client.AddHeader('X-Auth-Key', FAPI_KEY);
    client.AddHeader('X-Auth-Email', FAPI_EMAIL);
    try
      client.RequestBody:=TRawByteStringStream.Create(AJson.AsJSON);
      client.Put(aurl, response);
      result:=response.DataString;
    except
      on E: Exception do
        Log('Error: '+ E.Message);
    end;
  finally
    response.Free;
    client.Free;
  end;
end;
function TMainForm.GetExternalIPAddress: string;
var
  HTTPClient: TFPHTTPClient;
  IPRegex: TRegExpr;
  RawData: string;
begin
  Result:='';
  try
    HTTPClient := TFPHTTPClient.Create(nil);
    IPRegex := TRegExpr.Create;
    try
      RawData := HTTPClient.Get('http://checkip.dyndns.org');
      IPRegex.Expression := '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b';
      if IPRegex.Exec(RawData) then
        Result := IPRegex.Match[0]
      else
        Log( 'Error Got invalid results getting external IP address. Details:'
          + LineEnding + RawData);
    except
      on E: Exception do
      begin
        Log('Error retrieving external IP address: ' + E.Message);
      end;
    end;
  finally
    HTTPClient.Free;
    IPRegex.Free;
  end;
end;
procedure TMainForm.LogMemo(AMessage: String);
begin
  while memoResult.Lines.count >10 do memoResult.Lines.Delete(0);

  memoresult.lines.add(FormatDateTime('hh:nn:ss', Now) + ': ' + AMessage);
end;
procedure TMainForm.Log(AMessage: String);
var
 LogFile: TextFile;
 LogFileName,LMessage: String;
begin

 LogFileName := 'log.txt';

 try

   AssignFile(LogFile, LogFileName);
   if FileExists(LogFileName) then
     Append(LogFile)
   else
     Rewrite(LogFile);
   LMessage:=     FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ': ' + AMessage;
    LogMemo(LMessage);
   Writeln(LogFile,LMessage );
 finally

   CloseFile(LogFile);
 end;
end;

procedure TMainForm.LoadConfig();
var
  ConfigFile: TIniFile;
begin
  try
    ConfigFile := TIniFile.Create('config.ini');
    try
      FAPI_KEY := ConfigFile.ReadString('API', 'API_KEY', '');
      FAPI_EMAIL := ConfigFile.ReadString('API', 'API_EMAIL', '');
      FAPI_ZONE_ID := ConfigFile.ReadString('API', 'API_ZONE_ID', '');
      FAPI_DOMAIN_ID := ConfigFile.ReadString('API', 'API_DOMAIN_ID', '');
      textAPIKey.text:=FAPI_KEY;
      textAPIEmail.text:=FAPI_EMAIL;
      textAPIZoneID.text:=FAPI_ZONE_ID;
      textAPIDNSZoneID.text:=FAPI_DOMAIN_ID;
    finally
      ConfigFile.Free;
    end;
  except
    on E: Exception do
      Log('Error loading config: ' + E.Message);
  end;
end;

procedure TMainForm.SaveConfig(API_KEY, API_EMAIL, API_ZONE_ID, API_DOMAIN_ID: string);
var
  ConfigFile: TIniFile;
begin
  ConfigFile := TIniFile.Create('Config.ini');
  try
    ConfigFile.WriteString('API', 'API_KEY', API_KEY);
    ConfigFile.WriteString('API', 'API_EMAIL', API_EMAIL);
    ConfigFile.WriteString('API', 'API_ZONE_ID', API_ZONE_ID);
    ConfigFile.WriteString('API', 'API_DOMAIN_ID', API_DOMAIN_ID);
  finally
    ConfigFile.Free;
  end;
end;

procedure TMainForm.UpdateLabel;
begin
  labelnext.caption := 'Next update in ' + FormatDateTime(
    'yyyy-mm-dd hh:nn:ss', IncMinute(Now, 15))  ;
end;

procedure TMainForm.btnCheckZonesClick(Sender: TObject);
begin
  if not FileExists('Config.ini') then
  begin
       ShowMessage('Save API KEY and E-mail!');
       exit;
  end;
  LoadConfig();
  if (FAPI_KEY='') or (FAPI_EMAIL ='' ) then
  begin
    ShowMessage('Save API KEY and E-mail!');
    exit;
  end;
  memoResult.text:=FormatJson(PerformGET('https://api.cloudflare.com/client/v4/zones'));
end;

procedure TMainForm.btnCheckDNSZoneClick(Sender: TObject);
begin
    if not FileExists('Config.ini') then
  begin
       ShowMessage('Save API KEY, E-mail and Zone ID!');
       exit;
  end;
  LoadConfig();
  if (FAPI_KEY='') or (FAPI_EMAIL ='' ) or (FAPI_ZONE_ID='') then
  begin
    ShowMessage('Save API KEY, E-mail and Zone ID!');
    exit;
  end;
  memoResult.text:=FormatJson(PerformGET('https://api.cloudflare.com/client/v4/zones/'+FAPI_ZONE_ID+'/dns_records'));
end;

procedure TMainForm.btnCheckIPClick(Sender: TObject);
begin
  TimerUpdaterTimer(nil);
end;

procedure TMainForm.btnSaveClick(Sender: TObject);
begin
   SaveConfig(textAPIKey.text,textAPIEmail.text,textAPIZoneID.text,textAPIDNSZoneID.text);
   memoResult.clear;

   if (textAPIKey.text<>'' ) and  (textAPIEmail.text <>'') and (textAPIZoneID.text<>'') and (textAPIDNSZoneID.text<>'') then
   begin
     btnCheckIPClick(nil);
   end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin

  UpdateLabel;
  TrayIcon1.icon:=self.icon;
  TimerUpdaterTimer(nil);
end;

procedure TMainForm.FormWindowStateChange(Sender: TObject);
begin
if WindowState = wsMinimized then
  begin
    Self.Hide;
    TrayIcon1.Show;
  end;
end;

procedure TMainForm.TimerUpdaterTimer(Sender: TObject);
var
  Json,JsonPut: TJSONObject;
  Ip, CurrentCFip, UpdatedCFip: string;
  Success: Boolean;
  Errors: String;
  Parser:TJSONParser;
  strUrl:String;
  strJson:String  ;

begin
  TimerUpdater.Enabled := false;
  try
     if not FileExists('Config.ini') then
     begin
       ShowMessage('Please configure all fields!');
       labelNext.caption:='Unconfigured.';
       exit;

     end
     else
     begin
        LoadConfig();
        if (FAPI_KEY='' ) or (FAPI_EMAIL ='') or (FAPI_DOMAIN_ID='') or (FAPI_ZONE_ID='') then
        begin
          ShowMessage('Please configure all fields!');
          labelNext.caption:='Unconfigured.';

          exit;
        end;
     end;
  except
    on E: Exception do
    begin
       Log('Error in timer on loading config:' +e.Message);
       exit;
    end;
  end;

   try

     Ip := GetExternalIPAddress ;
     LogMemo('External IP:' + ip);
     if Ip='' then
     begin
       Log('Empty External Address');
       UpdateLabel;
       TimerUpdater.Enabled := true;
       exit;
     end;
     strurl:='https://api.cloudflare.com/client/v4/zones/'+ FAPI_ZONE_ID +'/dns_records/'+FAPI_DOMAIN_ID;
    strJson:= PerformGET(strurl);
    if strJson='' then exit;

    Parser:=TJSONParser.Create(strJson);
    Json := Parser.Parse as TJSONObject;

    CurrentCFip := json.FindPath('result').FindPath('content').AsString ;
    Success := json.FindPath('success').AsBoolean ;

    if Success and (CurrentCFip <> Ip) then
    begin
      LogMemo('Updating IP:' + ip);

      JsonPut := TJSONObject.Create;
      try
        JsonPut.Add('type', Json.FindPath('result').FindPath('type'));
        JsonPut.Add('name', Json.FindPath('result').FindPath('name'));
        JsonPut.Add('content', Ip);
        JsonPut.Add('ttl', Json.FindPath('result').FindPath('ttl'));
        JsonPut.Add('proxied', Json.FindPath('result').FindPath('proxied'));

        strJson := PerformPUT(strurl,jsonput);
        Parser:=TJSONParser.Create(strJson);
        Json := Parser.parse as TJSONObject;


        Success := Json.FindPath('success').AsBoolean;
        if Success then
          Log('IP Address changed to: '+ Json.FindPath('result').FindPath('content').AsString)
        else
        begin
          Errors := Json.FindPath('errors').AsString;
          Log('Error on puting new ip address. Errors: '+Errors);
        end;
      finally
        Json.Free;
        JsonPut.Free;
        Parser.Free;
      end;
    end
    else if not Success then
    begin
      Errors := Json.FindPath('errors').AsString;
      Log('Error on getting the actual information from dns record. Errors: '+Errors);
    end;
   except
     on E: Exception do
        Log('Error on timer:' +e.Message);
   end;
   UpdateLabel;
   labelnext.caption :=labelnext.caption + ' | Last time checked was ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
   TimerUpdater.Enabled := true;
end;

procedure TMainForm.TrayIcon1Click(Sender: TObject);
begin

  Self.WindowState:=wsNormal;
  Self.Show ;
  TrayIcon1.hide;
end;

end.

