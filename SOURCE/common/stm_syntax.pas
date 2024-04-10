unit stm_syntax;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, parser, lexanalz, pb_container, pb_package, pb_base, pb_item;

type

  TsmSyntaxStatement = class(TsmMasterStatement)
  private
    function StrToVersion(Value: string): TsmSyntaxVersion;
  public
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmSyntaxStatement }

function TsmSyntaxStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  Result:= False;

  // syntax = "syntax" "=" ("'" "proto2" "'" | '"' "proto2" '"') ";"

  if (LexAnalyzer.GetToken^.TokenType = ttIdent)
    and (LowerCase(LexAnalyzer.GetToken^.Value) = 'syntax')
  then begin

    LexAnalyzer.Next; // skip syntax

    if (LexAnalyzer.GetToken^.TokenType <> ttEquals) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['=', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    if (LexAnalyzer.GetToken^.TokenType <> ttString) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectVersion,
        [LexAnalyzer.GetToken^.Value]));
    end;

    Parser.Package.Version:= StrToVersion(LexAnalyzer.GetToken^.Value);

    LexAnalyzer.Next;

    if (LexAnalyzer.GetToken^.TokenType <> ttSemicolon) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        [';', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;

  end;

end;

function TsmSyntaxStatement.StrToVersion(Value: string): TsmSyntaxVersion;
var
  ValueL: string;
begin

  ValueL:= LowerCase(Value);

  if ValueL = 'proto2' then Result:= svSyntax2
  else if ValueL = 'proto3' then Result:= svSyntax3
  else raise EsmParserError.Create(Format(RsErr_UnknownVersion, [ValueL]));

end;

end.
