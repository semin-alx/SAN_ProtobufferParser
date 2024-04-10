unit pb_options;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, lexanalz, pb_base,
  pb_item;

type

  TsmProtoConstantValue = record
    Token: TsmProtoToken;
    Value: Variant;
  end;

  TsmProtoOptionPair = record
    Name: string;
    Value: TsmProtoConstantValue;
  end;

  TsmProtoOptions = class(TsmProtoObject)
  private
    FParent: TsmProtoItem;
    FOptions: TList<TsmProtoOptionPair>;
    function GetName(Index: integer): string;
    function GetValueByIndex(Index: integer): TsmProtoConstantValue;
    function GetValueByName(Name: string): TsmProtoConstantValue;
    function GetParent: TsmProtoItem;
    function Bind(Option: TsmProtoOptionPair): TsmProtoOptionPair;
  public
    constructor Create(AOwner: TsmProtoObject);
    destructor Destroy; override;
    procedure Add(Name: string; ConstantValue: TsmProtoConstantValue);
    procedure DoBindings;
    function Count: integer;
    function FindByName(Name: string): integer;
    procedure Clear;
    procedure Assign(Source: TsmProtoOptions);
    property Names[Index: integer]: string read GetName;
    property Values[Index: integer]: TsmProtoConstantValue read GetValueByIndex;
    property Options[Name: string]: TsmProtoConstantValue read GetValueByName;
  end;

implementation

uses errors, pb_utils, pb_enum, pb_message;

{ TsmProtoOptions }

procedure TsmProtoOptions.Add(Name: string; ConstantValue: TsmProtoConstantValue);
var
  Pair: TsmProtoOptionPair;
begin
  if FindByName(Name) = -1 then begin
    Pair.Name:= Name;
    Pair.Value:= ConstantValue;
    FOptions.Add(Pair);
  end else begin
    raise EsmParserError.Create(Format(RsErr_DuplicateOptionName, [Name]));
  end;
end;

procedure TsmProtoOptions.Assign(Source: TsmProtoOptions);
var
  I: integer;
begin
  Clear;
  for I := 1 to Source.Count do begin
    FOptions.Add(Source.FOptions[I-1]);
  end;
end;

function TsmProtoOptions.Bind(Option: TsmProtoOptionPair): TsmProtoOptionPair;
var
  EnumType: TsmProtoEnum;
  EnumTypeName: string;
  EnumItemName: string;
  ItemType: TsmProtoItem;
begin

  Result:= Option;
  EnumType:= nil;

  if Option.Value.Token.TokenType = ttFullIdent then begin

    ExtractLastPart(Option.Value.Token.Value, EnumTypeName, EnumItemName);
    ItemType:= FParent.FindType(EnumTypeName, True);

    if Not Assigned(ItemType) then begin
      raise EsmParserError.CreateByToken(Option.Value.Token,
        Format(RsErr_UnknownIdentifier, [Option.Value.Token.Value]));
    end;

    if Not (ItemType is TsmProtoEnum) then begin
      raise EsmParserError.CreateByToken(Option.Value.Token,
        Format(RsErr_ExpectEnumType, [ItemType.FullName]));
    end;

    EnumType:= TsmProtoEnum(ItemType);

  end else
  if Option.Value.Token.TokenType = ttIdent then begin
    if (Owner is TsmProtoNormalField)
       and Assigned(TsmProtoNormalField(Owner).FieldType.CustomType)
       and (TsmProtoNormalField(Owner).FieldType.CustomType is TsmProtoEnum)
    then begin
      EnumType:= TsmProtoEnum(TsmProtoNormalField(Owner).FieldType.CustomType);
      EnumItemName:= Option.Value.Token.Value;
    end else begin
      raise EsmParserError.CreateByToken(Option.Value.Token,
        Format(RsErr_UnknownIdentifier, [Option.Value.Token.Value]));
    end;
  end;

  if Assigned(EnumType) then begin
    try
      Result.Value.Value:= EnumType.GetEnumValue(EnumItemName);
    except
      on E: EsmParserError do begin
        raise EsmParserError.CreateByToken(Option.Value.Token, E.Message);
      end;
    end;
  end;

end;

procedure TsmProtoOptions.Clear;
begin
  FOptions.Clear;
end;

function TsmProtoOptions.Count: integer;
begin
  Result:= FOptions.Count;
end;

constructor TsmProtoOptions.Create(AOwner: TsmProtoObject);
begin
  inherited Create(AOwner);
  FParent:= GetParent;
  FOptions:= TList<TsmProtoOptionPair>.Create;
end;

destructor TsmProtoOptions.Destroy;
begin
  FOptions.Free;
  inherited;
end;

procedure TsmProtoOptions.DoBindings;
var
  I: integer;
begin
  for I := 1 to FOptions.Count do begin
    FOptions[I-1]:= Bind(FOptions[I-1]);
  end;
end;

function TsmProtoOptions.FindByName(Name: string): integer;
var
  I: integer;
begin
  Result:= -1;
  for I := 1 to FOptions.Count do begin
    if FOptions[I-1].Name = Name then begin
      Result:= I-1;
      break;
    end;
  end;
end;

function TsmProtoOptions.GetName(Index: integer): string;
begin
  Result:= FOptions.Items[Index].Name;
end;

function TsmProtoOptions.GetParent: TsmProtoItem;
var
  P: TsmProtoObject;
begin

  Result:= nil;
  P:= Self.Owner;

  while P <> nil do begin
    if P is TsmProtoItem then begin
      Result:= TsmProtoItem(P);
      break;
    end else begin
      P:= P.Owner;
    end;
  end;

end;

function TsmProtoOptions.GetValueByIndex(Index: integer): TsmProtoConstantValue;
begin
  Result:= FOptions.Items[Index].Value;
end;

function TsmProtoOptions.GetValueByName(Name: string): TsmProtoConstantValue;
var
  Index: integer;
begin

  Index:= FindByName(Name);
  if Index = -1 then begin
    raise EsmParserError.Create(Format(RsErr_OptionNotFound, [Name]));
  end else begin
    Result:= Values[Index];
  end;

end;

end.
