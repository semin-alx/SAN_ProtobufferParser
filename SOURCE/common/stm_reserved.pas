unit stm_reserved;

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
  parser, lexanalz, stm_ranges, pb_container, pb_enum, pb_package, pb_item;

type

  TsmReservedType = (rtRanges, rtFieldNames);

  TsmReservedStatement = class(TsmSlaveStatement)
  private
    FFieldNames: TStrings;
    FValueType: TsmReservedType;
    FStmRanges: TsmRangesStatement;
    function GetCount: integer;
    function GetFieldName(Index: Integer): string;
    function GetRange(Index: Integer): TsmRange;
    procedure ParseFieldNames(LexAnalyzer: TsmLexicalAnalyzer);
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
    property ValueType: TsmReservedType read FValueType;
    property Count: integer read GetCount;
    property Ranges[Index: Integer]: TsmRange read GetRange;
    property FieldNames[Index: Integer]: string read GetFieldName;
  end;

implementation

uses errors;

{ TsmReservedStatement }

constructor TsmReservedStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FFieldNames:= TStringList.Create;
  FStmRanges:= TsmRangesStatement.Create(Parser);
end;

destructor TsmReservedStatement.Destroy;
begin
  FStmRanges.Free;
  FFieldNames.Free;
  inherited;
end;

function TsmReservedStatement.GetCount: integer;
begin
  case FValueType of
    rtRanges:     Result:= FStmRanges.Count;
    rtFieldNames: Result:= FFieldNames.Count;
    else
      Result:= 0;
  end;
end;

function TsmReservedStatement.GetFieldName(Index: Integer): string;
begin
  Result:= FFieldNames[Index];
end;

function TsmReservedStatement.GetRange(Index: Integer): TsmRange;
begin
  Result:= FStmRanges.Ranges[Index];
end;

function TsmReservedStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  // reserved = "reserved" ( ranges | strFieldNames ) ";"
  // ranges = range { "," range }
  // range =  intLit [ "to" ( intLit | "max" ) ]
  // strFieldNames = strFieldName { "," strFieldName }
  // strFieldName = "'" fieldName "'" | '"' fieldName '"'

  Result:= False;

  if LexAnalyzer.IsTokenIdent('reserved') then begin

    LexAnalyzer.Next;

    if LexAnalyzer.GetToken^.TokenType = ttString then begin
      FValueType:= rtFieldNames;
      ParseFieldNames(LexAnalyzer);
    end else begin
      FValueType:= rtRanges;
      FStmRanges.Parse(Parent, LexAnalyzer);
    end;

    Result:= True;
  end;

end;

procedure TsmReservedStatement.ParseFieldNames(LexAnalyzer: TsmLexicalAnalyzer);
begin

  while True do begin

    if LexAnalyzer.GetToken^.TokenType <> ttString then begin
      raise EsmParserError.Create(Format(RsErr_ExpectFieldName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    FFieldNames.Add(LexAnalyzer.GetToken^.Value);
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
        Continue;
      end;

      else begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
      end;

    end;

  end;

end;

end.
