unit stm_extantions;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, parser, pb_item, lexanalz,
  stm_ranges;

type
  TsmExtantionsStatement = class(TsmSlaveStatement)
  private
    FRangesStatement: TsmRangesStatement;
    function GetRange(Index: Integer): TsmRange;
    function GetCount: integer;
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    property Count: integer read GetCount;
    property Ranges[Index: Integer]: TsmRange read GetRange;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation



{ TsmExtantionsStatement }

constructor TsmExtantionsStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FRangesStatement:= TsmRangesStatement.Create(Parser);
end;

destructor TsmExtantionsStatement.Destroy;
begin
  FRangesStatement.Free;
  inherited;
end;

function TsmExtantionsStatement.GetCount: integer;
begin
  Result:= FRangesStatement.Count;
end;

function TsmExtantionsStatement.GetRange(Index: Integer): TsmRange;
begin
  Result:= FRangesStatement.Ranges[Index];
end;


function TsmExtantionsStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  Result:= False;

  if LexAnalyzer.IsTokenIdent('extensions') then begin
    LexAnalyzer.Next;
    FRangesStatement.Parse(Parent, LexAnalyzer);
    Result:= True;
  end;

end;

end.
