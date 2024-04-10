unit pb_package;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.StrUtils, System.Generics.Collections, lexanalz,
  pb_base, pb_item, System.Variants, pb_options;

type

  TsmProtoTypeItem = record
    FullTypeName: string;
    pProtoType: TsmProtoItem;
  end;

  TsmProtoPackage = class(TsmProtoObject)
  private
    FFileName: string;
    FVersion: TsmSyntaxVersion;
    FPackageName: string;
    FItems: TList<TsmProtoItem>;
    FImportPakages: TList<TsmProtoPackage>;
    FTypes: TList<TsmProtoTypeItem>;
    FOptions: TsmProtoOptions;
    procedure ClearItems;
    function GetItem(Index: Integer): TsmProtoItem;
    function GetImportPackage(Index: Integer): TsmProtoPackage;
    procedure SetPackageName(const Value: string);
    procedure RecreateTypeList;
    procedure AddTypeToPackage(Item: TsmProtoItem);
    function IsRightIncludeStr(S: string; IncludedString: string): Boolean;
    function FindTypeInPackage(TypeName: string; Parent: TsmProtoItem = nil): integer;
    function FindTypeInImport(TypeName: string): TsmProtoItem;
  public

    constructor Create(AOwner: TsmProtoObject; FileName: string);
    destructor Destroy; override;

    function CreateItem(ItemClass: TsmProtoItemClass; Parent: TsmProtoItem;
      Name: string): TsmProtoItem;

    procedure AddImport(Package: TsmProtoPackage);

    function ItemCount: integer;
    function ImportPackageCount: integer;
    function FindType(Parent: TsmProtoItem; TypeName: string; IncludeImport: Boolean): TsmProtoItem;

    procedure Clear;
    procedure DoBindings;

    property FileName: string read FFileName;
    property Version: TsmSyntaxVersion read FVersion write FVersion;
    property PackageName: string read FPackageName write SetPackageName;
    property Items[Index: Integer]: TsmProtoItem read GetItem;
    property ImportPackages[Index: Integer]: TsmProtoPackage read GetImportPackage;
    property Options: TsmProtoOptions read FOptions;

  end;

implementation

uses errors, pb_utils;

{ TsmProtoPackage }

procedure TsmProtoPackage.AddImport(Package: TsmProtoPackage);
begin
  FImportPakages.Add(Package);
end;

procedure TsmProtoPackage.AddTypeToPackage(Item: TsmProtoItem);
var
  TypeItem: TsmProtoTypeItem;
begin
  TypeItem.FullTypeName:= PackageName + '.' + Item.Name;
  TypeItem.pProtoType:= Item;
  FTypes.Add(TypeItem);
end;

procedure TsmProtoPackage.Clear;
begin
  ClearItems;
  FImportPakages.Clear;
  FTypes.Clear;
end;

procedure TsmProtoPackage.ClearItems;
var
  I: integer;
begin

  for I := 1 to FItems.Count do begin
    FItems.Items[I-1].Free;
  end;

  FItems.Clear;

end;

constructor TsmProtoPackage.Create(AOwner: TsmProtoObject; FileName: string);
begin
  inherited Create(AOwner);
  FFileName:= FileName;
  FVersion:= svSyntax3;
  FPackageName:= '';
  FItems:= TList<TsmProtoItem>.Create;
  FImportPakages:= TList<TsmProtoPackage>.Create;
  FTypes:= TList<TsmProtoTypeItem>.Create;
  FOptions:= TsmProtoOptions.Create(Self);
end;

function TsmProtoPackage.CreateItem(ItemClass: TsmProtoItemClass;
  Parent: TsmProtoItem; Name: string): TsmProtoItem;
begin

  if Parent = nil then begin
    Result:= ItemClass.Create(Self, Name);
  end else begin
    Result:= ItemClass.Create(Parent, Name);
  end;

  FItems.Add(Result);
  AddTypeToPackage(Result);

end;

destructor TsmProtoPackage.Destroy;
begin
  Clear;
  FOptions.Free;
  FItems.Free;
  FImportPakages.Free;
  FTypes.Free;
  inherited;
