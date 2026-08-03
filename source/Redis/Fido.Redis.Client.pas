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

unit Fido.Redis.Client;

interface

uses
  System.SysUtils,
  System.Variants,
  Generics.Collections,
  Spring,
  Redis.Values,
  Redis.Commons,
  Redis.Client,
  Fido.Utilities,
  Fido.Functional,
  Fido.Functional.Ifs,
  Fido.Redis.Client.Intf;

type
  TFidoRedisClient = class(TInterfacedObject, IFidoRedisClient)
  private
    type
      TSubscribeStruct = record
        Channel: string;
        aCallback: TProc<string, string>;
        aContinueOnTimeoutCallback: TRedisTimeoutCallback;
        aAfterSubscribe: TProc;
      end;
      TQueueStruct = record
        Source: string;
        Destination: string;
        Timeout: Integer;
      end;
      TExpireStruct = record
        Key: string;
        Value: string;
        ExpireMS: Integer;
      end;
      TEvalStruct = record
        Script: string;
        Keys: TArray<string>;
        Values: TArray<string>;
      end;
  private
    FRedisClient: IRedisClient;
    function HasRedisNullableValue(const Value: TRedisNullable<string>): Context<Boolean>;
    function ConvertRedisNullable(const Value: TRedisNullable<string>): Nullable<string>;
    function DoDEL(const Key: string): Integer;
    function DoGET(const Key: string): TRedisNullable<string>;
    function DoLPUSH(const Params: TArray<string>): Integer;
    function DoPUBLISH(const Params: TArray<string>): Integer;
    function DoRPOP(const Key: string): Nullable<string>;
    function DoSET(const Params: TArray<string>): Boolean;
    function DoLREM(const Params: TArray<string>): Integer;
    function DoBRPOPLPUSH(const Struct: TQueueStruct): Nullable<string>;
    function DoSMEMBERS(const Key: string): TArray<string>;
    function DoLRANGE(const Key: TArray<TValue>): TArray<string>;
    function DoSETNXPX(const Struct: TExpireStruct): Context<Boolean>;
    function DoPEXPIRE(const Params: TArray<string>): Boolean;
    function DoEXPIRE(const Params: TArray<string>): Boolean;
    function DoHGET(const Params: TArray<string>): TRedisNullable<string>;
    function DoHSET(const Params: TArray<string>): Integer;
    function DoEVAL(const EvalStruct: TEvalStruct): Integer;
    function DoSADD(const Params: TArray<string>): Integer;
    function DoSREM(const Params: TArray<string>): Integer;
  public
    constructor Create(const RedisClient: IRedisClient);

    function DEL(const Key: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function GET(const Key: string; const Timeout: Integer = MAXINT): Context<Nullable<string>>;
    function &SET(const Key: string; const Value: string; const Timeout: Integer = MAXINT): Context<Boolean>;
    function SETNXPX(
        const Key, Value: string;
        const ExpireMS: Integer = 5000;
        const Timeout: Integer = MAXINT
    ): Context<Boolean>;
    function PEXPIRE(const Key: string; const TTL: Integer; const Timeout: Integer = MAXINT): Context<Boolean>;
    function EXPIRE(const Key, Value: string; const TTL: Integer; const Timeout: Integer = MAXINT): Context<Boolean>; overload;
    function EXPIRE(const Key: string; const TTL: Integer; const Timeout: Integer = MAXINT): Context<Boolean>; overload;
    function RPOP(const Key: string; const Timeout: Integer = MAXINT): Context<Nullable<string>>;
    function LPUSH(const Key: string; const Value: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function LREM(const Key, Item: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function SMEMBERS(const Key: string; const Timeout: Integer = MAXINT): Context<TArray<string>>;
    function SADD(const Key, Item: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function SREM(const Key, Item: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function LRANGE(
        const Key: string;
        const Start: integer = 0;
        const Stop: Integer = -1;
        const Timeout: Integer = MAXINT
    ): Context<TArray<string>>;
    function PUBLISH(const Key: string; const Value: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function SUBSCRIBE(
        const Channel: string;
        aCallback: TProc<string, string>;
        aContinueOnTimeoutCallback: TRedisTimeoutCallback = nil;
        aAfterSubscribe: TProc = nil
    ): Context<Void>;
    function BRPOPLPUSH(const Source, Destination: string; const Timeout: Integer = MAXINT): Context<Nullable<string>>;
    function HGET(const Key, Field: string; const Timeout: Integer = MAXINT): Context<Nullable<string>>;
    function HSET(const Key, Field: string; const Value: string; const Timeout: Integer = MAXINT): Context<Integer>;
    function EVAL(
        const aScript: string;
        aKeys, aValues: TArray<string>;
        const Timeout: Integer = MAXINT
    ): Context<Integer>;
  end;

implementation

{ TFidoRedisClient }

constructor TFidoRedisClient.Create(const RedisClient: IRedisClient);
begin
  inherited Create;

  FRedisClient := Utilities.CheckNotNullAndSet(RedisClient, 'RedisClient');
end;

function TFidoRedisClient.DoBRPOPLPUSH(const Struct: TQueueStruct): Nullable<string>;
var
  Client: IRedisClient;
  Value: string;
  ResultValue: Nullable<string>;
begin
  Client := FRedisClient;
  Result := ResultValue;
  if FRedisClient.BRPOPLPUSH(Struct.Source, Struct.Destination, Value, Struct.Timeout) then
    Result := Value;
end;

function TFidoRedisClient.DoDEL(const Key: string): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.DEL([Key]);
end;

function TFidoRedisClient.DoEVAL(const EvalStruct: TEvalStruct): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  result := Client.EVAL(EvalStruct.Script, EvalStruct.Keys, EvalStruct.Values);
end;

function TFidoRedisClient.DoEXPIRE(const Params: TArray<string>): Boolean;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  if Length(Params) = 3 then
    Result := Client.&SET(Params[0], Params[1], Params[2].ToInteger)
  else
    Result := Client.EXPIRE(Params[0], Params[1].ToInteger);
end;

function TFidoRedisClient.DEL(const Key: string; const Timeout: Integer): Context<Integer>;
begin
  Result := Context<string>.New(Key).MapAsync<Integer>(DoDel, Timeout);
end;

function TFidoRedisClient.HasRedisNullableValue(const Value: TRedisNullable<string>): Context<Boolean>;
var
  LValue: TRedisNullable<string>;
begin
  LValue := Value;
  Result := function: Boolean begin Result := LValue.HasValue; end;
end;

function TFidoRedisClient.HGET(const Key, Field: string; const Timeout: Integer = MAXINT): Context<Nullable<string>>;
var
  NullValue: Nullable<string>;
begin
  Result :=
      &If<TRedisNullable<string>>
          .New(Context<TArray<string>>.New([Key, Field]).MapAsync<TRedisNullable<string>>(DoHGET, Timeout))
          .Map(HasRedisNullableValue)
          .&Then<Nullable<string>>(ConvertRedisNullable, NullValue);
end;

function TFidoRedisClient.HSET(
    const Key, Field: string;
    const Value: string;
    const Timeout: Integer = MAXINT
): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Field, Value]).MapAsync<Integer>(DoHSET, Timeout);
end;

function TFidoRedisClient.BRPOPLPUSH(
    const Source, Destination: string;
    const Timeout: Integer = MAXINT
): Context<Nullable<string>>;
var
  Struct: TQueueStruct;
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Struct.Source := Source;
  Struct.Destination := Destination;
  Struct.Timeout := Timeout;

  Result := Context<TQueueStruct>.New(Struct).MapAsync<Nullable<string>>(DoBRPOPLPUSH, Timeout);
end;

function TFidoRedisClient.ConvertRedisNullable(const Value: TRedisNullable<string>): Nullable<string>;
begin
  Result := Value.Value;
end;

function TFidoRedisClient.DoGET(const Key: string): TRedisNullable<string>;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.GET(Key);
end;

function TFidoRedisClient.DoHGET(const Params: TArray<string>): TRedisNullable<string>;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.HGET(Params[0], Params[1]);
end;

function TFidoRedisClient.DoHSET(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.HSET(Params[0], Params[1], Params[2]);
end;

function TFidoRedisClient.GET(const Key: string; const Timeout: Integer): Context<Nullable<string>>;
var
  NullValue: Nullable<string>;
begin
  Result :=
      &If<TRedisNullable<string>>
          .New(Context<string>.New(Key).MapAsync<TRedisNullable<string>>(DoGET, Timeout))
          .Map(HasRedisNullableValue)
          .&Then<Nullable<string>>(ConvertRedisNullable, NullValue);
end;

function TFidoRedisClient.DoLPUSH(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.LPUSH(Params[0], [Params[1]]);
end;

function TFidoRedisClient.DoLRANGE(const Key: TArray<TValue>): TArray<string>;
var
  Client: IRedisClient;
  ArrayResult: TRedisArray;
begin
  result := [];

  Client := FRedisClient;

  ArrayResult := Client.LRANGE(Key[0].AsString, Key[1].AsInteger, Key[2].AsInteger);

  if not ArrayResult.HasValue then
    Exit;

  result := Client.LRANGE(Key[0].AsString, Key[1].AsInteger, Key[2].AsInteger).ToArray;
end;

function TFidoRedisClient.DoLREM(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.LREM(Params[0], 1, Params[1]);
end;

function TFidoRedisClient.LPUSH(const Key: string; const Value: string; const Timeout: Integer): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Value]).MapAsync<Integer>(DoLPUSH, Timeout);
end;

function TFidoRedisClient.LRANGE(
    const Key: string;
    const Start: integer = 0;
    const Stop: Integer = -1;
    const Timeout: Integer = MAXINT
): Context<TArray<string>>;
begin
  Result :=
      Context<TArray<TValue>>
          .New([TValue.From<string>(Key), TValue.From<integer>(Start), TValue.From<integer>(Stop)])
          .MapAsync<TArray<string>>(DoLRANGE, Timeout);
end;

function TFidoRedisClient.LREM(const Key, Item: string; const Timeout: Integer = MAXINT): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Item]).MapAsync<Integer>(DoLREM, Timeout);
end;

function TFidoRedisClient.DoPEXPIRE(const Params: TArray<string>): Boolean;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.PEXPIRE(Params[0], Params[1].ToInteger);
end;

function TFidoRedisClient.DoPUBLISH(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.PUBLISH(Params[0], Params[1]);
end;

function TFidoRedisClient.PEXPIRE(const Key: string; const TTL, Timeout: Integer): Context<Boolean>;
begin
  Result := Context<TArray<string>>.New([Key, TTL.ToString]).MapAsync<Boolean>(DoPEXPIRE, Timeout);
end;

function TFidoRedisClient.PUBLISH(const Key: string; const Value: string; const Timeout: Integer): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Value]).MapAsync<Integer>(DoPUBLISH, Timeout);
end;

function TFidoRedisClient.DoRPOP(const Key: string): Nullable<string>;
var
  Value: string;
  ResultValue: Nullable<string>;
  Client: IRedisClient;
begin
  Client := FRedisClient;
  Result := ResultValue;
  if FRedisClient.RPOP(Key, Value) then
    Result := Value;
end;

function TFidoRedisClient.RPOP(const Key: string; const Timeout: Integer): Context<Nullable<string>>;
begin
  Result := Context<string>.New(Key).MapAsync<Nullable<string>>(DoRPOP, Timeout);
end;

function TFidoRedisClient.DoSADD(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.SADD(Params[0], Params[1]);
end;

function TFidoRedisClient.DoSET(const Params: TArray<string>): Boolean;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.&SET(Params[0], Params[1]);
end;

function TFidoRedisClient.DoSETNXPX(const Struct: TExpireStruct): Context<Boolean>;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.&SETNX(Struct.Key, Struct.Value, Struct.ExpireMS);
end;

function TFidoRedisClient.DoSMEMBERS(const Key: string): TArray<string>;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  result := [];

  if not Client.SMEMBERS(Key).HasValue then
    Exit;

  result := Client.SMEMBERS(Key).ToArray;
end;

function TFidoRedisClient.DoSREM(const Params: TArray<string>): Integer;
var
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Result := Client.SREM(Params[0], Params[1]);
end;

function TFidoRedisClient.EVAL(
    const aScript: string;
    aKeys, aValues: TArray<string>;
    const Timeout: Integer = MAXINT
): Context<Integer>;
var
  Struct: TEvalStruct;
begin
  Struct.Script := aScript;
  Struct.Keys := aKeys;
  Struct.Values := aValues;
  Result := Context<TEvalStruct>.New(Struct).MapAsync<Integer>(DoEVAL, Timeout);
end;

function TFidoRedisClient.EXPIRE(const Key: string; const TTL, Timeout: Integer): Context<Boolean>;
begin
  Result := Context<TArray<string>>.New([Key, TTL.ToString]).MapAsync<Boolean>(DoEXPIRE, Timeout);
end;

function TFidoRedisClient.EXPIRE(const Key, Value: string; const TTL, Timeout: Integer): Context<Boolean>;
begin
  Result := Context<TArray<string>>.New([Key, Value, TTL.ToString]).MapAsync<Boolean>(DoEXPIRE, Timeout);
end;

function TFidoRedisClient.SADD(const Key, Item: string; const Timeout: Integer): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Item]).MapAsync<Integer>(DoSADD, Timeout);
end;

function TFidoRedisClient.&SET(const Key: string; const Value: string; const Timeout: Integer): Context<Boolean>;
begin
  Result := Context<TArray<string>>.New([Key, Value]).MapAsync<Boolean>(DoSET, Timeout);
end;

function TFidoRedisClient.SETNXPX(
    const Key, Value: string;
    const ExpireMS: Integer = 5000;
    const Timeout: Integer = MAXINT
): Context<Boolean>;
var
  Struct: TExpireStruct;
begin
  Struct.Key := Key;
  Struct.Value := Value;
  Struct.ExpireMS := ExpireMS;
  Result := Context<TExpireStruct>.New(Struct).MapAsync<Boolean>(DoSETNXPX, Timeout);
end;

function TFidoRedisClient.SMEMBERS(const Key: string; const Timeout: Integer = MAXINT): Context<TArray<string>>;
begin
  Result := Context<string>.New(Key).MapAsync<TArray<string>>(DoSMEMBERS, Timeout);
end;

function TFidoRedisClient.SREM(const Key, Item: string; const Timeout: Integer): Context<Integer>;
begin
  Result := Context<TArray<string>>.New([Key, Item]).MapAsync<Integer>(DoSREM, Timeout);
end;

function TFidoRedisClient.SUBSCRIBE(
    const Channel: string;
    aCallback: TProc<string, string>;
    aContinueOnTimeoutCallback: TRedisTimeoutCallback;
    aAfterSubscribe: TProc
): Context<Void>;
var
  Struct: TSubscribeStruct;
  Client: IRedisClient;
begin
  Client := FRedisClient;

  Struct.Channel := Channel;
  Struct.aCallback := aCallback;
  Struct.aContinueOnTimeoutCallback := aContinueOnTimeoutCallback;
  Struct.aAfterSubscribe := aAfterSubscribe;

  Result :=
      Context<TSubscribeStruct>
          .New(Struct)
          .Map<Void>(
              Void.MapProc<TSubscribeStruct>(
                  procedure(const Struct: TSubscribeStruct)
                  begin
                    Client.SUBSCRIBE(
                        [Struct.Channel],
                        Struct.aCallback,
                        Struct.aContinueOnTimeoutCallback,
                        Struct.aAfterSubscribe
                    )
                  end
              ));
end;

end.
