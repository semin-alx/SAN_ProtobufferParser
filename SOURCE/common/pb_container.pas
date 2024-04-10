unit pb_container;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Generics.Collections, pb_package, pb_base;

type

  TsmPublicImport = record
    OldPackage: TsmProtoPackage;
    RedirectTo: TsmProtoPackage;
  end;

  TsmProtoBufContainer = class(TsmProtoObject)
  private
    FPackages: TList<TsmProtoPackage>;
    FDefaultVersion: TsmSyntaxVersion;
    FPublicImports: TList<TsmPublicImport>;
    function GetPackageCount: integer;
    function GetPackage(Index: Integer): TsmProtoPackage;
    function FindPublicImport(Package: TsmProtoPackage): TsmProtoPackage;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function FindPackageByFileName(FileName: string): TsmProtoPackage;
    function AddPackage(FileName: string): TsmProtoPackage;
    procedure AddPublicImport(OldPackage: TsmProtoPackage; RedirectTo: TsmProtoPackage);
    function ImportRedirect(Package: TsmProtoPackage): TsmProtoPackage;
    property PackageCount: integer read GetPackageCount;
    property Packages[Index: Integer]: TsmProtoPackage read GetPackage;
    property DefaultVersion: TsmSyntaxVersion read FDefaultVersion write FDefaultVersion;
  end;

implementation

uses errors;

{ TsmProtoBufContainer }

function TsmProtoBufContainer.AddPackage(FileName: string): TsmProtoPackage;
begin
  Result:= FindPackageByFileName(FileName);
  if Not Assigned(Result) then begin
    Result:= TsmProtoPackage.Create(Self, FileName);
    Result.Version:= FDefaultVersion;
    FPackages.Add(Result);
  end;
end;

procedure TsmProtoBufContainer.AddPublicImport(OldPackage,
  RedirectTo: TsmProtoPackage);
var
  PublicImport: TsmPublicImport;
  EndPackage: TsmProtoPackage;
begin

  PublicImport.OldPackage:= OldPackage;
  PublicImport.RedirectTo:= RedirectTo;

  if PublicImport.OldPackage = PublicImport.RedirectTo then begin
    raise EsmParserError.CreateFmt(RsErr_PublicImportRefToSelf,
      [RedirectTo.FileName]);
  end;

  EndPackage:= ImportRedirect(RedirectTo);

  if EndPackage = OldPackage then begin
    raise EsmParserError.CreateFmt(RsErr_PublicImportCyclicalDependence,
      [RedirectTo.FileName]);
  end;

  FPublicImports.Add(PublicImport);

end;

procedure TsmProtoBufContainer.Clear;
var
  I: integer;
begin

  for I := 1 to FPackages.Count do begin
    FPackages.Items[I-1].Free;
  end;

  FPackages.Clear;
  FPublicImports.Clear;

end;

constructor TsmProtoBufContainer.Create;
begin
  inherited Create(nil);
  FPackages:= TList<TsmProtoPackage>.Create;
  FPublicImports:= TList<TsmPublicImport>.Create;
  FDefaultVersion:= svSyntax3;
end;

destructor TsmProtoBufContainer.Destroy;
begin
  Clear;
  FPublicImports.Free;
  FPackages.Free;
  inherited;
end;

function TsmProtoBufContainer.FindPackageByFileName(
  FileName: string): TsmProtoPackage;
var
  I: integer;
  FileNameL: string;
begin

  Result:= nil;
  FileNameL:= AnsiLowerCase(FileName);

  for I := 1 to FPackages.Count do begin
    if AnsiLowerCase(FPackages.Items[I-1].FileName) = FileNameL then begin
      Result:= FPackages.Items[I-1];
      break;
    end;
  end;

end;

function TsmProtoBufContainer.FindPublicImport(
  Package: TsmProtoPackage): TsmProtoPackage;
var
  I: integer;
begin
  Result:= nil;
  for I := 1 to FPublicImports.Count do begin
    if FPublicImports[I-1].OldPackage = Package then begin
      Result:= FPublicImports[I-1].RedirectTo;
      break;
    end;
  end;
end;

function TsmProtoBufContainer.GetPackage(Index: Integer): TsmProtoPackage;
begin
  Result:= FPackages.Items[Index];
end;

function TsmProtoBufContainer.GetPackageCount: integer;
begin
  Result:= FPackages.Count;
end;

function TsmProtoBufContainer.ImportRedirect(
  Package: TsmProtoPackage): TsmProtoPackage;
var
  DirectTo: TsmProtoPackage;
begin

  Result:= Package;

  while True do begin

    DirectTo:= FindPublicImport(Result);

    if Assigned(DirectTo) then begin
      if DirectTo = Package then begin
        raise EsmParserError.CreateFmt(RsErr_PublicImportCyclicalDependence,
          [Package.FileName]);
      end;
      Result:= DirectTo;
    end else begin
      break;
    end;

  end;

end;

end.
