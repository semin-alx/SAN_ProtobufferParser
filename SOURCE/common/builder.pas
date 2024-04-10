unit builder;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.Classes, System.SysUtils, pb_container;

type

  TsmBuilder = class(TObject)
  private
    FUtf8: Boolean;
    FStream: TStream;
    FFileName: string;
    FTabSize: integer;
    procedure WriteUTF8Preamble(Stream: TStream);
    procedure AddLineUtf8(S: string);
    procedure AddLineAnsi(S: string);
  protected
    procedure AddLine(S: string; Offset: integer = 0);
    procedure BuildData(Container: TsmProtoBufContainer); virtual; abstract;
    property FileName: string read FFileName;
  public
    constructor Create; virtual;
    procedure Build(Container: TsmProtoBufContainer; DestFileName: string);
    property Utf8: Boolean read FUtf8 write FUtf8;
    property TabSize: integer read FTabSize write FTabSize;
  end;

implementation

{ TsmBuilder }

procedure TsmBuilder.Build(Container: TsmProtoBufContainer;
  DestFileName: string);
var
  FileStream: TFileStream;
begin

  FFileName:= DestFileName;
  FileStream:= TFileStream.Create(FFileName, fmCreate);

  try
    if FUtf8 then WriteUTF8Preamble(FileStream);
    FStream:= FileStream;
    BuildData(Container);
  finally
    FileStream.Free;
  end;

end;

procedure TsmBuilder.AddLine(S: string; Offset: integer);
var
  S1: string;
begin

  S1:= StringOfChar(' ', Offset * FTabSize) + S + #13#10;

  if FUtf8 then begin
    AddLineUtf8(S1);
  end else begin
    AddLineAnsi(S1);
  end;
end;

procedure TsmBuilder.AddLineAnsi(S: string);
var
  S1: AnsiString;
begin
  S1:= AnsiString(S);
  FStream.Write((@S1[1])^, Length(S1));
end;

procedure TsmBuilder.AddLineUtf8(S: string);
var
  Buf: TBytes;
begin
  Buf:= TEncoding.UTF8.GetBytes(S);
  FStream.Write((@Buf[0])^, Length(Buf));
end;

constructor TsmBuilder.Create;
begin
  FUtf8:= False;
  FTabSize:= 2;
end;

procedure TsmBuilder.WriteUTF8Preamble(Stream: TStream);
var
  Preamble: TBytes;
begin
  Preamble:= TEncoding.UTF8.GetPreamble;
  Stream.Write((@Preamble[0])^, Length(Preamble));
end;

end.
