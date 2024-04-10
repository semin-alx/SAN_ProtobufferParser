unit enum_files;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

//    Класс реализует рекурсивный перебор файлов в уаказанной
//    директории.

interface

uses System.SysUtils;

type

  TsmEnumFileEvent = procedure (Sender: TObject; FileName: string) of object;

  TsmEnumFiles = class(TObject)
  private
    FOnEnumFile: TsmEnumFileEvent;
  protected
    procedure DoEnumFile(FileName: string); virtual;
  public
    procedure StartEnum(RootDir: string);
    property OnEnumFile: TsmEnumFileEvent read FOnEnumFile write FOnEnumFile;
  end;

implementation

{ TsmEnumFiles }

procedure TsmEnumFiles.DoEnumFile(FileName: string);
begin
  if Assigned(FOnEnumFile) then FOnEnumFile(Self, FileName);
end;

procedure TsmEnumFiles.StartEnum(RootDir: string);
var
  Rec: TSearchRec;
  isFound: boolean;
begin

  isFound:= FindFirst(RootDir + '\*.*', faAnyFile, Rec) = 0;

  while isFound do
  begin
    if (Rec.Name <> '.') and (Rec.Name <> '..') then begin
      if(Rec.Attr and faDirectory) = faDirectory then begin
        StartEnum(RootDir + '\' + Rec.Name); // Рекурсия
      end else begin
        DoEnumFile(RootDir + '\' + Rec.Name);
      end;
    end;
    isFound := FindNext(Rec) = 0;
  end;

  FindClose(Rec);

end;

end.
