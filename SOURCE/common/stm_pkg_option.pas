unit stm_pkg_option;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses parser, lexanalz, pb_item, stm_option;

type
  TsmPackageOptionStatement = class(TsmMasterStatement)
  private
    FStmOption: TsmOptionStatement;
  public
    constructor Create(ParserA: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

{ TsmImportStatement }

constructor TsmPackageOptionStatement.Create(ParserA: TsmProtoBufParser);
begin
  inherited;
  FStmOption:= TsmOptionStatement.Create(ParserA);
end;

destructor TsmPackageOptionStatement.Destroy;
begin
  FStmOption.Free;
  inherited;
end;

function TsmPackageOptionStatement.Parse(Parent: TsmProtoItem;
  LexAnalyzer: TsmLexicalAnalyzer): Boolean;
begin

  Result:= FStmOption.Parse(Parent, LexAnalyzer);

  if Result then begin
    Parser.Package.Options.Add(FStmOption.Name, FStmOption.ConstantValue);
  end;

end;

end.
