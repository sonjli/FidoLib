(*
 * Copyright 2022 Mirko Bianco (email: writetomirko@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *)

unit Fido.DesignPatterns.Adapter.TBrookHTTPResponseAsIHTTPResponse;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Defaults,

  Spring,
  Spring.Collections,

  BrookHTTPRequest,
  BrookHTTPResponse,
  BrookStringMap,

  Fido.Utilities,
  Fido.Http.Types,
  Fido.Http.Utils,
  Fido.Http.Response.Intf,
  IOUtils,
  BrookMediaTypes,
  BrookHTTPCookies,
  BrookUtility, System.DateUtils, System.StrUtils;

type
  TBrookHTTPResponseAsIHTTPResponseDecorator = class(TInterfacedObject, IHttpResponse)
  private
    FResponse: TBrookHTTPResponse;
    FMimeType: TMimeType;
    FBodyStream: TStringStream;
    FOwnStream: Boolean;
    FHeaders: IDictionary<string, string>;
    FRequest: TBrookHTTPRequest;
    FMIME: TBrookMIME;
    FCookies: IDictionary<string, string>;
    FRedirectActive: Boolean;
    FRedirectPath: string;

    procedure BrookMapToDictionary(const Map: TBrookStringMap; const Dictionary: IDictionary<string, string>);
    procedure Send(const AValue, AContentType: string; AStatus: Word);
  public
    constructor Create(const Response: TBrookHTTPResponse; const Request: TBrookHTTPRequest; const MimeType: TMimeType); reintroduce;
    destructor Destroy; override;

    procedure SetResponseCode(const ResponseCode: Integer; const ResponseText: string = '');
    function Body: string;
    procedure SetBody(const Body: string);
    procedure SetStream(const Stream: TStream);
    function HeaderParams: IDictionary<string, string>;
    function CookieParams: IDictionary<string, string>;
    function MimeType: TMimeType;
    procedure SetMimeType(const MimeType: TMimeType);
    procedure SetRedirect(const Active: Boolean);
    procedure SetRedirectPath(const PathToRedirect: string);
  end;

implementation

{ TBrookHTTPResponseAsIHTTPResponseDecorator }

function TBrookHTTPResponseAsIHTTPResponseDecorator.Body: string;
begin
  FBodyStream.ReadData<string>(Result, FBodyStream.Size);
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.BrookMapToDictionary(
  const Map: TBrookStringMap;
  const Dictionary: IDictionary<string, string>);
var
  _Key: string;
  _Value: string;
begin
  with Map.GetEnumerator do
    try
      while MoveNext do
      begin
        _Key := GetCurrent.Name;
        _Value := GetCurrent.Value;
        Dictionary[GetCurrent.Name] := GetCurrent.Value;
      end;
    finally
      Free;
    end;
end;

function TBrookHTTPResponseAsIHTTPResponseDecorator.CookieParams: IDictionary<string, string>;
begin
  Result := FCookies;
end;

constructor TBrookHTTPResponseAsIHTTPResponseDecorator.Create(
  const Response: TBrookHTTPResponse;
  const Request: TBrookHTTPRequest;
  const MimeType: TMimeType);
begin
  inherited Create;

  FResponse := Utilities.CheckNotNullAndSet<TBrookHTTPResponse>(Response, 'Response');
  FRequest := Utilities.CheckNotNullAndSet<TBrookHTTPRequest>(Request, 'Request');
  FMimeType := MimeType;
  FBodyStream := TStringStream.Create('');
  FOwnStream := True;
  FHeaders := TCollections.CreateDictionary<string, string>(TIStringComparer.Ordinal);
  FCookies := TCollections.CreateDictionary<string, string>(TIStringComparer.Ordinal);

  FRedirectActive := False;
  FRedirectPath := '';

  FMIME := TBrookMIME.Create(nil);
  FMIME.FileName := './mime.types';
  if FMimeType = mtHtml then
    FMIME.Open;

  BrookMapToDictionary(FResponse.Headers, FHeaders);
end;

destructor TBrookHTTPResponseAsIHTTPResponseDecorator.Destroy;
begin
  FMIME.Free;
  if FOwnStream then
    FBodyStream.Free;
  inherited;
end;

function TBrookHTTPResponseAsIHTTPResponseDecorator.HeaderParams: IDictionary<string, string>;
begin
  Result := FHeaders;
end;

function TBrookHTTPResponseAsIHTTPResponseDecorator.MimeType: TMimeType;
begin
  Result := FMimeType;
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.Send(const AValue, AContentType: string; AStatus: Word);
begin
  if FRedirectActive then
    FResponse.SendAndRedirect(AValue, FRedirectPath, AContentType, 301)
  else
    FResponse.Send(AValue, AContentType, AStatus);
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetBody(const Body: string);
begin
  FBodyStream.Position := 0;
  FBodyStream.SetSize(Longint(0));
  FBodyStream.WriteString(Body);
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetMimeType(const MimeType: TMimeType);
begin
  FMimeType := MimeType;
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetRedirect(const Active: Boolean);
begin
  FRedirectActive := Active;
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetRedirectPath(const PathToRedirect: string);
begin
  FRedirectPath := PathToRedirect;
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetResponseCode(const ResponseCode: Integer; const ResponseText: string);
var
  FileName: string;
  FileStream: TFileStream;
  MediaType: string;
  RelativePath: string;
  CookieParams: IShared<TStringList>;
  ExpiresValue: TDateTime;
  MaxAgeValue: Integer;
begin
  FHeaders.ForEach(procedure(const Item: TPair<string, string>)
    begin
      FResponse.Headers.AddOrSet(Item.Key, Item.Value);
    end);

  CookieParams := Shared.Make(TStringList.Create);
  CookieParams.CaseSensitive := False;
  FCookies
  .Where(function(const Item: TPair<string, string>): Boolean
   begin
     result := FResponse.Cookies.IndexOf(Item.Key) < 0;
   end
  )
  .ForEach(procedure(const Item: TPair<string, string>)
    begin
      CookieParams.Clear;
      CookieParams.AddStrings(Item.Value.Split([';']));
      for var i := 0 to CookieParams.Count - 1 do
        CookieParams[i] := CookieParams[i].Trim;

      with FResponse.Cookies.Add do
      begin
        Name := Item.Key;
        Value := '';
        if (CookieParams.Count >= 1) then
          Value := CookieParams[0];
        Path := Utilities.IfThen<string>(CookieParams.IndexOfName('PATH') >= 0, CookieParams.Values['PATH'].Trim, '/');
        if CookieParams.IndexOfName('DOMAIN') >= 0 then
          Domain := CookieParams.Values['DOMAIN'].Trim;
        HttpOnly := CookieParams.IndexOf('HTTPONLY') >= 0;
        Secure := CookieParams.IndexOf('SECURE') >= 0;
        if (CookieParams.IndexOfName('EXPIRES') >= 0) and (TryISO8601ToDate(CookieParams.Values['EXPIRES'].Trim, ExpiresValue)) then
          Expires := ExpiresValue;
        if (CookieParams.IndexOfName('MAX-AGE') >= 0) and (TryStrToInt(CookieParams.Values['MAX-AGE'].Trim, MaxAgeValue)) then
          MaxAge := MaxAgeValue;
        if CookieParams.IndexOfName('SAMESITE') >= 0 then
          SameSite := TBrookHTTPCookieSameSite(IndexText(CookieParams.Values['MAX-AGE'].Trim.ToUpper, ['NONE', 'STRICT', 'LAX']))
        else
          SameSite := TBrookHTTPCookieSameSite.ssLax;
      end;
    end);

  if ResponseCode <> 200 then
  begin
    Send(FBodyStream.DataString, SMimeType[FMimeType], ResponseCode);
    Exit;
  end;

  if FMimeType = mtHtml then
  begin
    RelativePath := FRequest.Path;
    if TPath.IsRelativePath(RelativePath) then
      RelativePath := '.' + FRequest.Path;

    FileName := TPath.GetFullPath(TPath.Combine('./public', RelativePath));
    if TFile.Exists(FileName) then
    begin
      MediaType := FMIME.Types.Find(ExtractFileExt(FileName));
      FileStream := TFileStream.Create(FileName, fmShareDenyWrite);
      FResponse.Headers['content-type'] := MediaType;
      FResponse.SendStream(FileStream, 200);
    end
    else
    begin
      if FBodyStream.DataString.Trim.Equals('') and not FRedirectActive then
        Send(Format('{"error": "page %s not found"}', [FRequest.Path]), 'application/json', 404)
      else
        Send(FBodyStream.DataString, SMimeType[FMimeType], ResponseCode);
    end;
  end
  else
    Send(FBodyStream.DataString, SMimeType[FMimeType], ResponseCode);
end;

procedure TBrookHTTPResponseAsIHTTPResponseDecorator.SetStream(const Stream: TStream);
begin
  if FOwnStream then
    FBodyStream.Free;
  FOwnStream := False;
  FBodyStream.Position := 0;
  FBodyStream.SetSize(Longint(0));
  FBodyStream.LoadFromStream(Stream);
end;

end.

