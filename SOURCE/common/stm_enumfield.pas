unit stm_enumfield;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Classes, System.Generics.Collections,
  parser, lexanalz, pb_container, pb_enum, stm_option_pair,
  stm_option_list, pb_options, pb_package, pb_item;

type

  TsmEnumFieldStatement = class(TsmContextStatement)
  private
    FName: string;
    FValue: integer;
    FOptionListStatement: TsmOptionListStatement;
    function GetOptions: TsmProtoOptions;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property Name: string read FName;
    property Value: integer read FValue;
    property Options: TsmProtoOptions read GetOptions;
  end;

implementation

uses errors;

{ TsmEnumFieldStatement }

constructor TsmEnumFieldStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FOptionListStatement:= TsmOptionListStatement.Create(ParserA);
end;

destructor TsmEnumFieldStatement.Destroy;
begin
  FOptionListStatement.Free;
  inherited;
end;

function TsmEnumFieldStatement.GetOptions: TsmProtoOptions;
begin
  Result:= FOptionListStatement.Options;
end;

procedure TsmEnumFieldStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer);
begin

  FOptionListStatement.Options.Clear;

  // enumField = ident "=" [ "-" ] intLit [ "[" enumValueOption { ","  enumValueOption } "]" ]";"
  // enumValueOption = optionName "=" constant

  if (LexAnalyzer.GetToken^.TokenType = ttIdent)
    and (LexAnalyzer.GetToken(1)^.TokenType = ttEquals)
    and (LexAnalyzer.GetToken(2)^.TokenType = ttInteger)
  then begin

    FName:= LexAnalyzer.GetToken^.Value;
    LexAnalyzer.Next;
    LexAnalyzer.Next;

    FValue:= StrToInt(LexAnalyzer.GetToken^.Value);
    LexAnalyzer.Next;

    if LexAnalyzer.IsToken(ttOpenSquareBracket)
      then FOptionListStatement.Parse(Parent, LexAnalyzer);

    if Not LexAnalyzer.IsToken(ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

  end else begin
    raise EsmParserError.Create(Format(RsErr_ExpectFieldName,
      [LexAnalyzer.GetToken^.Value]));
  end;

end;

end.
