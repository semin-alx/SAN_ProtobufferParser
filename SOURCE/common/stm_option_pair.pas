unit stm_option_pair;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, parser, lexanalz,
  pb_container, pb_enum, stm_constant, pb_options, pb_package, pb_item;

type

  TsmOptionPairStatement = class(TsmContextStatement)
  private
    FName: string;
    FConstantStatement: TsmConstantStatement;
    procedure ParseOptionName(LexAnalyzer: TsmLexicalAnalyzer);
    function GetConstantValue: TsmProtoConstantValue;
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property Name: string read FName;
    property ConstantValue: TsmProtoConstantValue read GetConstantValue;
  end;


implementation

uses errors;

{ TsmOptionPairStatement }

constructor TsmOptionPairStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FConstantStatement:= TsmConstantStatement.Create(Parser);
end;

destructor TsmOptionPairStatement.Destroy;
begin
  FConstantStatement.Free;
  inherited;
end;

function TsmOptionPairStatement.GetConstantValue: TsmProtoConstantValue;
begin
  Result:= FConstantStatement.Value;
end;

procedure TsmOptionPairStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer);
begin

  // optionName  "=" constant ";"
  ParseOptionName(LexAnalyzer);

  if (LexAnalyzer.GetToken^.TokenType <> ttEquals) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['=', LexAnalyzer.GetToken^.Value]));
  end;

  LexAnalyzer.Next;

  FConstantStatement.Parse(Parent, LexAnalyzer);

end;

procedure TsmOptionPairStatement.ParseOptionName(
  LexAnalyzer: TsmLexicalAnalyzer);

  procedure AddName(Value: string);
  begin
    if FName <> '' then begin
      FName:= FName + '.' + Value;
    end else begin
      FName:= Value;
    end;
  end;

begin

  // optionName = ( ident | "(" fullIdent ")" ) { "." ident }

  FName:= '';

  while True do begin

    case LexAnalyzer.GetToken^.TokenType of

      ttIdent, ttFullIdent:
      begin
        AddName(LexAnalyzer.GetToken^.Value);
        LexAnalyzer.Next;
      end;

      ttOpenParenthesis:
      begin

        LexAnalyzer.Next;

        if (LexAnalyzer.GetToken^.TokenType = ttIdent)
          or (LexAnalyzer.GetToken^.TokenType = ttFullIdent)
        then begin
          AddName(LexAnalyzer.GetToken^.Value);
        end else begin
          raise EsmParserError.Create(Format(RsErr_ExpectOptionName,
            [LexAnalyzer.GetToken^.Value]));
        end;

        LexAnalyzer.Next;

        if (LexAnalyzer.GetToken^.TokenType <> ttCloseParenthesis) then begin
          raise EsmParserError.Create(Format(RsErr_ExpectChar,
            [')', LexAnalyzer.GetToken^.Value]));
        end;

        LexAnalyzer.Next;

      end;

      ttDot:
      begin
        LexAnalyzer.Next;
        if Not LexAnalyzer.IsToken(ttIdent) then begin
          raise EsmParserError.Create(Format(RsErr_ExpectOptionName,
            [LexAnalyzer.GetToken^.Value]));
        end;
      end;

      ttEquals:
      begin
        break;
      end;

      else begin
        if FName <> '' then begin
          raise EsmParserError.Create(Format(RsErr_ExpectChar,
            ['=', LexAnalyzer.GetToken^.Value]));
        end else begin
          raise EsmParserError.Create(Format(RsErr_ExpectOptionName,
            [LexAnalyzer.GetToken^.Value]));
        end;
      end;

    end;

  end;

end;

end.
