unit bld_delphi;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.IOUtils, System.Variants, builder, pb_container,
  pb_package, pb_message, pb_enum, pb_utils, pb_base, pb_item;

type
  TsmDelphiBuilder = class(TsmBuilder)
  private
    FAppName: string;
    procedure AddUnit;
    procedure AddModuleDescr(Container: TsmProtoBufContainer);
    procedure AddParsedFiles(Container: TsmProtoBufContainer; Offset: integer);
    procedure AddAvailableTypes(Container: TsmProtoBufContainer; Offset: integer);
    procedure AddHeader;
    procedure AddConstSection(Container: TsmProtoBufContainer);
    procedure AddVarSection;
    procedure AddFunc_GetProtoType;
    procedure AddFunc_CreateProtoInstance;
    procedure AddFunc_GetMapType;
    procedure AddProcSet_DefineMessageFileds(Container: TsmProtoBufContainer);
    procedure AddProcSet_DefineEnumFileds(Container: TsmProtoBufContainer);
    procedure AddProc_DefineMessageFields(Package: TsmProtoPackage;
      ProtoItem: TsmProtoMessage; FuncNumber: integer);
    procedure AddProc_DefineEnumFields(Package: TsmProtoPackage;
      ProtoItem: TsmProtoEnum; FuncNumber: integer);
    procedure AddFooter;
    procedure AddProc_CreateTypes(Container: TsmProtoBufContainer);
    procedure AddCallDefineMessageFields(Container: TsmProtoBufContainer);
    procedure AddCallDefineEnumItems(Container: TsmProtoBufContainer);
    procedure DefineMessageField(MessageType: TsmProtoMessage; Offset: integer);
    procedure DefineEnumItem(ProtoEnum: TsmProtoEnum; Offset: integer);
    procedure AddNormalField(Field: TsmProtoNormalField; Offset: integer);
    procedure AddMapField(Field: TsmProtoMapField; Offset: integer);
    procedure AddConstProtoNames(Container: TsmProtoBufContainer;
      ConstArrayName: string; ProtoType: TsmProtoBaseFieldType);
    function GetFieldLabel(FieldLabel: TsmProtoFieldLabel): string;
    function VariantToPasString(Value: Variant): string;
  protected
    procedure BuildData(Container: TsmProtoBufContainer); override;
  public
    constructor Create; override;
    property AppName: string read FAppName write FAppName;
  end;

implementation

uses errors;

const
  ARR_PROTO_MESSAGE_NAMES    = 'PROTO_MESSAGE_NAMES';
  ARR_PROTO_ENUM_NAMES       = 'PROTO_ENUM_NAMES';
  PROC_DEFINE_MESSAGE_FIELDS = 'DefineMessageFields_%d';
  PROC_DEFINE_ENUM_ITEMS     = 'DefineEnumItems_%d';
  FUNC_GET_PROTO_TYPE        = 'GetProtoType';
  FUNC_GET_PROTO_INSTANCE    = 'CreateProtoInstance';
  FUNC_GET_MAP_TYPE          = 'GetMapType';

{ TsmDelphiBuilder }

procedure TsmDelphiBuilder.AddAvailableTypes(Container: TsmProtoBufContainer;
  Offset: integer);
var
  I: integer;
  J: integer;
  ProtoItem: TsmProtoItem;
begin
  for I:= 1 to Container.PackageCount do begin
    for J := 1 to Container.Packages[I-1].ItemCount do begin
      ProtoItem:= Container.Packages[I-1].Items[J-1];
      if ProtoItem.BaseType = ftMessage then begin
        Addline(ProtoItem.FullName, Offset);
      end;
    end;
  end;
end;

procedure TsmDelphiBuilder.AddCallDefineEnumItems(
  Container: TsmProtoBufContainer);
var
  I, J: integer;
  N: integer;
  Package: TsmProtoPackage;
  ProcName: string;
begin

  N:= 1;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ftEnum then begin
        ProcName:= Format(PROC_DEFINE_ENUM_ITEMS, [N]);
        AddLine(Format('%s; //%s', [ProcName, Package.Items[J-1].FullName]), 1);
        Inc(N);
      end;
    end;
  end;

  AddLine('');

end;

procedure TsmDelphiBuilder.AddCallDefineMessageFields(
  Container: TsmProtoBufContainer);