end;

procedure TsmProtoPackage.DoBindings;
var
  Item: TsmProtoItem;
begin
  for Item in FItems
    do Item.DoBindigns;
end;

function TsmProtoPackage.FindTypeInImport(TypeName: string): TsmProtoItem;

type
  FoundTypeRec = record
    Filename: string;
    pProtoItem: TsmProtoItem;
  end;

var
  pProtoItem: TsmProtoItem;
  FoundTypes: array of FoundTypeRec;
  FoundCount: integer;
  I: integer;
  FileList: string;
  ErrMes: string;
begin

  SetLength(FoundTypes, ImportPackageCount);
  FoundCount:= 0;

  for I := 1 to ImportPackageCount do begin
    pProtoItem:= ImportPackages[I-1].FindType(nil, TypeName, False);
    if Assigned(pProtoItem) then begin
      Inc(FoundCount);
      FoundTypes[FoundCount-1].Filename:= ImportPackages[I-1].FileName;
      FoundTypes[FoundCount-1].pProtoItem:= pProtoItem;
    end;
  end;

  case FoundCount of
    0: Result:= nil;
    1: Result:= FoundTypes[0].pProtoItem;
    else begin
      // more than one type found (colision)
      FileList:= '';
      for I := 1 to FoundCount do begin
        FileList:= FileList + #13 + FoundTypes[I-1].Filename;
      end;
      ErrMes:= Format(RsErr_TypeColision, [TypeName]) + FileList + #13;
      raise EsmParserError.Create(ErrMes);
    end;
  end;

end;

function TsmProtoPackage.FindTypeInPackage(TypeName: string;
  Parent: TsmProtoItem): integer;
var
  I: integer;
begin

  Result:= -1;

  for I := 1 to FTypes.Count do begin
    if IsRightIncludeStr(FTypes[I-1].FullTypeName, TypeName) then begin
      if (Assigned(Parent) and (FTypes[I-1].pProtoType.Parent = Parent))
        or (Not Assigned(Parent))
      then begin
        Result:= I-1;
        break;
      end;
    end;
  end;

end;

function TsmProtoPackage.FindType(Parent: TsmProtoItem;
  TypeName: string; IncludeImport: Boolean): TsmProtoItem;
var
  TypeIndex: integer;
begin

  Result:= nil;
  TypeIndex:= -1;

  if Assigned(Parent) then begin
    TypeIndex:= FindTypeInPackage(TypeName, Parent);
  end;

  if (TypeIndex = -1) then begin
    TypeIndex:= FindTypeInPackage(TypeName);
  end;

  if TypeIndex <> -1 then begin
    Result:= FTypes[TypeIndex].pProtoType;
    exit;
  end;

  if IncludeImport then begin
    Result:= FindTypeInImport(TypeName);
  end;

end;

function TsmProtoPackage.GetImportPackage(Index: Integer): TsmProtoPackage;
begin
  Result:= FImportPakages[Index];
end;

function TsmProtoPackage.GetItem(Index: Integer): TsmProtoItem;
begin
  Result:= FItems[Index];
end;

function TsmProtoPackage.ImportPackageCount: integer;
begin
  Result:= FImportPakages.Count;
end;

function TsmProtoPackage.IsRightIncludeStr(S, IncludedString: string): Boolean;
var
  Ident1, Ident2: TsmFullIdentString;
begin

  Ident1:= TsmFullIdentString.Create(S);
  Ident2:= TsmFullIdentString.Create(IncludedString);

  try
    Result:= Ident1.IsInclude(Ident2);
  finally
    Ident1.Free;
    Ident2.free;
  end;

end;

function TsmProtoPackage.ItemCount: integer;
begin
  Result:= FItems.Count;
end;

procedure TsmProtoPackage.RecreateTypeList;
var
  I: integer;
begin
  FTypes.Clear;
  for I := 1 to ItemCount do AddTypeToPackage(Items[I-1]);
end;

procedure TsmProtoPackage.SetPackageName(const Value: string);
begin
  FPackageName := Value;
  RecreateTypeList;
end;

end.
