unit stm_package;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_package, pb_container, pb_item;

type

  TsmPackageStatement = class(TsmMasterStatement)
  public
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmPackageStatement }

function TsmPackageStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  // package = "package" fullIdent ";"
  // fullIdent = ident { "." ident }

  Result:= False;

  if (LexAnalyzer.GetToken^.TokenType = ttIdent)
    and (LowerCase(LexAnalyzer.GetToken^.Value) = 'package')
  then begin

    LexAnalyzer.Next;

    if (LexAnalyzer.GetToken^.TokenType <> ttIdent)
      and (LexAnalyzer.GetToken^.TokenType <> ttFullIdent)
    then begin
      raise EsmParserError.Create(Format(RsErr_ExpectPackageName,
        [LexAnalyzer.GetToken^.Value]));
    end;

    Parser.Package.PackageName:= LexAnalyzer.GetToken^.Value;

    LexAnalyzer.Next;

    if (LexAnalyzer.GetToken^.TokenType <> ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;

  end;

end;

end.
