unit stm_option_list;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, pb_options, lexanalz, stm_option_pair,
  pb_package, pb_item;

type

  TsmOptionListStatement = class(TsmContextStatement)
  private
    FOptions: TsmProtoOptions;
    FOptionPairStm: TsmOptionPairStatement;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property Options: TsmProtoOptions read FOptions;
  end;

implementation

uses errors;

{ TsmOptionListStatement }

constructor TsmOptionListStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FOptions:= TsmProtoOptions.Create(nil);
  FOptionPairStm:= TsmOptionPairStatement.Create(ParserA);
end;

destructor TsmOptionListStatement.Destroy;
begin
  FOptions.Free;
  FOptionPairStm.Free;
  inherited;
end;

procedure TsmOptionListStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer);
begin

  FOptions.Clear;

  // [ "[" enumValueOption { ","  enumValueOption } "]" ]";"
  // enumValueOption = optionName "=" constant
  if not LexAnalyzer.IsToken(ttOpenSquareBracket) then begin
    raise EsmParserError.Create(Format(RsErr_ExpectChar,
      ['[', LexAnalyzer.GetToken^.Value]));
  end;

  LexAnalyzer.Next;

  while True do begin

    FOptionPairStm.Parse(nil, LexAnalyzer);

    FOptions.Add(FOptionPairStm.Name, FOptionPairStm.ConstantValue);

    case LexAnalyzer.GetToken^.TokenType of

      ttCloseSquareBracket:
      begin
        LexAnalyzer.Next;
        break;
      end;

      ttComma:
      begin
        LexAnalyzer.Next;
        continue;
      end;

      else begin
        raise EsmParserError.Create(Format(RsErr_ExpectChar,
          [']', LexAnalyzer.GetToken^.Value]));
      end;

    end;

  end;

end;

end.
