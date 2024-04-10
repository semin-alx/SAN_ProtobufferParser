unit stm_fieldtype;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Classes, parser, lexanalz, pb_package, pb_message,
  pb_enum, pb_base, pb_item;

type

  TsmFieldTypeStatement = class(TsmContextStatement)
  private
    FFieldType: TsmProtoFieldType;
  public
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); override;
    property FieldType: TsmProtoFieldType read FFieldType;
  end;

implementation

uses errors;

{ TsmFieldTypeStatement }

procedure TsmFieldTypeStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer);
begin

  //type = "double" | "float" | "int32" | "int64" | "uint32" | "uint64"
  //    | "sint32" | "sint64" | "fixed32" | "fixed64" | "sfixed32" | "sfixed64"
  //    | "bool" | "string" | "bytes" | messageType | enumType
  FFieldType.BaseType:= ftUndefined;
  FFieldType.Token:= LexAnalyzer.GetToken^;
  FFieldType.CustomType:= nil;

  if LexAnalyzer.IsTokenIdent('double') then FFieldType.BaseType:= ftDouble
  else if LexAnalyzer.IsTokenIdent('float') then FFieldType.BaseType:= ftFloat
  else if LexAnalyzer.IsTokenIdent('int32') then FFieldType.BaseType:= ftInt32
  else if LexAnalyzer.IsTokenIdent('int64') then FFieldType.BaseType:= ftInt64
  else if LexAnalyzer.IsTokenIdent('uint32') then FFieldType.BaseType:= ftInt32
  else if LexAnalyzer.IsTokenIdent('uint64') then FFieldType.BaseType:= ftInt64
  else if LexAnalyzer.IsTokenIdent('sint32') then FFieldType.BaseType:= ftSint32
  else if LexAnalyzer.IsTokenIdent('sint64') then FFieldType.BaseType:= ftSint64
  else if LexAnalyzer.IsTokenIdent('fixed32') then FFieldType.BaseType:= ftFixed32
  else if LexAnalyzer.IsTokenIdent('fixed64') then FFieldType.BaseType:= ftFixed64
  else if LexAnalyzer.IsTokenIdent('sfixed32') then FFieldType.BaseType:= ftSfixed32
  else if LexAnalyzer.IsTokenIdent('sfixed64') then FFieldType.BaseType:= ftSfixed64
  else if LexAnalyzer.IsTokenIdent('bool') then FFieldType.BaseType:= ftBoolean
  else if LexAnalyzer.IsTokenIdent('string') then FFieldType.BaseType:= ftString
  else if LexAnalyzer.IsTokenIdent('bytes') then FFieldType.BaseType:= ftBytes
  else begin
    if Not (LexAnalyzer.IsToken(ttIdent) or LexAnalyzer.IsToken(ttFullIdent)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectFieldType, [LexAnalyzer.GetToken^.Value]));
    end;
  end;

  LexAnalyzer.Next;

end;

end.
