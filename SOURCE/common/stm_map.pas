unit stm_map;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_container, pb_package, pb_message,
  stm_option_list, stm_fieldtype, pb_options, pb_base, pb_item;

type

  // mapField = "map" "<" keyType "," type ">" mapName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  // keyType = "int32" | "int64" | "uint32" | "uint64" | "sint32" | "sint64" |
  //        "fixed32" | "fixed64" | "sfixed32" | "sfixed64" | "bool" | "string"
  // mapName = ident
  TsmMapStatement = class(TsmSlaveStatement)
  private
    FOptionListStm: TsmOptionListStatement;
    FFieldTypeStm: TsmFieldTypeStatement;
    function GetKeyType(FieldTypeStm: TsmFieldTypeStatement): TsmProtoBaseFieldType;
    function GetOptionListStatement: TsmProtoOptions;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
    property Options: TsmProtoOptions read GetOptionListStatement;
  end;

implementation

uses errors;

{ TsmMapStatement }

function TsmMapStatement.GetKeyType(FieldTypeStm: TsmFieldTypeStatement): TsmProtoBaseFieldType;
begin

  if (FieldTypeStm.FieldType.BaseType = ftUndefined)
    or Not (FieldTypeStm.FieldType.BaseType in [
      ftInt32, ftInt64, ftUint32, ftUint64, ftSint32, ftSint64,
      ftFixed32, ftFixed64, ftSfixed32, ftSfixed64, ftBoolean, ftString])
  then begin
    raise EsmParserError.Create(RsErr_InvalidMapKeyType);
  end;

  Result:= FieldTypeStm.FieldType.BaseType;

end;

constructor TsmMapStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FFieldTypeStm:= TsmFieldTypeStatement.Create(ParserA);
  FOptionListStm:= TsmOptionListStatement.Create(ParserA);
end;

destructor TsmMapStatement.Destroy;
begin
  FFieldTypeStm.Free;
  FOptionListStm.Free;
  inherited;
end;

function TsmMapStatement.GetOptionListStatement: TsmProtoOptions;
begin
  Result:= FOptionListStm.Options;
end;

function TsmMapStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer): Boolean;
var
  ProtoMessage: TsmProtoMessage;
  KeyType: TsmProtoBaseFieldType;
  ValueType: TsmProtoFieldType;
  Name: string;
  FieldId: integer;
  MapField: TsmProtoMapField;
begin

  Result:= False;

  if LexAnalyzer.IsTokenIdent('map') then begin

    if (Not Assigned(Parent)) or (Not (Parent is TsmProtoMessage))
      then raise EsmParserError.Create(RsErr_InvalidParentMessageType);

    ProtoMessage:= TsmProtoMessage(Parent);

    LexAnalyzer.Next;

    if Not LexAnalyzer.IsToken(ttLess) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['<', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    FFieldTypeStm.Parse(Parent, LexAnalyzer);
    KeyType:= GetKeyType(FFieldTypeStm);

    if not LexAnalyzer.IsToken(ttComma) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [',', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    FFieldTypeStm.Parse(Parent, LexAnalyzer);
    ValueType:= FFieldTypeStm.FieldType;

    if Not LexAnalyzer.IsToken(ttMore) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['>', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    if not LexAnalyzer.IsToken(ttIdent) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectMapName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    Name:= LexAnalyzer.GetToken^.Value;
    LexAnalyzer.Next;

    if Not LexAnalyzer.IsToken(ttEquals) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['=', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    if not LexAnalyzer.IsToken(ttInteger) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectIntegerValue,
        [LexAnalyzer.GetToken^.Value]));
    end;

    FieldId:= StrToInt(LexAnalyzer.GetToken^.Value);

    LexAnalyzer.Next;

    FOptionListStm.Options.Clear;
    if LexAnalyzer.IsToken(ttOpenSquareBracket) then begin
      FOptionListStm.Parse(Parent, LexAnalyzer);
    end;

    if Not LexAnalyzer.IsToken(ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    MapField:= TsmProtoMapField.Create(ProtoMessage, Name, FieldId);
    MapField.KeyType:= KeyType;
    MapField.ValueType:= ValueType;
    MapField.Options.Assign(FOptionListStm.Options);

    ProtoMessage.Fields.Add(MapField);
    Result:= True;

  end;

end;

end.
