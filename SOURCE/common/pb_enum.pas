unit pb_enum;

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
  pb_container, pb_options, pb_package, pb_base, pb_item;

const
  ENUM_ALLOW_ALIAS = 'allow_alias';

type

  TsmProtoEnumItem = record
    Name: string;
    Value: integer;
  end;

  TsmProtoEnum = class(TsmProtoItem)
  private
    FItems: TList<TsmProtoEnumItem>;
    FOptions: TsmProtoOptions;
  protected
    function GetBaseType: TsmProtoBaseFieldType; override;
  public
    constructor Create(ParentA: TsmProtoObject; NameA: string); override;
    destructor Destroy; override;
    procedure DoBindigns; override;
    function AddEnumItem(Name: string; Value: integer): integer;
    function FindEnumItem(Name: string): integer; overload;
    function FindEnumItem(Value: integer): integer; overload;
    function GetEnumValue(Name: string): integer;
    function IsAllowAlias: Boolean;
    property Items: TList<TsmProtoEnumItem> read FItems write FItems;
    property Options: TsmProtoOptions read FOptions;
  end;

implementation

uses errors;

{ TsmProtoEnum }

function TsmProtoEnum.AddEnumItem(Name: string; Value: integer): integer;
var
  Item: TsmProtoEnumItem;
begin

  if FindEnumItem(Name) <> -1 then begin
    raise EsmParserError.Create(Format(RsErr_DuplcateEnumName, [Name]));
  end;

  if (FindEnumItem(Value) <> -1) and (Not IsAllowAlias) then begin
    raise EsmParserError.Create(Format(RsErr_DuplcateEnumValue, [Value]));
  end;

  Item.Name:= Name;
  Item.Value:= Value;
  Result:= FItems.Add(Item);

end;

constructor TsmProtoEnum.Create(ParentA: TsmProtoObject; NameA: string);
begin
  inherited;
  FItems:= TList<TsmProtoEnumItem>.Create;
  FOptions:= TsmProtoOptions.Create(Self);
end;

destructor TsmProtoEnum.Destroy;
begin
  FItems.Free;
  FOptions.Free;
  inherited;
end;

procedure TsmProtoEnum.DoBindigns;
begin
  inherited;
  FOptions.DoBindings;
end;

function TsmProtoEnum.FindEnumItem(Value: integer): integer;
var
  I: integer;
begin
  Result:= -1;
  for I := 1 to FItems.Count do begin
    if FItems[I-1].Value = Value then begin
      Result:= I-1;
      break;
    end;
  end;
end;

function TsmProtoEnum.GetBaseType: TsmProtoBaseFieldType;
begin
  Result:= ftEnum;
end;

function TsmProtoEnum.GetEnumValue(Name: string): integer;
var
  Index: integer;
begin

  Index:= FindEnumItem(Name);

  if Index = -1 then begin
    raise EsmParserError.CreateFmt(RsErr_EnumItemNotFound, [Name, FullName]);
  end;

  Result:= Items[Index].Value;

end;

function TsmProtoEnum.IsAllowAlias: Boolean;
var
  Index: integer;
  OptionValue: TsmProtoConstantValue;
begin

  Index:= Options.FindByName(ENUM_ALLOW_ALIAS);

  if Index = -1 then begin
    Result:= False;
    Exit;
  end;

  OptionValue:= Options.Values[Index];
  if VarType(OptionValue.Value) <> varBoolean then begin
    raise EsmParserError.Create(RsErr_BadTypeAllowAlias);
  end;

  Result:= OptionValue.Value;

end;

function TsmProtoEnum.FindEnumItem(Name: string): integer;
var
  I: integer;
begin
  Result:= -1;
  for I := 1 to FItems.Count do begin
    if UpperCase(FItems[I-1].Name) = UpperCase(Name) then begin
      Result:= I-1;
      break;
    end;
  end;
end;

end.
