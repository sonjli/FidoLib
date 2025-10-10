(*
 * Copyright 2021 Mirko Bianco (email: writetomirko@gmail.com)
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

unit Fido.win.Db.StatementExecutor.ADO;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Variants,

  Data.DB,
  Data.Win.ADODB,

  Fido.Utilities,
  Fido.Win.Db.Connections.Ado,
  Fido.VirtualStatement.Intf,
  Fido.VirtualStatement.Attributes,
  Fido.StatementExecutor.Intf,
  Fido.StatementExecutor.Abstract,
  Classes;

type
  TADOStatementExecutor = class (TAbstractStatementExecutor, IStatementExecutor)
  private
    FAdoConnections: TAdoConnections;
    function GetParameters: TParameters;
  protected
    function BuildObjectInternal(const StatementType: TStatementType; const SQLData: string): TObject; override;
    function UpdateObjectInternal(const SQLData: string): TObject; override;
  public
    constructor Create(AdoConnections: TAdoConnections);
    function GetParameterValue(const ParamName: string): Variant; override;
    procedure AddParameter(const ParamName: string; const DataType: TFieldType; const ParamType: TParamType = ptInput); override;
    procedure SetParameterValue(const ParamName: string; const Value: Variant); override;
    procedure Prepare; override;
    procedure Execute; override;
  end;

implementation

{ TADOStatementExecutor }

procedure TADOStatementExecutor.AddParameter(
  const ParamName: string;
  const DataType: TFieldType;
  const ParamType: TParamType);
var
  P: TParameter;
const
  TypeToDirectionMap: array[TParamType] of TParameterDirection = (
    pdUnknown, pdInput, pdOutput, pdInputOutput,  pdReturnValue);
begin
  inherited;
  P := GetParameters.FindParam(ParamName);
  if not Assigned(P) then
  begin
    P := GetParameters.AddParameter;
    P.Name := ParamName;
  end;
  P.Direction := TypeToDirectionMap[ParamType];
  P.DataType := DataType;
  { Apparently Size is not really necessary for string parameters:
  if DataType in [ftWideString, ftString] then
    P.Size := 4000;}
end;

function TADOStatementExecutor.BuildObjectInternal(
  const StatementType: TStatementType;
  const SQLData: string): TObject;
begin
  Result := nil;
  try
    case StatementType of
      stSequence, stQuery, stFunction, stScalarQuery: // = stOpenable
        begin
          Result := TADODataSet.Create(nil);
          with TADODataSet(Result) do begin
            Connection := FAdoConnections.GetCurrent;
            LockType := ltReadOnly; // because all are readonly at the moment
            CommandText := SQLData;
          end;
        end;
      stStoredProc:
        begin
          Result := TADOStoredProc.Create(nil);
          TADOStoredProc(Result).ProcedureName := SQLData;
          TADOStoredProc(Result).Connection := FAdoConnections.GetCurrent;
        end;
      stCommand:
        begin
          Result := TADOCommand.Create(nil);
          with TADOCommand(Result) do begin
            Connection := FAdoConnections.GetCurrent;
            ParamCheck := true;  // CRITICAL!
            CommandText := SQLData;
          end;
        end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

constructor TADOStatementExecutor.Create(AdoConnections: TAdoConnections);
begin
  FAdoConnections := Utilities.CheckNotNullAndSet(AdoConnections, 'AdoConnections');
end;

procedure TADOStatementExecutor.Execute;
begin
  inherited;
  case StatementType of
    stStoredProc:
      TADOStoredProc(Statement).ExecProc;
    stCommand:
      TADOCommand(Statement).Execute(FRowsAffected, EmptyParam);
  end;
end;

function TADOStatementExecutor.GetParameters: TParameters;
begin
  Assert(Assigned(Statement));
  case StatementType of
    stStoredProc:
      Result := TADOStoredProc(Statement).Parameters;
    stCommand:
      Result := TADOCommand(Statement).Parameters;
    stQuery, stFunction, stScalarQuery:
      Result := TADODataSet(Statement).Parameters;
    else
      Result := nil;
  end;
end;

function TADOStatementExecutor.GetParameterValue(const ParamName: string): Variant;
begin
  inherited;
  Result := GetParameters.ParamByName(ParamName).Value;
end;

procedure TADOStatementExecutor.Prepare;
begin
  inherited;
  case StatementType of
    stStoredProc:
      TADOStoredProc(Statement).Prepared := true;
    stCommand:
      TADOCommand(Statement).Prepared := true;
    stQuery, stFunction, stSequence, stScalarQuery:
      TADODataSet(Statement).Prepared := true;
    else
      Assert(false, 'Unimplemented');
  end;
end;

procedure TADOStatementExecutor.SetParameterValue(
  const ParamName: string;
  const Value: Variant);
begin
  GetParameters.ParamByName(ParamName).Value := Value;
end;

function TADOStatementExecutor.UpdateObjectInternal(const SQLData: string): TObject;
var
  DummyEvent: TNotifyEvent;
begin
  Result := Statement;

  TADOQuery(Statement).Close;
  DummyEvent := TADOQuery(Statement).Connection.AfterDisconnect;
  TADOQuery(Statement).Connection.AfterDisconnect := nil;
  try
    TADOQuery(Statement).Connection.Connected := False;
    TADOQuery(Statement).Connection.Connected := True;
  finally
    TADOQuery(Statement).Connection.AfterDisconnect := DummyEvent;
  end;
  TADOQuery(Statement).Parameters.Clear;
  TADOQuery(Statement).SQL.Clear;
  TADOQuery(Statement).SQL.Text := SQLData;
end;

end.
