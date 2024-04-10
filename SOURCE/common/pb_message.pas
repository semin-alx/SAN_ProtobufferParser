unit pb_message;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, System.Variants,
  pb_container, pb_options, pb_package, lexanalz, pb_base, pb_item;

type

  // label = "required" | "optional" | "repeated" (proto2)
  TsmProtoFieldLabel = (flSingular,  // Default for proto3
                        flRequired,  // Only for proto2
                        flOptional,  // Allowed prot2, proto3
                        flRepeated); // Allowed prot2, proto3

  TsmProtoMessage = class;
  TsmProtoMsgField = class;

  PsmProtoFieldType = ^TsmProtoFieldType;
  TsmProtoFieldType = record
    Token: TsmProtoToken;
    BaseType: TsmProtoBaseFieldType;
    CustomType: TsmProtoItem;
  end;

  TsmProtoMsgField = class(TsmProtoObject)
  private
    FParent: TsmProtoMessage;
    FName: string;
    FFieldId: integer;
    FOptions: TsmProtoOptions;
  protected
    procedure BindFieldType(pFieldType: PsmProtoFieldType);
    procedure DoBindings; virtual;
  public
    constructor Create(ParentA: TsmProtoMessage; NameA: string; FieldIdA: integer); virtual;
    destructor Destroy; override;
    property Name: string read FName;
    property FieldId: integer read FFieldId;
    property Options: TsmProtoOptions read FOptions;
    property Parent: TsmProtoMessage read FParent;
  end;

  // proto3
  //  field = [ "repeated" ] type fieldName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  //  fieldOptions = fieldOption { ","  fieldOption }
  //  fieldOption = optionName "=" constant
  // proto2
  //  label = "required" | "optional" | "repeated"
  //  field = label type fieldName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  //  fieldOptions = fieldOption { ","  fieldOption }
  //  fieldOption = optionName "=" constant
  TsmProtoNormalField = class(TsmProtoMsgField)
  private
    FFieldType: TsmProtoFieldType;
    FFieldLabel: TsmProtoFieldLabel;
    FDefaultValue: Variant;
    FDataPacked: Boolean;
    procedure SetFieldType(const Value: TsmProtoFieldType);
  protected
    procedure DoBindings; override;
  public
    constructor Create(ParentA: TsmProtoMessage; NameA: string; FieldIdA: integer); override;
    destructor Destroy; override;
    property FieldLabel: TsmProtoFieldLabel read FFieldLabel write FFieldLabel;
    property FieldType: TsmProtoFieldType read FFieldType write SetFieldType;
    property DefaultValue: Variant read FDefaultValue;
    property DataPacked: Boolean read FDataPacked;
  end;

  // mapField = "map" "<" keyType "," type ">" mapName "=" fieldNumber [ "[" fieldOptions "]" ] ";"
  // keyType = "int32" | "int64" | "uint32" | "uint64" | "sint32" | "sint64" |
  //        "fixed32" | "fixed64" | "sfixed32" | "sfixed64" | "bool" | "string"

  TsmProtoMapField = class(TsmProtoMsgField)
  private
    FKeyType: TsmProtoBaseFieldType;
    FValueType: TsmProtoFieldType;
    procedure SetValueType(const Value: TsmProtoFieldType);
  protected
    procedure DoBindings; override;
  public
    constructor Create(ParentA: TsmProtoMessage; NameA: string; FieldIdA: integer); override;
    destructor Destroy; override;
    property KeyType: TsmProtoBaseFieldType read FKeyType write FKeyType;
    property ValueType: TsmProtoFieldType read FValueType write SetValueType;
  end;

  TsmProtoOneOfField = class(TsmProtoNormalField)
  private
    FOneOfGroupName: string;
  public
    property OneOfGroupName: string read FOneOfGroupName write FOneOfGroupName;
  end;

  TsmProtoMessage = class(TsmProtoItem)
  private
    FOptions: TsmProtoOptions;
    FFields: TList<TsmProtoMsgField>;
    procedure ClearFields;
  protected
    function GetBaseType: TsmProtoBaseFieldType; override;
  public
    constructor Create(ParentA: TsmProtoObject; NameA: string); override;
    destructor Destroy; override;
    procedure DoBindigns; override;
    function FindFieldByName(FieldName: string): TsmProtoMsgField;
    function FindFieldById(Id: integer): TsmProtoMsgField;
    property Fields: TList<TsmProtoMsgField> read FFields;
    property Options: TsmProtoOptions read FOptions;
  end;

implementation

uses errors, pb_utils, pb_enum;

{ TsmProtoMessage }

procedure TsmProtoMessage.ClearFields;
var
  I: integer;
begin
  for I := 1 to FFields.Count do begin
    FFields[I-1].Free;
  end;
end;

constructor TsmProtoMessage.Create(ParentA: TsmProtoObject; NameA: string);
begin
  inherited;
  FOptions:= TsmProtoOptions.Create(Self);
  FFields:= TList<TsmProtoMsgField>.Create;
