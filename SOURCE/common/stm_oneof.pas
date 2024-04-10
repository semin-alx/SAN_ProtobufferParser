unit stm_oneof;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_package, pb_message, stm_msgfield,
  pb_item;

type

  TsmOneOfStatement = class(TsmSlaveStatement)
  private
    FFieldStm: TsmMsgFieldStatement;
    function ParseFields(LexAnalyzer: TsmLexicalAnalyzer;
      ProtoMessage: TsmProtoMessage; OneofName: string): Boolean;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmOneOfStatement }

constructor TsmOneOfStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FFieldStm:= TsmMsgFieldStatement.Create(ParserA);
end;

destructor TsmOneOfStatement.Destroy;
begin
  FFieldStm.Free;
  inherited;
end;

function TsmOneOfStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer): Boolean;
var
  ProtoMessage: TsmProtoMessage;
  Name: string;
begin

  Result:= False;

  if LexAnalyzer.IsTokenIdent('oneof') then begin

    if (Not Assigned(Parent)) or (Not (Parent is TsmProtoMessage))
      then raise EsmParserError.Create(RsErr_InvalidParentMessageType);

    ProtoMessage:= TsmProtoMessage(Parent);

    LexAnalyzer.Next;

    if not LexAnalyzer.IsToken(ttIdent) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectOneOfName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    Name:= LexAnalyzer.GetToken^.Value;
    LexAnalyzer.Next;

    if (Not LexAnalyzer.IsToken(ttOpenCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['{', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    while Not ParseFields(LexAnalyzer, ProtoMessage, Name) do;

    if (Not LexAnalyzer.IsToken(ttCloseCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['}', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;
  end;

end;

function TsmOneOfStatement.ParseFields(LexAnalyzer: TsmLexicalAnalyzer;
  ProtoMessage: TsmProtoMessage; OneofName: string): Boolean;
var
  OneofField: TsmProtoOneofField;
begin

  Result:= False;

  case LexAnalyzer.GetToken^.TokenType of

    ttSemicolon:
    begin
      // Empty statement
      LexAnalyzer.Next;
    end;

    ttCloseCurlyBracket:
    begin
      Result:= True; // End fields
    end;

    ttEof:
    begin
      raise EsmParserError.Create(RsErr_UnexpectedEndOfFile);
    end;

    else begin

      FFieldStm.Parse(ProtoMessage, LexAnalyzer);

      OneofField:= TsmProtoOneofField.Create(ProtoMessage,
                                             FFieldStm.FieldName,
                                             FFieldStm.FieldId);

      OneofField.FieldLabel:= FFieldStm.FieldLabel;
      OneofField.FieldType:= FFieldStm.FieldType;
      OneofField.OneOfGroupName:= OneofName;

      ProtoMessage.Fields.Add(OneofField);

    end;

  end;

end;

end.
