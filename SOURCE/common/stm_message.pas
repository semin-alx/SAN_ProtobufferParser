unit stm_message;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Variants, parser, lexanalz, pb_container,
  pb_package, pb_message, stm_enum, stm_option, stm_reserved, stm_msgfield,
  stm_map, stm_oneof, pb_item, stm_extantions;

type

  TsmMessageStatement = class(TsmMasterStatement)
  private
    FEnumStatement: TsmEnumStatement;
    FMessageStatement: TsmMessageStatement;
    FOptionStatement: TsmOptionStatement;
    FReservedStatement: TsmReservedStatement;
    FExtantionsStatement: TsmExtantionsStatement;
    FMsgFieldStatement: TsmMsgFieldStatement;
    FMapStatement: TsmMapStatement;
    FOneOfStatement: TsmOneOfStatement;
    procedure CreateStatements;
    procedure FreeStatements;
    function ParseMessageItem(LexAnalyzer: TsmLexicalAnalyzer; ProtoMessage: TsmProtoMessage): Boolean;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmMessageStatement }

constructor TsmMessageStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FEnumStatement:= nil;
  FMessageStatement:= nil;
  FOptionStatement:= nil;
  FReservedStatement:= nil;
  FMsgFieldStatement:= nil;
  FOneOfStatement:= nil;
end;

procedure TsmMessageStatement.CreateStatements;
begin
  if Not Assigned(FEnumStatement) then FEnumStatement:= TsmEnumStatement.Create(Parser);
  if Not Assigned(FMessageStatement) then FMessageStatement:= TsmMessageStatement.Create(Parser);
  if Not Assigned(FOptionStatement) then FOptionStatement:= TsmOptionStatement.Create(Parser);
  if Not Assigned(FReservedStatement) then FReservedStatement:= TsmReservedStatement.Create(Parser);
  if Not Assigned(FExtantionsStatement) then FExtantionsStatement:= TsmExtantionsStatement.Create(Parser);
  if Not Assigned(FMsgFieldStatement) then FMsgFieldStatement:= TsmMsgFieldStatement.Create(Parser);
  if Not Assigned(FMapStatement) then FMapStatement:= TsmMapStatement.Create(Parser);
  if Not Assigned(FOneOfStatement) then FOneOfStatement:= TsmOneOfStatement.Create(Parser);

end;

destructor TsmMessageStatement.Destroy;
begin
  FreeStatements;
  inherited;
end;

procedure TsmMessageStatement.FreeStatements;
begin
  if Assigned(FEnumStatement) then FEnumStatement.Free;
  if Assigned(FMessageStatement) then FMessageStatement.Free;
  if Assigned(FOptionStatement) then FOptionStatement.Free;
  if Assigned(FReservedStatement) then FReservedStatement.Free;
  if Assigned(FExtantionsStatement) then FExtantionsStatement.Free;
  if Assigned(FMsgFieldStatement) then FMsgFieldStatement.Free;
  if Assigned(FMapStatement) then FMapStatement.Free;
  if Assigned(FOneOfStatement) then FOneOfStatement.Free;
end;

function TsmMessageStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer): Boolean;
var
  ProtoMessage: TsmProtoMessage;
begin

  Result:= False;

  // messageName = ident
  // message = "message" messageName messageBody
  // messageBody = "{" { field | enum | message | option | oneof | mapField |
  // reserved | emptyStatement } "}"

  if LexAnalyzer.IsTokenIdent('message') then begin

    CreateStatements;

    LexAnalyzer.Next;

    if (Not LexAnalyzer.IsToken(ttIdent)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectMessageName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    ProtoMessage:= TsmProtoMessage(Parser.Package.CreateItem(TsmProtoMessage, Parent,
      LexAnalyzer.GetToken^.Value));

    LexAnalyzer.Next;

    if (Not LexAnalyzer.IsToken(ttOpenCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['{', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    while Not ParseMessageItem(LexAnalyzer, ProtoMessage) do;

    if (Not LexAnalyzer.IsToken(ttCloseCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['}', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;
  end;

end;

function TsmMessageStatement.ParseMessageItem(LexAnalyzer: TsmLexicalAnalyzer;
  ProtoMessage: TsmProtoMessage): Boolean;
var
  NormalField: TsmProtoNormalField;
begin

  Result:= False;

  // messageBody = "{" { field | enum | message | option | oneof | mapField |
  // reserved | emptyStatement } "}"

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
      if Not FEnumStatement.Parse(ProtoMessage, LexAnalyzer) then
      if Not FMessageStatement.Parse(ProtoMessage, LexAnalyzer) then
      {$MESSAGE HINT 'keyword extend not done yet (reserved and extantions are stub)'}
      if Not FReservedStatement.Parse(ProtoMessage, LexAnalyzer) then
      if Not FExtantionsStatement.Parse(ProtoMessage, LexAnalyzer) then
      if Not FMapStatement.Parse(ProtoMessage, LexAnalyzer) then
      if Not FOneOfStatement.Parse(ProtoMessage, LexAnalyzer) then
      if FOptionStatement.Parse(ProtoMessage, LexAnalyzer) then begin
        ProtoMessage.Options.Add(FOptionStatement.Name,
            FOptionStatement.ConstantValue);
      end else begin
        FMsgFieldStatement.Parse(ProtoMessage, LexAnalyzer);
        NormalField:= TsmProtoNormalField.Create(ProtoMessage,
                                           FMsgFieldStatement.FieldName,
                                           FMsgFieldStatement.FieldId);
        NormalField.FieldLabel:= FMsgFieldStatement.FieldLabel;
        NormalField.FieldType:= FMsgFieldStatement.FieldType;
        NormalField.Options.Assign(FMsgFieldStatement.Options);
        ProtoMessage.Fields.Add(NormalField);
      end;
    end;

  end;

end;

end.
