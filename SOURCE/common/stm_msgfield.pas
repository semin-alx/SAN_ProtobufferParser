unit stm_msgfield;

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
  parser, lexanalz, pb_container, pb_enum, stm_option_pair, pb_message,
  pb_package, pb_options, stm_option_list, stm_fieldtype, pb_base, pb_item;

type

  TsmMsgFieldStatement = class(TsmContextStatement)
  private
    FFieldTypeStm: TsmFieldTypeStatement;
    FOptionListStatement: TsmOptionListStatement;
    FFieldName: string;
    FFieldLabel: TsmProtoFieldLabel;
    FFieldId: integer;
    function ParseLabelProto2(LexAnalyzer: TsmLexicalAnalyzer): TsmProtoFieldLabel;
    function ParseLabelProto3(LexAnalyzer: TsmLexicalAnalyzer): TsmProtoFieldLabel;
    function GetOptions: TsmProtoOptions;
    function GetFieldType: TsmProtoFieldType;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property FieldName: string read FFieldName;
    property FieldId: integer read FFieldId;
    property FieldLabel: TsmProtoFieldLabel read FFieldLabel;
    property FieldType: TsmProtoFieldType read GetFieldType;
    property Options: TsmProtoOptions read GetOptions;
  end;

implementation

uses errors;

{ TsmMsgFieldStatement }

constructor TsmMsgFieldStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FFieldTypeStm:= TsmFieldTypeStatement.Create(ParserA);
  FOptionListStatement:= TsmOptionListStatement.Create(ParserA);
end;

destructor TsmMsgFieldStatement.Destroy;
begin
  FFieldTypeStm.Free;
  FOptionListStatement.Free;
  inherited;
end;

function TsmMsgFieldStatement.GetOptions: TsmProtoOptions;
begin
  Result:= FOptionListStatement.Options;
end;

function TsmMsgFieldStatement.GetFieldType: TsmProtoFieldType;
begin
  Result:= FFieldTypeStm.FieldType;
end;

function TsmMsgFieldStatement.ParseLabelProto2(
  LexAnalyzer: TsmLexicalAnalyzer): TsmProtoFieldLabel;
begin

  if LexAnalyzer.IsTokenIdent('required') then begin
    Result:= flRequired;
  end else
  if LexAnalyzer.IsTokenIdent('optional') then begin
    Result:= flOptional;
  end else
  if LexAnalyzer.IsTokenIdent('repeated') then begin
    Result:= flRepeated;
  end else begin
    raise EsmParserError.Create(Format(RsErr_ExpectFieldLabel,
      [LexAnalyzer.GetToken^.Value]));
  end;

  LexAnalyzer.Next;

end;

function TsmMsgFieldStatement.ParseLabelProto3(
  LexAnalyzer: TsmLexicalAnalyzer): TsmProtoFieldLabel;
begin

  Result:= flSingular;

  if LexAnalyzer.IsTokenIdent('repeated') then begin
    Result:= flRepeated;
    LexAnalyzer.Next;
  end else
  if LexAnalyzer.IsTokenIdent('optional') then begin
    Result:= flOptional;
    LexAnalyzer.Next;
  end else begin
    if LexAnalyzer.IsTokenIdent('required')
    then begin
      raise EsmParserError.Create(Format(RsErr_InvalidFieldLabelProto3,
        [LexAnalyzer.GetToken^.Value]));
    end;
  end;

end;

procedure TsmMsgFieldStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer);
begin

  // proto3
  //  field = [ "repeated" ] type fieldName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  //  fieldOptions = fieldOption { ","  fieldOption }
  //  fieldOption = optionName "=" constant
  // proto2
  //  label = "required" | "optional" | "repeated"
  //  field = label type fieldName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  //  fieldOptions = fieldOption { ","  fieldOption }
  //  fieldOption = optionName "=" constant

  if Parser.Package.Version = svSyntax2 then begin
    FFieldLabel:= ParseLabelProto2(LexAnalyzer);
  end else begin
    FFieldLabel:= ParseLabelProto3(LexAnalyzer);
  end;

  FFieldTypeStm.Parse(Parent, LexAnalyzer);

  if Not LexAnalyzer.IsToken(ttIdent) then begin
    raise EsmParserError.Create(Format(RsErr_ExpectFieldName,
      [LexAnalyzer.GetToken^.Value]));
  end;

  FFieldName:= LexAnalyzer.GetToken^.Value;
  LexAnalyzer.Next;

  if Not LexAnalyzer.IsToken(ttEquals) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['=', LexAnalyzer.GetToken^.Value]));
  end;

  LexAnalyzer.Next;

  if Not LexAnalyzer.IsToken(ttInteger) then begin
    raise EsmParserError.Create(Format(RsErr_ExpectIntegerValue,
      [LexAnalyzer.GetToken^.Value]));
  end;

  FFieldId:= StrToInt(LexAnalyzer.GetToken^.Value);

  LexAnalyzer.Next;

  FOptionListStatement.Options.Clear;
  if LexAnalyzer.IsToken(ttOpenSquareBracket)
      then FOptionListStatement.Parse(Parent, LexAnalyzer);

  if Not LexAnalyzer.IsToken(ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

  LexAnalyzer.Next;

end;

end.
