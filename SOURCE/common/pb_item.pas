unit pb_item;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, pb_base;

type

  TsmProtoItem = class;

  TsmProtoCustomPackage = class(TsmProtoObject)
  public
    function FindType(Parent: TsmProtoItem; TypeName: string; IncludeImport: Boolean): TsmProtoItem; virtual; abstract;
    function GetPackageName: string; virtual; abstract;
  end;

  TsmProtoItem = class(TsmProtoObject)
  private
    FParent: TsmProtoItem;
    FName: string;
    FFullName: string;
    FPackage: TsmProtoObject;
    function GetName: string;
    function GetFullName: string;
  protected
    function GetBaseType: TsmProtoBaseFieldType; virtual; abstract;
  public
    constructor Create(ParentA: TsmProtoObject; NameA: string); virtual;
    function FindType(TypeName: string; IncludeImport: Boolean): TsmProtoItem;
    procedure DoBindigns; virtual;
    property Parent: TsmProtoItem read FParent;
    property Name: string read GetName;
    property FullName: string read FFullName;
    property BaseType: TsmProtoBaseFieldType read GetBaseType;
  end;

  TsmProtoItemClass = class of TsmProtoItem;

implementation

uses pb_package;

{ TsmProtoItem }

constructor TsmProtoItem.Create(ParentA: TsmProtoObject; NameA: string);
begin

  if ParentA is TsmProtoItem then begin
    FParent:= TsmProtoItem(ParentA);
    FPackage:= FParent.FPackage;
  end else
  if ParentA is TsmProtoPackage then begin
    FParent:= nil;
    FPackage:= TsmProtoPackage(ParentA);
  end else begin
    raise Exception.Create('Invalid parent');
  end;

  inherited Create(FPackage);

  FName:= NameA;
  FFullName:= GetFullName;

end;

procedure TsmProtoItem.DoBindigns; begin end;

function TsmProtoItem.FindType(TypeName: string;
  IncludeImport: Boolean): TsmProtoItem;
begin
  Result:= TsmProtoPackage(FPackage).FindType(Self, TypeName, IncludeImport);
end;

function TsmProtoItem.GetFullName: string;
begin
  if TsmProtoPackage(FPackage).PackageName = '' then begin
    Result:= Name;
  end else begin
    Result:= TsmProtoPackage(FPackage).PackageName + '.' + Name;
  end;
end;

function TsmProtoItem.GetName: string;
begin
  if Assigned(FParent) then begin
    Result:= FParent.Name + '.' + FName;
  end else begin
    Result:= FName;
  end;
end;

end.
