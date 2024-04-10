unit stm_ranges;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, parser, pb_item, lexanalz;

type

  TsmRange = record
    FirstValue: integer;
    LastValue: integer; // if 0 then Max
  end;

  TsmRangesStatement = class(TsmContextStatement)
  private
    FRanges: TList<TsmRange>;
    function GetRange(Index: Integer): TsmRange;
    function GetCount: integer;
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    property Count: integer read GetCount;
    property Ranges[Index: Integer]: TsmRange read GetRange;
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
  end;


implementation

uses errors;

{ TsmRangesStatement }

constructor TsmRangesStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FRanges:= TList<TsmRange>.Create;
end;

destructor TsmRangesStatement.Destroy;
begin
  FRanges.Free;
  inherited;
end;

function TsmRangesStatement.GetCount: integer;
begin
  Result:= FRanges.Count;
end;

function TsmRangesStatement.GetRange(Index: Integer): TsmRange;
begin
  Result:= FRanges[Index];
end;

procedure TsmRangesStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer);
var
  Range: TsmRange;
begin

  // ranges = range { "," range }
  // range =  intLit [ "to" ( intLit | "max" ) ]
  while True do begin

    if LexAnalyzer.GetToken^.TokenType <> ttInteger then begin
      raise EsmParserError.Create(Format(RsErr_ExpectIntegerValue,
        [LexAnalyzer.GetToken^.Value]));
    end;

    Range.FirstValue:= StrToInt(LexAnalyzer.GetToken^.Value);

    if LexAnalyzer.IsTokenIdent('to', 1) then begin

      LexAnalyzer.Next;
      LexAnalyzer.Next;

      if LexAnalyzer.IsTokenIdent('max')
      then begin
        Range.LastValue:= 0;
      end else
      if LexAnalyzer.GetToken^.TokenType = ttInteger then begin
        Range.LastValue:= StrToInt(LexAnalyzer.GetToken^.Value);
      end else begin
        raise EsmParserError.Create(Format(RsErr_ExpectIntegerValue,
          [LexAnalyzer.GetToken^.Value]));
      end;

    end else begin
      Range.LastValue:= Range.FirstValue;
    end;

    FRanges.Add(Range);
    LexAnalyzer.Next;

    case LexAnalyzer.GetToken^.TokenType of

      ttSemicolon:
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
          [';', LexAnalyzer.GetToken^.Value]));
      end;
    end;

  end;

end;

end.
