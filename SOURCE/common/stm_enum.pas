unit stm_enum;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Variants, parser, lexanalz, pb_container,
  pb_enum, stm_option, stm_reserved, stm_enumfield, pb_package, pb_item;

type

  TsmEnumStatement = class(TsmMasterStatement)
  private
    FOptionStatement: TsmOptionStatement;
    FReservedStatement: TsmReservedStatement;
    FEnumFieldStatement: TsmEnumFieldStatement;
    function ParseEnumItem(LexAnalyzer: TsmLexicalAnalyzer; ProtoEnum: TsmProtoEnum): Boolean;
    procedure SetOption(ProtoEnum: TsmProtoEnum; OptionStatement: TsmOptionStatement);
    procedure SetEnumField(ProtoEnum: TsmProtoEnum; EnumFieldStatement: TsmEnumFieldStatement);
  public
    constructor Create(Parser: TsmProtoBufParser); override;
    destructor Destroy; override;
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; override;
  end;

implementation

uses errors;

{ TsmEnumStatement }

constructor TsmEnumStatement.Create(Parser: TsmProtoBufParser);
begin
  inherited;
  FOptionStatement:= TsmOptionStatement.Create(Parser);
  FReservedStatement:= TsmReservedStatement.Create(Parser);
  FEnumFieldStatement:= TsmEnumFieldStatement.Create(Parser);
end;

destructor TsmEnumStatement.Destroy;
begin
  FOptionStatement.Free;
  FReservedStatement.Free;
  FEnumFieldStatement.Free;
  inherited;
end;

function TsmEnumStatement.Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean;
var
  ProtoEnum: TsmProtoEnum;
begin

  Result:= False;

  // enum = "enum" enumName enumBody
  // enumBody = "{" { option | enumField | emptyStatement | reserved } "}"
  // enumField = ident "=" [ "-" ] intLit [ "[" enumValueOption { ","  enumValueOption } "]" ]";"
  // enumValueOption = optionName "=" constant
  // optionName = ( ident | "(" fullIdent ")" ) { "." ident }
  // constant = fullIdent | ( [ "-" | "+" ] intLit ) | ( [ "-" | "+" ] floatLit ) | strLit | boolLit

  if LexAnalyzer.IsTokenIdent('enum') then begin

    LexAnalyzer.Next; // skip enum

    if (Not LexAnalyzer.IsToken(ttIdent)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectEnumName, [LexAnalyzer.GetToken^.Value]));
    end;

    ProtoEnum:= TsmProtoEnum(Parser.Package.CreateItem(TsmProtoEnum, Parent,
      LexAnalyzer.GetToken^.Value));

    LexAnalyzer.Next;

    if (Not LexAnalyzer.IsToken(ttOpenCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['{', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    while Not ParseEnumItem(LexAnalyzer, ProtoEnum) do;

    if (Not LexAnalyzer.IsToken(ttCloseCurlyBracket)) then begin
      raise EsmParserError.Create(Format(RsErr_ExpectChar,
        ['}', LexAnalyzer.GetToken^.Value]));
    end;

    LexAnalyzer.Next;

    Result:= True;
  end;

end;

function TsmEnumStatement.ParseEnumItem(LexAnalyzer: TsmLexicalAnalyzer;
  ProtoEnum: TsmProtoEnum): Boolean;
begin

  // enumBody = "{" { option | enumField | emptyStatement | reserved } "}"

  Result:= False;

  case LexAnalyzer.GetToken^.TokenType of

    ttSemicolon:
    begin
      // Empty statement
      LexAnalyzer.Next;
    end;

    ttCloseCurlyBracket:
    begin
      Result:= True; // End fields
    end;

    ttEof:
    begin
      raise EsmParserError.Create(RsErr_UnexpectedEndOfFile);
    end;

    else begin
      if FOptionStatement.Parse(ProtoEnum, LexAnalyzer) then begin
        SetOption(ProtoEnum, FOptionStatement);
      end else
      if FReservedStatement.Parse(ProtoEnum, LexAnalyzer) then begin
        // skip
      end else begin
        FEnumFieldStatement.Parse(ProtoEnum, LexAnalyzer);
        SetEnumField(ProtoEnum, FEnumFieldStatement);
      end;
    end;

  end;

end;

procedure TsmEnumStatement.SetEnumField(ProtoEnum: TsmProtoEnum;
  EnumFieldStatement: TsmEnumFieldStatement);
begin
  ProtoEnum.AddEnumItem(EnumFieldStatement.Name, EnumFieldStatement.Value);
end;

procedure TsmEnumStatement.SetOption(ProtoEnum: TsmProtoEnum;
  OptionStatement: TsmOptionStatement);
begin

  if OptionStatement.Name = ENUM_ALLOW_ALIAS then begin
    if VarType(OptionStatement.ConstantValue.Value) <> varBoolean then begin
      raise EsmParserError.Create(Format(RsErr_ExpectBooleanType,
        [OptionStatement.Name]));
    end;
  end;

  ProtoEnum.Options.Add(OptionStatement.Name,
                        OptionStatement.ConstantValue);

end;

end.
