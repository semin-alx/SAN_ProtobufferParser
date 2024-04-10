unit pb_base;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.Generics.Collections, lexanalz;

type

  TsmSyntaxVersion = (svSyntax2, svSyntax3);

  //type = "double" | "float" | "int32" | "int64" | "uint32" | "uint64"
  //     | "sint32" | "sint64" | "fixed32" | "fixed64" | "sfixed32" | "sfixed64"
  //     | "bool" | "string" | "bytes" | messageType | enumType
  TsmProtoBaseFieldType = (ftUndefined, ftDouble, ftFloat, ftInt32, ftInt64, ftUint32, ftUint64,
        ftSint32, ftSint64, ftFixed32, ftFixed64, ftSfixed32, ftSfixed64,
        ftBoolean, ftString, ftBytes, ftMessage, ftEnum);

  TsmProtoObject = class(TObject)
  private
    FOwner: TsmProtoObject;
    FChilds: TList<TsmProtoObject>;
    procedure Insert(Child: TsmProtoObject);
    procedure Remove(Child: TsmProtoObject);
    procedure RemoveChilds;
  public
    constructor Create(AOwner: TsmProtoObject);
    destructor Destroy; override;
    property Owner: TsmProtoObject read FOwner;
  end;

implementation

{ TsmProtoObject }

constructor TsmProtoObject.Create(AOwner: TsmProtoObject);
begin
  FOwner:= AOwner;
  FChilds:= nil;
  if Assigned(AOwner) then AOwner.Insert(Self);
end;


destructor TsmProtoObject.Destroy;
begin
  RemoveChilds;
  if Assigned(FOwner) then FOwner.Remove(Self);
  inherited;
end;

procedure TsmProtoObject.Insert(Child: TsmProtoObject);
begin
  if FChilds = nil then FChilds:= TList<TsmProtoObject>.Create;
  FChilds.Add(Child);
end;

procedure TsmProtoObject.Remove(Child: TsmProtoObject);
begin
  FChilds.Remove(Child);
end;

procedure TsmProtoObject.RemoveChilds;
begin
  if Assigned(FChilds) then begin
    while FChilds.Count > 0 do FChilds[0].Free;
  end;
  FChilds.Free;
  FChilds:= nil;
end;

end.
