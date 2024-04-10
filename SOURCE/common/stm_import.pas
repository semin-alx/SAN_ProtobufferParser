unit stm_import;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_container, pb_package, pb_item;

type

  TsmImportOption = (ioNone, ioWeak, ioPublic);

  TsmImportStatement = class(TsmMasterStatement)
  private
    procedure ImportProtoFile(FileName: string; Option: TsmImportOption);
    function StrToImportOption(Value: string): TsmImportOption;
    function IsAbsolutPath(Value: string): Boolean;
    function ParseProtoFile(FileName: string): TsmProtoPackage;
    function NormalizeFilePath(FilePath: string): string;
  public
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmImportStatement }

procedure TsmImportStatement.ImportProtoFile(FileName: string;
  Option: TsmImportOption);
var
  FullFileName: string;
  IsExistFile: Boolean;
  ImportPackage: TsmProtoPackage;
  I: integer;
begin

  if IsAbsolutPath(FileName) then begin
    FullFileName:= NormalizeFilePath(FileName);
    IsExistFile:= FileExists(FullFileName);
  end else begin

    FullFileName:= NormalizeFilePath(RootDir + '\' + FileName);
    IsExistFile:= FileExists(FullFileName);

    if Not IsExistFile then begin
      for I := 1 to Parser.SearchPath.Count do begin
        FullFileName:= NormalizeFilePath(Parser.SearchPath.Strings[I-1] + '\' + FileName);
        IsExistFile:= FileExists(FullFileName);
        if IsExistFile then break;
      end;
    end;

  end;

  if IsExistFile then begin

    ImportPackage:= ParseProtoFile(FullFileName);

    if Option = ioPublic then begin
      Container.AddPublicImport(Parser.Package, ImportPackage);
    end else begin
      ImportPackage:= Container.ImportRedirect(ImportPackage);
      Parser.Package.AddImport(ImportPackage);
    end;

  end else begin
    if Option <> ioWeak then begin
      raise EsmParserError.Create(Format(RsErr_FileNotFound, [FileName]));
    end;
  end;

end;

function TsmImportStatement.IsAbsolutPath(Value: string): Boolean;
begin
  Result:= (Pos(':', Value) <> 0) or ((Pos('\\', Value) = 1));
end;

function TsmImportStatement.NormalizeFilePath(FilePath: string): string;
begin
  Result:= StringReplace(FilePath, '/', '\', [rfReplaceAll]);
end;

function TsmImportStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
var
  ImportOption: TsmImportOption;
  FileName: string;
begin

  Result:= False;

  // import = "import" [ "weak" | "public" ] strLit ";"
  // strLit = ( "'" { charValue } "'" ) |  ( '"' { charValue } '"' )

  if (LexAnalyzer.GetToken^.TokenType = ttIdent)
    and (LowerCase(LexAnalyzer.GetToken^.Value) = 'import')
  then begin

    LexAnalyzer.Next; // import

    ImportOption:= ioNone;

    if LexAnalyzer.GetToken^.TokenType = ttIdent then begin
      ImportOption:= StrToImportOption(LexAnalyzer.GetToken^.Value);
      LexAnalyzer.Next;
    end;

    if LexAnalyzer.GetToken^.TokenType <> ttString then begin
      raise EsmParserError.Create(Format(RsErr_ExpectFileName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    FileName:= LexAnalyzer.GetToken^.Value;
    ImportProtoFile(FileName, ImportOption);

    LexAnalyzer.Next;

    if LexAnalyzer.GetToken^.TokenType <> ttSemicolon then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;

  end;

end;

function TsmImportStatement.ParseProtoFile(FileName: string): TsmProtoPackage;
var
  ParserA: TsmProtoBufParser;
begin

  ParserA:= TsmProtoBufParser.Create(RootDir);
  try
    ParserA.OnBeforeParse:= Parser.OnBeforeParse;
    ParserA.OnAfterParse:= Parser.OnAfterParse;
    ParserA.SourceUtf8:= Parser.SourceUtf8;
    ParserA.Parse(FileName, Container);
    Result:= Container.FindPackageByFileName(FileName);
  finally
    ParserA.Free;
  end;

end;

function TsmImportStatement.StrToImportOption(Value: string): TsmImportOption;
var
  StrOption: string;
begin

  StrOption:= LowerCase(Value);

  if StrOption = 'weak' then Result:= ioWeak
  else if StrOption = 'public' then Result:= ioPublic
  else
    raise EsmParserError.Create(Format(RsErr_InvalidImportOption, [StrOption]));

end;

end.
