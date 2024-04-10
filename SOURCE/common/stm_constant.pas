unit stm_constant;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_container, pb_options,
  pb_package, pb_item;

type

  TsmConstantStatement = class(TsmContextStatement)
  private
    FValue: TsmProtoConstantValue;
    function StrToFloatA(V: string): double;
  public
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property Value: TsmProtoConstantValue read FValue;
  end;

implementation

uses errors;

{ TsmConstantStatement }

procedure TsmConstantStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer);
begin

  // constant = fullIdent | ( [ "-" | "+" ] intLit ) | ( [ "-" | "+" ] floatLit ) | strLit | boolLit
  FValue.Token:= LexAnalyzer.GetToken^;

  case FValue.Token.TokenType of
    ttIdent, ttFullIdent, ttString: FValue.Value:= LexAnalyzer.GetToken^.Value;
    ttInteger: FValue.Value:= StrToInt(LexAnalyzer.GetToken^.Value);
    ttFloat:   FValue.Value:= StrToFloatA(LexAnalyzer.GetToken^.Value);
    ttBoolean: FValue.Value:= LowerCase(LexAnalyzer.GetToken^.Value) = 'true';
    else begin
      raise EsmParserError.Create(Format(RsErr_InvalidConstantValue,
        [LexAnalyzer.GetToken^.Value]));
    end;
  end;

  LexAnalyzer.Next;

end;

function TsmConstantStatement.StrToFloatA(V: string): double;
var
  SaveDecimalSeparator: Char;
begin

  SaveDecimalSeparator:= FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator:= '.';
    Result:= StrToFloat(V);
  finally
    FormatSettings.DecimalSeparator:= SaveDecimalSeparator;
  end;

end;

end.