var
  I, J: integer;
  N: integer;
  Package: TsmProtoPackage;
  ProcName: string;
begin

  N:= 1;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ftMessage then begin
        ProcName:= Format(PROC_DEFINE_MESSAGE_FIELDS, [N]);
        AddLine(Format('%s; //%s', [ProcName, Package.Items[J-1].FullName]), 1);
        Inc(N);
      end;
    end;
  end;

  AddLine('');

end;

procedure TsmDelphiBuilder.AddConstProtoNames(Container: TsmProtoBufContainer;
  ConstArrayName: string; ProtoType: TsmProtoBaseFieldType);
var
  NamesCount: integer;
  I, J, n: integer;
  Package: TsmProtoPackage;
begin

  NamesCount:= 0;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ProtoType then begin
        Inc(NamesCount);
      end;
    end;
  end;

  AddLine(Format('%s: array[0..%d] of string = (', [ConstArrayName, NamesCount-1]), 1);

  n:= 1;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ProtoType then begin
        if n = NamesCount then begin
          AddLine(Format('''%s''', [Package.Items[J-1].FullName]), 2);
        end else begin
          AddLine(Format('''%s'',', [Package.Items[J-1].FullName]), 2);
        end;
        Inc(n);
      end;
    end;
  end;

  AddLine(');', 1);
  AddLine('');

end;

procedure TsmDelphiBuilder.AddConstSection(Container: TsmProtoBufContainer);
begin
  AddLine('const');
  AddLine('');
  AddConstProtoNames(Container, ARR_PROTO_MESSAGE_NAMES, ftMessage);
  AddConstProtoNames(Container, ARR_PROTO_ENUM_NAMES, ftEnum);
end;

procedure TsmDelphiBuilder.DefineEnumItem(ProtoEnum: TsmProtoEnum;
  Offset: integer);
var
  EnumItem: TsmProtoEnumItem;
begin
  for EnumItem in ProtoEnum.Items do begin
    AddLine(Format('AddEnumItem(%d, ''%s'');',
            [EnumItem.Value, EnumItem.Name]), Offset);
  end;
end;

procedure TsmDelphiBuilder.DefineMessageField(MessageType: TsmProtoMessage;
  Offset: integer);
var
  Field: TsmProtoMsgField;
begin

  for Field in MessageType.Fields do begin

    {$MESSAGE HINT 'Build pas file: Oneof not done yet'}
    //if Field is TsmProtoOneOfField then begin

    //end else
    if Field is TsmProtoNormalField then begin
      AddNormalField(TsmProtoNormalField(Field), Offset);
    end else
    if Field is TsmProtoMapField then begin
      AddMapField(TsmProtoMapField(Field), Offset);
    end else begin
      raise EsmParserError.CreateFmt(RsErrBuild_UnknownFieldClass, [Field.ClassName]);
    end;

  end;

end;

procedure TsmDelphiBuilder.AddFooter;
begin

  AddLine('procedure FreeTypes;');
  AddLine('var');
  AddLine('ProtoType: TsanPBCustomType;', 1);
  AddLine('begin');
  AddLine('for ProtoType in ProtoTypeList do ProtoType.Free;', 1);
  AddLine('ProtoTypeList.Free;', 1);
  AddLine('end;');
  AddLine('');
  AddLine('initialization');
  AddLine('CreateTypes;', 1);
  AddLine('');
  AddLine('finalization');
  AddLine('FreeTypes;', 1);
  AddLine('');
  AddLine('end.');

end;

procedure TsmDelphiBuilder.AddProc_CreateTypes(Container: TsmProtoBufContainer);
begin

  AddLine('procedure CreateTypes;');
  AddLine('var');
  AddLine('I: integer;', 1);
  AddLine('begin');
  AddLine('');
  AddLine('ProtoTypeList:= TList<TsanPBCustomType>.Create;', 1);
  AddLine('');

  AddLine(Format('for I:= 1 to Length(%s) do begin', [ARR_PROTO_MESSAGE_NAMES]), 1);
  AddLine(Format('ProtoTypeList.Add(TsanPBMessageType.Create(nil, %s[I-1]));', [ARR_PROTO_MESSAGE_NAMES]), 2);
  AddLine('end;', 1);
  AddLine('');
  AddLine(Format('for I:= 1 to Length(%s) do begin', [ARR_PROTO_ENUM_NAMES]), 1);
  AddLine(Format('ProtoTypeList.Add(TsanPBEnumType.Create(nil, %s[I-1]));', [ARR_PROTO_ENUM_NAMES]), 2);
  AddLine('end;', 1);

  AddLine('');

  AddCallDefineMessageFields(Container);
  AddCallDefineEnumItems(Container);

  AddLine('end;');
  AddLine('');

end;

procedure TsmDelphiBuilder.AddProc_DefineEnumFields(Package: TsmProtoPackage;
  ProtoItem: TsmProtoEnum; FuncNumber: integer);
var
  ProcName: string;
begin

  ProcName:= Format(PROC_DEFINE_ENUM_ITEMS, [FuncNumber]);

  AddLine(Format('// %s', [Package.FileName]));
  AddLine(Format('// %s', [ProtoItem.FullName]));

  AddLine(Format('procedure %s;', [ProcName]));
  AddLine('begin');

  AddLine(Format('with TsanPBEnumType(%s(''%s'')) do begin',
    [FUNC_GET_PROTO_TYPE, ProtoItem.FullName]), 1);

  DefineEnumItem(ProtoItem, 2);

  AddLine('end;', 1);

  AddLine('end;');
  AddLine('');

end;

procedure TsmDelphiBuilder.AddProc_DefineMessageFields(Package: TsmProtoPackage;
  ProtoItem: TsmProtoMessage; FuncNumber: integer);
var
  ProcName: string;
begin

  ProcName:= Format(PROC_DEFINE_MESSAGE_FIELDS, [FuncNumber]);

  AddLine(Format('// %s', [Package.FileName]));
  AddLine(Format('// %s', [ProtoItem.FullName]));

  AddLine(Format('procedure %s;', [ProcName]));
  AddLine('begin');

  AddLine(Format('with TsanPBMessageType(%s(''%s'')) do begin',
    [FUNC_GET_PROTO_TYPE, ProtoItem.FullName]), 1);

  DefineMessageField(ProtoItem, 2);

  AddLine('end;', 1);

  AddLine('end;');
  AddLine('');

end;

procedure TsmDelphiBuilder.AddProcSet_DefineEnumFileds(
  Container: TsmProtoBufContainer);
var
  I, J: integer;
  N: integer;
  Package: TsmProtoPackage;
begin

  N:= 1;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ftEnum then begin
        AddProc_DefineEnumFields(Package, TsmProtoEnum(Package.Items[J-1]), N);
        Inc(N);
      end;
    end;
  end;

end;

procedure TsmDelphiBuilder.AddProcSet_DefineMessageFileds(
  Container: TsmProtoBufContainer);
var
  I, J: integer;
  N: integer;
  Package: TsmProtoPackage;
begin

  N:= 1;

  for I := 1 to Container.PackageCount do begin
    Package:= Container.Packages[I-1];
    for J := 1 to Package.ItemCount do begin
      if Package.Items[J-1].BaseType = ftMessage then begin
        AddProc_DefineMessageFields(Package, TsmProtoMessage(Package.Items[J-1]), N);
        Inc(N);
      end;
    end;
  end;

end;

procedure TsmDelphiBuilder.AddFunc_CreateProtoInstance;
begin
  AddLine(Format('function %s(ProtoName: string): TsanPBMessage;', [FUNC_GET_PROTO_INSTANCE]));
  AddLine('var');
  AddLine('ProtoType: TsanPBCustomType;', 1);
  AddLine('begin');
  AddLine(Format('ProtoType:= %s(ProtoName);', [FUNC_GET_PROTO_TYPE]), 1);
  AddLine('if Assigned(ProtoType) and (ProtoType is TsanPBMessageType) then begin', 1);
  AddLine('Result:= TsanPBMessageType(ProtoType).CreateInstance;', 2);
  AddLine('end else begin', 1);
  AddLine('Result:= nil;', 2);
  AddLine('end;', 1);
  AddLine('end;');
  AddLine('');
end;

procedure TsmDelphiBuilder.AddFunc_GetMapType;
begin
  AddLine(Format('function %s(KeyType: TsanPBFieldType; ValueType: TsanPBFieldType;', [FUNC_GET_MAP_TYPE]));
  AddLine('ValueCustomType: TsanPBCustomType): TsanPBMessageType;', 1);
  AddLine('begin');
  AddLine('Result:= TsanPBMessageType.Create(nil, '''');', 1);
  AddLine('Result.AddFieldDef(ftoRequired, KeyType, nil, ''key'', 1);', 1);
  AddLine('Result.AddFieldDef(ftoRequired, ValueType, ValueCustomType, ''value'', 2);', 1);
  AddLine('ProtoTypeList.Add(Result);', 1);
  AddLine('end;');
  AddLine('');
end;

procedure TsmDelphiBuilder.AddFunc_GetProtoType;
begin
  AddLine(Format('function %s(ProtoTypeName: string): TsanPBCustomType;', [FUNC_GET_PROTO_TYPE]));
  AddLine('var');
  AddLine('ProtoType: TsanPBCustomType;', 1);
  AddLine('begin');
  AddLine('Result:= nil;', 1);
  AddLine('for ProtoType in ProtoTypeList do begin', 1);
  AddLine('if ProtoType.Name = ProtoTypeName then begin', 2);
  AddLine('Result:= ProtoType;', 3);
  AddLine('break;', 3);
  AddLine('end;', 2);
  AddLine('end;', 1);
  AddLine('end;');
  AddLine('');
end;

procedure TsmDelphiBuilder.AddHeader;
begin
  AddLine('interface');
  AddLine('');
  AddLine('uses System.Classes, System.Generics.Collections, semin64.protobuf;');
  AddLine('');
  AddLine('// Creating a TsanPBMessage object by full name');
  AddLine('// Don''t forget to call Free after using it');
  AddLine(Format('function %s(ProtoName: string): TsanPBMessage;', [FUNC_GET_PROTO_INSTANCE]));
  AddLine('');
  AddLine('implementation');
  AddLine('');
end;

procedure TsmDelphiBuilder.AddMapField(Field: TsmProtoMapField;
  Offset: integer);
var
  KeyFieldType: string;
  ValueBaseType: string;
  CustomValueType: string;
begin

  // Example:
  // AddFieldDef(ftoRepeated, ftMessage, GetMapType(ftString, ftInt32, nil), 'mapList', 6);
  KeyFieldType:= BaseTypeToString(Field.KeyType);
  ValueBaseType:= BaseTypeToString(Field.ValueType.BaseType);

  if Assigned(Field.ValueType.CustomType) then begin
    CustomValueType:= Format('%s(''%s'')',
      [FUNC_GET_PROTO_TYPE, Field.ValueType.CustomType.FullName]);
  end else begin
    CustomValueType:= 'nil';
  end;

  AddLine(Format('AddFieldDef(ftoRepeated, ftMessage, %s(%s, %s, %s), ''%s'', %d);',
    [FUNC_GET_MAP_TYPE, KeyFieldType, ValueBaseType, CustomValueType, Field.Name, Field.FieldId]),
    Offset);

end;

procedure TsmDelphiBuilder.AddModuleDescr(Container: TsmProtoBufContainer);
begin
  AddLine('{=============================================================================');
  AddLine(Format('This file was generated automatically by the %s', [FAppName]), 1);
  AddLine(Format('Date: %s', [FormatDateTime('dd/mm/yyyy hh:nn:ss', Now)]), 1);
  AddLine('');
  AddLine('Files: ', 1);
  AddParsedFiles(Container, 4);
  AddLine('');
  AddLine('Available types: ', 1);
  AddAvailableTypes(Container, 4);
  AddLine('');
  AddLine(' =============================================================================}');
  AddLine('');
end;

procedure TsmDelphiBuilder.AddNormalField(Field: TsmProtoNormalField;
  Offset: integer);
var
  FieldLabel: string;
  BaseFieldType: string;
  CustomFieldType: string;
begin

  // Example:
  // AddFieldDef(ftoRequired, ftString, nil, 'date', 2);
  // AddFieldDef(ftoRequired, ftMessage, GetProtoType('MyApp.Api.Firms'), 'client', 3);
  FieldLabel:= GetFieldLabel(Field.FieldLabel);
  BaseFieldType:= BaseTypeToString(Field.FieldType.BaseType);

  if Assigned(Field.FieldType.CustomType) then begin
    CustomFieldType:= Format('%s(''%s'')',
      [FUNC_GET_PROTO_TYPE, Field.FieldType.CustomType.FullName]);
  end else begin
    CustomFieldType:= 'nil';
  end;

  AddLine(Format('AddFieldDef(%s, %s, %s, ''%s'', %d);',
    [FieldLabel, BaseFieldType, CustomFieldType, Field.Name, Field.FieldId]),
    Offset);

  if Not Field.DataPacked then begin
    AddLine('FieldDef[FieldDefsCount-1].DataPacked:= False;', Offset);
  end;

  if Not VarIsEmpty(Field.DefaultValue) then begin
    AddLine(Format('FieldDef[FieldDefsCount-1].DefaultValue:= %s;',
      [VariantToPasString(Field.DefaultValue)]), Offset);
  end;

end;

procedure TsmDelphiBuilder.AddParsedFiles(Container: TsmProtoBufContainer;
  Offset: integer);
var
  I: integer;
begin
  for I:= 1 to Container.PackageCount do begin
    Addline(Container.Packages[I-1].FileName, Offset);
  end;
end;

procedure TsmDelphiBuilder.AddUnit;
begin
  AddLine(Format('unit %s;', [TPath.GetFileNameWithoutExtension(FileName)]));
  AddLine('');
end;

procedure TsmDelphiBuilder.AddVarSection;
begin
  AddLine('var');
  AddLine('ProtoTypeList: TList<TsanPBCustomType>;', 1);
  AddLine('');
end;

procedure TsmDelphiBuilder.BuildData(Container: TsmProtoBufContainer);
begin

  // Все названия типов я в начале прописываю в массивы
  // PROTO_MESSAGE_NAMES и PROTO_ENUM_NAMES
  // Раньше я определял их напрямую в функции CreateTypes, то при большом
  // кол-ве типов я получал ошибку компилятора:
  //   E2283 Too many local constants.  Use shorter procedures

  AddUnit;
  AddModuleDescr(Container);
  AddHeader;                      // interface..implementation
  AddConstSection(Container);     // const...
  AddVarSection;                  // var...
  AddFunc_GetProtoType;           // function GetProtoType(...
  AddFunc_CreateProtoInstance;    // function CreateProtoInstance(...
  AddFunc_GetMapType;             // function GetMapType(...
  AddProcSet_DefineMessageFileds(Container); // function DefineMessageFields_%d
  AddProcSet_DefineEnumFileds(Container);    // function DefineEnumFields_%d
  AddProc_CreateTypes(Container);
  AddFooter;
end;

constructor TsmDelphiBuilder.Create;
begin
  inherited;
  FAppName:= 'ProtoBuf parser for Delphi v1.0.';
end;

function TsmDelphiBuilder.GetFieldLabel(
  FieldLabel: TsmProtoFieldLabel): string;
begin

  {$MESSAGE HINT 'Build pas file: flSingular not done yet'}
  case FieldLabel of
    flSingular: Result:= 'ftoOptional';
    flRequired: Result:= 'ftoRequired';
    flOptional: Result:= 'ftoOptional';
    flRepeated: Result:= 'ftoRepeated';
    else begin
      raise EsmParserError.CreateFmt(RsErrBuild_UnknownFieldLabel,
        [FieldLabelToString(FieldLabel)]);
    end;
  end;

end;

function TsmDelphiBuilder.VariantToPasString(Value: Variant): string;
var
  SaveDecimalSeparator: Char;
begin

  case VarType(Value) of

    varShortInt, varSmallInt, varInteger, varLongWord, varInt64, varUInt64:
    begin
      Result:= IntToStr(Value);
    end;

    varSingle, varDouble, varCurrency:
    begin
      SaveDecimalSeparator:= FormatSettings.DecimalSeparator;
      try
        FormatSettings.DecimalSeparator:= '.';
        Result:= FloatToStr(Value);
      finally
        FormatSettings.DecimalSeparator:= SaveDecimalSeparator;
      end;
    end;

    varBoolean:
    begin
      if Boolean(Value) then Result:= 'True' else Result:= 'False';
    end;

    varString, varUString:
    begin
      Result:= '''' + Value + '''';
    end;

    else begin
      raise EsmParserError.CreateFmt(RsErrBuild_UnsupportedValueType,
        [VarTypeAsText(VarType(Value))]);
    end;

  end;

end;

end.
