unit stm_option;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_container, pb_enum,
  stm_option_pair, stm_constant, pb_package, pb_options, pb_item;

type

  TsmOptionStatement = class(TsmSlaveStatement)
  private
    FOptionPairStatement: TsmOptionPairStatement;
    function GetName: string;
    function GetConstantValue: TsmProtoConstantValue;
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
    property Name: string read GetName;
    property ConstantValue: TsmProtoConstantValue read GetConstantValue;
  end;

implementation

uses errors;

{ TsmOptionStatement }

constructor TsmOptionStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FOptionPairStatement:= TsmOptionPairStatement.Create(Parser);
end;

destructor TsmOptionStatement.Destroy;
begin
  FOptionPairStatement.Free;
  inherited;
end;

function TsmOptionStatement.GetName: string;
begin
  Result:= FOptionPairStatement.Name;
end;

function TsmOptionStatement.GetConstantValue: TsmProtoConstantValue;
begin
  Result:= FOptionPairStatement.ConstantValue;
end;

function TsmOptionStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  Result:= False;

  if LexAnalyzer.IsTokenIdent('option') then begin

    LexAnalyzer.Next;
    FOptionPairStatement.Parse(Parent, LexAnalyzer);

    if Not LexAnalyzer.IsToken(ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;

  end;

end;

end.