end;

destructor TsmProtoMessage.Destroy;
begin
  ClearFields;
  FFields.Free;
  FOptions.Free;
  inherited;
end;

procedure TsmProtoMessage.DoBindigns;
var
  Field: TsmProtoMsgField;
begin
  inherited;

  FOptions.DoBindings;

  for Field in FFields do begin
    Field.DoBindings;
  end;

end;

function TsmProtoMessage.FindFieldById(Id: integer): TsmProtoMsgField;
var
  I: integer;
begin
  Result:= nil;
  for I := 1 to FFields.Count do begin
    if FFields[I-1].FieldId = Id then begin
      Result:= FFields[I-1];
      break;
    end;
  end;
end;

function TsmProtoMessage.FindFieldByName(
  FieldName: string): TsmProtoMsgField;
var
  I: integer;
begin
  Result:= nil;
  for I := 1 to FFields.Count do begin
    if FFields[I-1].Name = FieldName then begin
      Result:= FFields[I-1];
      break;
    end;
  end;
end;

function TsmProtoMessage.GetBaseType: TsmProtoBaseFieldType;
begin
  Result:= ftMessage;
end;

{ TsmProtoMsgField }

procedure TsmProtoMsgField.BindFieldType(pFieldType: PsmProtoFieldType);
begin

  if pFieldType^.BaseType = ftUndefined then begin

    pFieldType^.CustomType:= Parent.FindType(pFieldType^.Token.Value,
                                             True {Include imports});

    if Assigned(pFieldType^.CustomType) then begin
      pFieldType^.BaseType:= pFieldType^.CustomType.BaseType;
    end else begin
      raise EsmParserError.CreateByToken(pFieldType^.Token,
        Format(RsErr_UnknownFieldType, [pFieldType^.Token.Value]));
    end;

  end;

end;

constructor TsmProtoMsgField.Create(ParentA: TsmProtoMessage; NameA: string;
  FieldIdA: integer);
begin

  inherited Create(ParentA);

  FParent:= ParentA;

  if FParent.FindFieldByName(NameA) <> nil then begin
    raise EsmParserError.Create(Format(RsErr_DuplicateFieldName, [NameA]));
  end;

  if FParent.FindFieldById(FieldIdA) <> nil then begin
    raise EsmParserError.Create(Format(RsErr_DuplicateFieldId, [FieldIdA]));
  end;

  FName:= NameA;
  FFieldId:= FieldIdA;

  FOptions:= TsmProtoOptions.Create(Self);

end;

destructor TsmProtoMsgField.Destroy;
begin
  FOptions.Free;
  inherited;
end;

procedure TsmProtoMsgField.DoBindings;
begin
  FOptions.DoBindings;
end;

{ TsmProtoNormalField }

constructor TsmProtoNormalField.Create(ParentA: TsmProtoMessage; NameA: string;
  FieldIdA: integer);
begin
  inherited;
  FFieldLabel:= flOptional;
  FDefaultValue:= Unassigned;
  FDataPacked:= True;
end;

destructor TsmProtoNormalField.Destroy;
begin

  inherited;
end;

procedure TsmProtoNormalField.DoBindings;
var
  OptionDefaultIndex: integer;
  DataPackedIndex: integer;
begin

  BindFieldType(@FFieldType);

  inherited;

  OptionDefaultIndex:= FOptions.FindByName('default');
  if OptionDefaultIndex <> -1 then begin
    FDefaultValue:= FOptions.Values[OptionDefaultIndex].Value;
  end;

  DataPackedIndex:= FOptions.FindByName('packed');
  if DataPackedIndex <> -1 then begin

    if FFieldLabel <> flRepeated then begin
      raise EsmParserError.CreateByToken(FOptions.Values[DataPackedIndex].Token,
        RsErr_WrongOptionPacked);
    end;

    if VarType(FOptions.Values[DataPackedIndex].Value) <> varBoolean then begin
      raise EsmParserError.CreateByToken(FOptions.Values[DataPackedIndex].Token,
        Format(RsErr_ExpectBooleanType, ['packed']));
    end;

    FDataPacked:= FOptions.Values[DataPackedIndex].Value;

  end;

end;

procedure TsmProtoNormalField.SetFieldType(const Value: TsmProtoFieldType);
begin
  FFieldType:= Value;
end;

{ TsmProtoMapField }

constructor TsmProtoMapField.Create(ParentA: TsmProtoMessage; NameA: string;
  FieldIdA: integer);
begin
  inherited;

end;

destructor TsmProtoMapField.Destroy;
begin

  inherited;
end;

procedure TsmProtoMapField.DoBindings;
begin
  inherited;
  BindFieldType(@FValueType);
end;

procedure TsmProtoMapField.SetValueType(const Value: TsmProtoFieldType);
begin
  FValueType:= Value;
end;

end.
