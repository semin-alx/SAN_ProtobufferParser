unit pb_utils;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.StrUtils, pb_base, pb_message;

type

  TsmFullIdentString = class(TObject)
  private
    FParts: array of string;
    FPartCount: integer;
    function CalcPoints(S: string): integer;
    procedure LoadParts(S: string);
  public
    constructor Create(S: string);
    function IsInclude(FullIdent: TsmFullIdentString): Boolean;
  end;


function BaseTypeToString(FieldType: TsmProtoBaseFieldType): string;
function FieldLabelToString(FieldLabel: TsmProtoFieldLabel): string;

// Например:
//   Value = 'aaa.bbb.ccc', тогда FirstPart = 'aaa.bbb', LastPart = 'ccc'
//   Value = 'aaa', тогда FirstPart = 'aaa', LastPart = ''
procedure ExtractLastPart(Value: string; var FirstPart, LastPart: string);

implementation

uses errors;

function BaseTypeToString(FieldType: TsmProtoBaseFieldType): string;
begin
  case FieldType of
    ftUndefined: Result:= 'ftUndefined';
    ftDouble:    Result:= 'ftDouble';
    ftFloat:     Result:= 'ftFloat';
    ftInt32:     Result:= 'ftInt32';
    ftInt64:     Result:= 'ftInt64';
    ftUint32:    Result:= 'ftUint32';
    ftUint64:    Result:= 'ftUint64';
    ftSint32:    Result:= 'ftSint32';
    ftSint64:    Result:= 'ftSint64';
    ftFixed32:   Result:= 'ftFixed32';
    ftFixed64:   Result:= 'ftFixed64';
    ftSfixed32:  Result:= 'ftSfixed32';
    ftSfixed64:  Result:= 'ftSfixed64';
    ftBoolean:   Result:= 'ftBoolean';
    ftString:    Result:= 'ftString';
    ftBytes:     Result:= 'ftBytes';
    ftMessage: Result:= 'ftMessage';
    ftEnum:    Result:= 'ftEnum';
    else begin
      raise EsmParserError.Create(RsErr_UnknownBaseFieldType);
    end;
  end;
end;

function FieldLabelToString(FieldLabel: TsmProtoFieldLabel): string;
begin
  case FieldLabel of
    flSingular: Result:= 'flSingular';
    flRequired: Result:= 'flRequired';
    flOptional: Result:= 'flOptional';
    flRepeated: Result:= 'flRepeated';
    else begin
      raise EsmParserError.Create(RsErr_UnknownFieldLabel);
    end;
  end;
end;

{ TsmFullIdentString }

function TsmFullIdentString.CalcPoints(S: string): integer;
var
  I: integer;
begin
  Result:= 0;
  for I := 1 to Length(S) do begin
    if S[I] = '.' then Inc(Result);
  end;
end;

constructor TsmFullIdentString.Create(S: string);
begin
  FPartCount:= CalcPoints(S) + 1;
  LoadParts(S);
end;

function TsmFullIdentString.IsInclude(FullIdent: TsmFullIdentString): Boolean;
var
  I: integer;
begin

  Result:= False;

  if FullIdent.FPartCount > FPartCount then begin
    exit;
  end;

  for I := 1 to FullIdent.FPartCount do begin
    //if FParts[I-1] <> FullIdent.FParts[I-1] then begin
    if UpperCase(FParts[I-1]) <> UpperCase(FullIdent.FParts[I-1]) then begin
      Exit;
    end;
  end;

  Result:= True;

end;

procedure TsmFullIdentString.LoadParts(S: string);
var
  PartIndex: integer;
  n1, n2: integer;
begin

  SetLength(FParts, FPartCount);

  n1:= 1;
  PartIndex:= FPartCount - 1;

  while PartIndex >= 0 do begin

    n2:= PosEx('.', S, n1);
    if n2 = 0 then begin
      n2:= Length(S);
      FParts[PartIndex]:= Copy(S, n1, n2-n1 + 1);
    end else begin
      FParts[PartIndex]:= Copy(S, n1, n2-n1);
    end;

    Dec(PartIndex);
    n1:= n2+1;

  end;

end;

procedure ExtractLastPart(Value: string; var FirstPart, LastPart: string);
var
  I: integer;
  LastDotPos: integer;
begin

  LastDotPos:= -1;

  for I := Length(Value) downto 1 do begin
    if Value[I] = '.' then begin
      LastDotPos:= I;
      break;
    end;
  end;

  if LastDotPos = -1 then begin
    FirstPart:= Value;
    LastPart:= '';
  end else begin
    FirstPart:= Copy(Value, 1, LastDotPos - 1);
    LastPart:= Copy(Value, LastDotPos  + 1, Length(Value) - LastDotPos);
  end;

end;

end.
