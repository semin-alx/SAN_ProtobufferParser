unit lexanalz;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Classes, System.Generics.Collections,
  System.Generics.Defaults, System.Character;

type

  TsmTokenType = (ttIdent, ttFullIdent, ttSpace1, ttString, ttSemicolon, ttDot,
    ttOpenCurlyBracket, ttCloseCurlyBracket, ttOpenParenthesis, ttCloseParenthesis,
    ttEquals, ttInteger, ttFloat, ttBoolean, ttOpenSquareBracket,
    ttCloseSquareBracket, ttCommentLine, ttCommentBlock, ttComma,
    ttMore, ttLess, ttEof);

  PsmProtoToken = ^TsmProtoToken;
  TsmProtoToken = record
    TokenType: TsmTokenType;
    PosStart: integer;
    PosEnd:   integer;
    Value: string;
  end;

  TsmLexicalItem = class(TObject)
  public
    function GetTokenMinLength: integer; virtual; abstract;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; virtual; abstract;
  end;

  TsmLexicalAnalyzer = class(TObject)
  private
    FReadTokens: TList<PsmProtoToken>;
    FReadIndex: integer;
    FText: string;
    FFileName: string;
    procedure ClearReadTokens;
    function ReadToken(var ReadIndex: integer): PsmProtoToken;
    function InternalNext: PsmProtoToken;
    function GetPosition: integer;
    function GetFromUtf8File(FileName: string): string;
    function GetFromAnsiFile(FileName: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(FileName: string; Utf8: Boolean);
    procedure Next;
    function GetToken(IndexToFuture: integer = 0): PsmProtoToken;
    function IsTokenIdent(IdentValue: string; IndexToFuture: integer = 0): Boolean;
    function IsToken(TokenType: TsmTokenType; IndexToFuture: integer = 0): Boolean;
    procedure GetLineFromPos(Pos: integer; var LineNum: integer; var PosOfLine: integer);
    property Position: integer read GetPosition; // 1,2,3...
    property FileName: string read FFileName;
  end;

implementation

uses errors;

var
  LexicalItems: TList<TsmLexicalItem>;

type

  TsmNumberSign = (nsPositive, nsNegative);

  // ќдносимвольные лексемы
  TsmLexOneChar = class(TsmLexicalItem)
  private
    FLexChar: Char;
    FTokenType: TsmTokenType;
  public
    constructor Create(LexChar: Char; TokenType: TsmTokenType);
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // »дентификатор
  TsmLexIdent = class(TsmLexicalItem)
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // –азделитель (ѕробел, переход на другую строку и т.д
  TsmLexSpace = class(TsmLexicalItem)
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // —трока в двойных кавычках
  TsmLexString = class(TsmLexicalItem)
  private
    FQuoteChar: Char;
  public
    constructor Create(Quote: Char);
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  TsmLexNumber = class(TsmLexicalItem)
  protected
    function GetValueSign(pText: PChar; var Index: integer): TsmNumberSign;
  end;

  // ÷елое число
  TsmLexInteger = class(TsmLexNumber)
  private
    function OctToInt64(V: string): Int64;
    function IsHexChar(C: Char): Boolean;
    function IsOctalChar(C: Char): Boolean;
    function isHexValue(pText: PChar; TextLen: integer; Index: integer): Boolean;
    function isOctalValue(pText: PChar; TextLen: integer; Index: integer): Boolean;
    function GetTokenFromHex(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken;
    function GetTokenFromOctal(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken;
    function GetTokenFromDecimal(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken;
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // Float
  TsmLexFloat = class(TsmLexNumber)
  private
    procedure SkipIntPart(pText: PChar; TextLen: integer; var Index: integer);
    function ReadFrqPart(pText: PChar; TextLen: integer; var Index: integer): Boolean;
    function ReadExpPart(pText: PChar; TextLen: integer; var Index: integer): Boolean;
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // ќднострочный комментарий
  TsmLexCommentLine = class(TsmLexicalItem)
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // Ѕлочный комментарий
  TsmLexCommentBlock = class(TsmLexicalItem)
  public
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  // fullIdent = ident { "." ident }
  TsmLexFullIdent = class(TsmLexicalItem)
  private
    FIdent: TsmLexIdent;
    FDot:   TsmLexOneChar;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

  TsmLexBoolean = class(TsmLexicalItem)
  private
    FIdent: TsmLexIdent;
  public
    constructor Create;
    destructor Destroy; override;
    function GetTokenMinLength: integer; override;
    function GetToken(pText: PChar; TextLen: integer; var Index: integer): PsmProtoToken; override;
  end;

procedure ClearLexicalItems;
var
  I: integer;
begin
  for I := 1 to LexicalItems.Count
    do LexicalItems.Items[I-1].Free;
  LexicalItems.Clear;
end;

procedure CreateLexicalItems;
begin
  LexicalItems.Add(TsmLexIdent.Create);
  LexicalItems.Add(TsmLexFullIdent.Create);
  LexicalItems.Add(TsmLexSpace.Create);
  LexicalItems.Add(TsmLexString.Create('"'));
  LexicalItems.Add(TsmLexString.Create(''''));
  LexicalItems.Add(TsmLexOneChar.Create(';', ttSemicolon));
  LexicalItems.Add(TsmLexOneChar.Create('.', ttDot));
  LexicalItems.Add(TsmLexOneChar.Create('{', ttOpenCurlyBracket));
  LexicalItems.Add(TsmLexOneChar.Create('}', ttCloseCurlyBracket));
  LexicalItems.Add(TsmLexOneChar.Create('[', ttOpenSquareBracket));
  LexicalItems.Add(TsmLexOneChar.Create(']', ttCloseSquareBracket));
  LexicalItems.Add(TsmLexOneChar.Create('=', ttEquals));
  LexicalItems.Add(TsmLexOneChar.Create('(', ttOpenParenthesis));
  LexicalItems.Add(TsmLexOneChar.Create(')', ttCloseParenthesis));
  LexicalItems.Add(TsmLexOneChar.Create(',', ttComma));
  LexicalItems.Add(TsmLexOneChar.Create('>', ttMore));
  LexicalItems.Add(TsmLexOneChar.Create('<', ttLess));
  LexicalItems.Add(TsmLexInteger.Create);
  LexicalItems.Add(TsmLexFloat.Create);
  LexicalItems.Add(TsmLexCommentLine.Create);
  LexicalItems.Add(TsmLexCommentBlock.Create);
  LexicalItems.Add(TsmLexBoolean.Create);
end;

procedure SortLexicalItems;
var
  Comparer: IComparer<TsmLexicalItem>;
begin

  Comparer := TDelegatedComparer<TsmLexicalItem>.Create(
    function(const Left, Right: TsmLexicalItem): Integer
    begin
      Result := -(Left.GetTokenMinLength - Right.GetTokenMinLength);
    end);

  LexicalItems.Sort(Comparer);

end;

{ TsmLexicalAnalyzer }

procedure TsmLexicalAnalyzer.ClearReadTokens;
var
  I: integer;
begin

  for I := 1 to FReadTokens.Count do begin
    Dispose(FReadTokens.Items[I-1]);
  end;

  FReadTokens.Clear;

end;

constructor TsmLexicalAnalyzer.Create;
begin
  FReadTokens:= TList<PsmProtoToken>.Create;
end;

destructor TsmLexicalAnalyzer.Destroy;
begin
  ClearReadTokens;
  FReadTokens.Free;
  inherited;
end;

function TsmLexicalAnalyzer.InternalNext: PsmProtoToken;
begin

  Result:= nil;

  while True do begin

    Result:= ReadToken(FReadIndex);

    if (Result^.TokenType = ttCommentLine)
      or (Result^.TokenType = ttCommentBlock)
      or (Result^.TokenType = ttSpace1)
    then begin
      Dispose(Result);
      Result:= nil;
      Continue;
    end else begin
      break;
    end;

  end;

end;

function TsmLexicalAnalyzer.IsToken(TokenType: TsmTokenType;
  IndexToFuture: integer): Boolean;
begin
  Result:= GetToken(IndexToFuture)^.TokenType = TokenType;
end;

function TsmLexicalAnalyzer.IsTokenIdent(IdentValue: string;
  IndexToFuture: integer): Boolean;
begin
  Result:= (GetToken(IndexToFuture)^.TokenType = ttIdent)
    and (LowerCase(GetToken(IndexToFuture)^.Value) = LowerCase(IdentValue));
end;

procedure TsmLexicalAnalyzer.Next;
begin

  if FReadTokens.Count > 0 then begin
    Dispose(FReadTokens.Items[0]);
    FReadTokens.Delete(0);
  end;

  if FReadTokens.Count = 0 then begin
    FReadTokens.Add(InternalNext);
  end;

end;

function TsmLexicalAnalyzer.ReadToken(var ReadIndex: integer): PsmProtoToken;
var
  pText: PChar;
  Len: integer;
  I: integer;
begin

  pText:= @FText[1];
  Len:= Length(FText);

  if (ReadIndex >= Len) then begin
    New(Result);
    Result^.TokenType:= ttEof;
    Result^.PosStart:= ReadIndex;
    Result^.PosEnd:= ReadIndex;
  end else begin

    for I := 1 to LexicalItems.Count do begin
      Result:= LexicalItems.Items[I-1].GetToken(pText, Len, ReadIndex);
      if Assigned(Result) then Exit;
    end;

    raise EsmParserError.CreateFmt(RsErr_IllegalCharacter, [FText[ReadIndex+1]]);

  end;

end;

function TsmLexicalAnalyzer.GetFromAnsiFile(FileName: string): string;
var
  StringStream: TStringStream;
begin

  StringStream:= TStringStream.Create;

  try
    StringStream.LoadFromFile(FileName);
    Result:= StringStream.DataString;
  finally
    StringStream.Free;
  end;

end;

function TsmLexicalAnalyzer.GetFromUtf8File(FileName: string): string;
var
  SourceStream: TBytesStream;
  Utf8Buffer: UTF8String;
begin

  SourceStream:= TBytesStream.Create;

  try
    SourceStream.LoadFromFile(FileName);
    SetLength(Utf8Buffer, SourceStream.Size);
    SourceStream.Read(Utf8Buffer[1], SourceStream.Size);
    Result:= Utf8ToWideString(Utf8Buffer);
  finally
    SourceStream.Free;
  end;

end;

procedure TsmLexicalAnalyzer.GetLineFromPos(Pos: integer; var LineNum,
  PosOfLine: integer);
var
  I: integer;
begin

  // Unix $A
  // Windows $A$D

  LineNum:= 1;
  PosOfLine:= 1;

  for I := 1 to Length(FText) do begin

    if I = Pos then break;

    if FText[I] = #$A then begin
      Inc(LineNum);
      PosOfLine:= 1;
    end else
    if FText[I] <> #$D then begin
      Inc(PosOfLine);
    end;

  end;

end;

function TsmLexicalAnalyzer.GetPosition: integer;
begin
  Result:= FReadIndex + 1;
end;

function TsmLexicalAnalyzer.GetToken(IndexToFuture: integer): PsmProtoToken;
var
  I: integer;
begin

  if IndexToFuture >= FReadTokens.Count then begin
    for I:= 1 to FReadTokens.Count - IndexToFuture + 1
      do FReadTokens.Add(InternalNext);
  end;

  Result:= FReadTokens.Items[IndexToFuture];

end;

procedure TsmLexicalAnalyzer.Start(FileName: string; Utf8: Boolean);
begin

  FFileName:= FileName;

  if Utf8 then begin
    FText:= GetFromUtf8File(FileName);
  end else begin
    FText:= GetFromAnsiFile(FileName);
  end;

  FReadIndex:= 0;
  ClearReadTokens;
  FReadTokens.Add(InternalNext);

end;

{ TsmLexicalIdentifier }

function TsmLexIdent.GetTokenMinLength: integer;
begin
  Result:= 1;
end;

function TsmLexIdent.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;

  function IsIdentifierChar(C: Char; isFirstChar: Boolean = False): Boolean;
  begin
    Result:= IsLetter(C);
    if Not isFirstChar then begin
      Result:= Result or IsDigit(C) or (C = '_');
    end;
  end;

begin

  // ident = letter { letter | decimalDigit | "_" }

  if Not IsIdentifierChar(pText[Index], True) then begin
    Result:= nil;
    Exit;
  end;

  nStart:= Index;
  nEnd:= nStart - 1;

  while Index < TextLen do begin

    if IsIdentifierChar(pText[Index]) then begin
      Inc(nEnd);
    end else begin
      break;
    end;

    Inc(Index);

  end;

  New(Result);
  Result.TokenType:= ttIdent;
  Result.PosStart:= nStart + 1;
  Result.PosEnd:= nEnd + 1;
  Result.Value:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);

end;

{ TsmLexSpace }

function TsmLexSpace.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;

  function IsSpaceChar(C: Char): Boolean;
  begin
    Result:= (C = #13) or (C = #10) or (C = #09) or (C = ' ');
  end;

begin

  if Not IsSpaceChar(pText[Index]) then begin
    Result:= nil;
    Exit;
  end;

  nStart:= Index;
  nEnd:= nStart - 1;

  while Index < TextLen do begin

    if IsSpaceChar(pText[Index]) then begin
      Inc(nEnd);
    end else begin
      break;
    end;

    Inc(Index);

  end;

  New(Result);
  Result.TokenType:= ttSpace1;
  Result.PosStart:= nStart + 1;
  Result.PosEnd:= nEnd + 1;
  Result.Value:= '<Space>';

end;

function TsmLexSpace.GetTokenMinLength: integer;
begin
  Result:= 1;
end;

{ TsmLexString }

constructor TsmLexString.Create(Quote: Char);
begin
  FQuoteChar:= Quote;
end;

function TsmLexString.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
begin

  if pText[Index] <> FQuoteChar then begin
    Result:= nil;
    Exit;
  end;

  nStart:= Index;
  Inc(Index);

  if Index = TextLen then begin
    raise EsmParserError.Create(RsErr_UnexpectedEndOfFile);
  end;

  nEnd:= Index-1;

  while Index < TextLen do begin

    if pText[Index] <> FQuoteChar then begin
      Inc(nEnd);
    end else begin
      break;
    end;

    Inc(Index);

  end;

  if pText[Index] <> FQuoteChar  then begin
    raise EsmParserError.Create(RsErr_UnexpectedEndOfFile);
  end;

  Inc(Index);

  New(Result);
  Result.TokenType:= ttString;
  Result.PosStart:= nStart + 2;
  Result.PosEnd:= nEnd + 1;
  Result.Value:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);

end;

function TsmLexString.GetTokenMinLength: integer;
begin
  Result:= 2;
end;

{ TsmLexOneChar }

constructor TsmLexOneChar.Create(LexChar: Char; TokenType: TsmTokenType);
begin
  FLexChar:= LexChar;
  FTokenType:= TokenType;
end;

function TsmLexOneChar.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
begin

  if pText[Index] = FLexChar then begin
    New(Result);
    Result.TokenType:= FTokenType;
    Result.PosStart:= Index + 1;
    Result.PosEnd:= Index + 1;
    Result.Value:= FLexChar;
    Inc(Index);
  end else begin
    Result:= nil;
  end;

end;

function TsmLexOneChar.GetTokenMinLength: integer;
begin
  Result:= 1;
end;

{ TsmLexNumber }

function TsmLexInteger.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  ValueSign: TsmNumberSign;
  NewIndex: integer;
begin

  // decimalDigit = "0" Е "9"
  // octalDigit   = "0" Е "7"
  // hexDigit     = "0" Е "9" | "A" Е "F" | "a" Е "f"

  // intLit     = decimalLit | octalLit | hexLit
  // decimalLit = ( "1" Е "9" ) { decimalDigit }
  // octalLit   = "0" { octalDigit }
  // hexLit     = "0" ( "x" | "X" ) hexDigit { hexDigit }

  NewIndex:= Index;

  ValueSign:= GetValueSign(pText, NewIndex);

  if NewIndex >= TextLen then begin
    Result:= nil;
    Exit;
  end;

  if isHexValue(pText, TextLen, NewIndex) then begin
    Result:= GetTokenFromHex(pText, TextLen, NewIndex);
  end else
  if isOctalValue(pText, TextLen, NewIndex) then begin
    Result:= GetTokenFromOctal(pText, TextLen, NewIndex);
  end else
  if IsDigit(pText[NewIndex]) then begin
    Result:= GetTokenFromDecimal(pText, TextLen, NewIndex);
  end else begin
    Result:= nil;
    Exit;
  end;

  if (ValueSign = nsNegative) then begin
    Result^.Value:= '-' + Result^.Value;
  end;

  Index:= NewIndex;

end;

function TsmLexInteger.GetTokenFromDecimal(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
begin

  nStart:= Index;
  nEnd:= Index - 1;

  while (Index < TextLen) and IsDigit(pText[Index]) do begin
    Inc(nEnd);
    Inc(Index);
  end;

  New(Result);
  Result^.TokenType:= ttInteger;
  Result^.PosStart:= nStart + 1;
  Result^.PosEnd:= nEnd + 1;

  Result^.Value:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);

end;

function TsmLexInteger.GetTokenFromHex(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
  HexValue: string;
  Value: Int64;
begin

  Inc(Index, 2); // Skip 0x

  nStart:= Index;
  nEnd:= Index - 1;

  while (Index < TextLen) and IsHexChar(pText[Index]) do begin
    Inc(nEnd);
    Inc(Index);
  end;

  New(Result);
  Result^.TokenType:= ttInteger;
  Result^.PosStart:= nStart + 1;
  Result^.PosEnd:= nEnd + 1;

  HexValue:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);
  Value:= StrToInt64('$' + HexValue);
  Result^.Value:= IntToStr(Value);

end;

function TsmLexInteger.GetTokenFromOctal(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
  OctalValue: string;
  Value: Int64;
begin

  Inc(Index, 1); // Skip 0

  nStart:= Index;
  nEnd:= Index - 1;

  while (Index < TextLen) and IsOctalChar(pText[Index]) do begin
    Inc(nEnd);
    Inc(Index);
  end;

  New(Result);
  Result^.TokenType:= ttInteger;
  Result^.PosStart:= nStart + 1;
  Result^.PosEnd:= nEnd + 1;

  OctalValue:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);
  Value:= OctToInt64(OctalValue);
  Result^.Value:= IntToStr(Value);

end;

function TsmLexInteger.GetTokenMinLength: integer;
begin
  Result:= 1;
end;

function TsmLexInteger.IsHexChar(C: Char): Boolean;
begin
  case C of
    'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f': Result:= True;
    else begin
      Result:= IsDigit(C);
    end;
  end;
end;

function TsmLexInteger.isHexValue(pText: PChar; TextLen,
  Index: integer): Boolean;
begin

  Result:= False;
  if (Index + 2 >= TextLen) then Exit;

  Result:= (pText[Index] = '0')
    and ((pText[Index+1] = 'x') or (pText[Index+1] = 'X'))
    and IsHexChar(pText[Index+2]);

end;

function TsmLexInteger.IsOctalChar(C: Char): Boolean;
begin
  case C of
    '0', '1', '2', '3', '4', '5' ,'6', '7': Result:= True;
    else Result:= False;
  end;
end;

function TsmLexInteger.isOctalValue(pText: PChar; TextLen,
  Index: integer): Boolean;
begin

  Result:= False;
  if (Index + 1 >= TextLen) then Exit;

  Result:= (pText[Index] = '0')
    and IsOctalChar(pText[Index+1]);

end;

function TsmLexInteger.OctToInt64(V: string): Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(V) do
  begin
    Result := Result * 8 + StrToInt(Copy(V, I, 1));
  end;
end;

{ TsmLexNumber }

function TsmLexNumber.GetValueSign(pText: PChar;
  var Index: integer): TsmNumberSign;
begin

  case pText[Index] of

    '-':
    begin
      Result:= nsNegative;
      Inc(Index);
    end;

    '+':
    begin
      Result:= nsPositive;
      Inc(Index);
    end;

    else
      Result:= nsPositive;

  end;

end;

{ TsmLexCommentLine }

function TsmLexCommentLine.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
begin

  if (Index + 1 < TextLen)
    and (pText[Index] = '/')
    and (pText[Index+1] = '/')
  then begin

    nStart:= Index;
    nEnd:= Index - 1;

    while (Index < TextLen) do begin
      if pText[Index] = #$A then begin
        if (Index + 1 < TextLen) and (pText[Index] = #$D) then begin
          Inc(Index);
          Inc(nEnd);
        end;
        break;
      end else begin
        Inc(Index);
        Inc(nEnd);
      end;
    end;

    New(Result);
    Result.TokenType:= ttCommentLine;
    Result.PosStart:= nStart + 1;
    Result.PosEnd:= nEnd + 1;
    Result.Value:= '';

  end else begin
    Result:= nil;
  end;

end;

function TsmLexCommentLine.GetTokenMinLength: integer;
begin
  Result:= 2;
end;

{ TsmLexCommentBlock }

function TsmLexCommentBlock.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  nStart, nEnd: integer;
begin

  if (Index + 1 < TextLen)
    and (pText[Index] = '/')
    and (pText[Index+1] = '*')
  then begin

    nStart:= Index;
    nEnd:= Index - 1;

    while (Index + 1 < TextLen) do begin
      if (pText[Index] = '*') and (pText[Index+1] = '/')
      then begin
        Inc(Index, 2);
        Inc(nEnd);
        break;
      end else begin
        Inc(Index);
        Inc(nEnd);
      end;
    end;

    New(Result);
    Result.TokenType:= ttCommentBlock;
    Result.PosStart:= nStart + 1;
    Result.PosEnd:= nEnd + 1;
    Result.Value:= '';

  end else begin
    Result:= nil;
  end;

end;

function TsmLexCommentBlock.GetTokenMinLength: integer;
begin
  Result:= 2;
end;

{ TsmLexFloat }

function TsmLexFloat.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  NewIndex: integer;
  ExistFrqPart: Boolean;
  ExistsExpPart: Boolean;
begin

  // 20.2e-5
  // 20e-5
  // -.2
  // .2e-5

  NewIndex:= Index;

  GetValueSign(pText, NewIndex);

  if NewIndex >= TextLen then begin
    Result:= nil;
    Exit;
  end;

  if not (IsDigit(pText[NewIndex]) or (pText[NewIndex] = '.')) then begin
    Result:= nil;
    Exit;
  end;

  SkipIntPart(pText, TextLen, NewIndex);
  ExistFrqPart:= ReadFrqPart(pText, TextLen, NewIndex);
  ExistsExpPart:= ReadExpPart(pText, TextLen, NewIndex);

  if (Not ExistFrqPart) and (Not ExistsExpPart) then begin
    Result:= nil;
    Exit;
  end;

  New(Result);
  Result^.TokenType:= ttFloat;
  Result^.PosStart:= Index + 1;
  Result^.PosEnd:= NewIndex;
  Result^.Value:= Copy(pText, Result.PosStart, Result.PosEnd - Result.PosStart + 1);

  Index:= NewIndex;

end;

function TsmLexFloat.GetTokenMinLength: integer;
begin
  Result:= 2;
end;

function TsmLexFloat.ReadExpPart(pText: PChar; TextLen: integer;
  var Index: integer): Boolean;
var
  NewIndex: integer;
begin

  Result:= False;
  if (pText[Index] <> 'e') and (pText[Index] <> 'E') then Exit;

  NewIndex:= Index;

  Inc(NewIndex);

  GetValueSign(pText, NewIndex);

  while (NewIndex < TextLen) and (isDigit(pText[NewIndex])) do begin
    Result:= True;
    Inc(NewIndex);
  end;

  if Result then Index:= NewIndex;

end;

function TsmLexFloat.ReadFrqPart(pText: PChar; TextLen: integer;
  var Index: integer): Boolean;
var
  NewIndex: integer;
begin

  Result:= False;
  if pText[Index] <> '.' then Exit;

  NewIndex:= Index;

  Inc(NewIndex);

  while (NewIndex < TextLen) and (isDigit(pText[NewIndex])) do begin
    Result:= True;
    Inc(NewIndex);
  end;

  if Result then Index:= NewIndex;

end;

procedure TsmLexFloat.SkipIntPart(pText: PChar; TextLen: integer;
  var Index: integer);
begin
  while (Index < TextLen) and (isDigit(pText[Index]))
    do Inc(Index);
end;

{ TsmLexFullIdent }

constructor TsmLexFullIdent.Create;
begin
  FIdent:= TsmLexIdent.Create;
  FDot:= TsmLexOneChar.Create('.', ttDot);
end;

destructor TsmLexFullIdent.Destroy;
begin
  FIdent.Free;
  FDot.Free;
  inherited;
end;

function TsmLexFullIdent.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  NewIndex1: integer;
  NewIndex2: integer;
  pNextIdentToken: PsmProtoToken;
  pDotToken: PsmProtoToken;
  PosEnd: integer;
begin

  NewIndex1:= Index;

  Result:= FIdent.GetToken(pText, TextLen, NewIndex1);
  if Not Assigned(Result) then Exit;

  pNextIdentToken:= nil;
  PosEnd:= 0;

  while True do begin

    // {.ident}

    NewIndex2:= NewIndex1;

    pDotToken:= FDot.GetToken(pText, TextLen, NewIndex2);
    if Assigned(pDotToken) then begin
      Dispose(pDotToken);
    end else begin
      break;
    end;

    pNextIdentToken:= FIdent.GetToken(pText, TextLen, NewIndex2);
    if Assigned(pNextIdentToken) then begin
      PosEnd:= pNextIdentToken^.PosEnd;
      Dispose(pNextIdentToken);
    end else begin
      break;
    end;

    NewIndex1:= NewIndex2;

  end;

  if Assigned(pNextIdentToken) then begin
    Index:= NewIndex1;
    Result^.TokenType:= ttFullIdent;
    Result^.PosEnd:= PosEnd;
    Result^.Value:= Copy(pText, Result^.PosStart,
                                   Result^.PosEnd
                                    - Result^.PosStart + 1);
  end else begin
    Dispose(Result);
    Result:= nil;
  end;

end;

function TsmLexFullIdent.GetTokenMinLength: integer;
begin
  Result:= 3; // Ќапример a.a
end;

{ TsmLexBoolean }

constructor TsmLexBoolean.Create;
begin
  FIdent:= TsmLexIdent.Create;
end;

destructor TsmLexBoolean.Destroy;
begin
  FIdent.Free;
  inherited;
end;

function TsmLexBoolean.GetToken(pText: PChar; TextLen: integer;
  var Index: integer): PsmProtoToken;
var
  NewIndex: integer;
  pIdent: PsmProtoToken;
  StrBool: string;
begin

  Result:= nil;

  NewIndex:= Index;
  pIdent:= FIdent.GetToken(pText, TextLen, NewIndex);

  if Assigned(pIdent) then begin
    StrBool:= LowerCase(pIdent^.Value);
    if (StrBool = 'true') or (StrBool = 'false') then begin
      Result:= pIdent;
      Result^.TokenType:= ttBoolean;
      Index:= NewIndex;
    end else begin
      Dispose(pIdent);
    end;
  end;

end;

function TsmLexBoolean.GetTokenMinLength: integer;
begin
  // true | false
  Result:= 4;
end;

initialization
  LexicalItems:= TList<TsmLexicalItem>.Create;
  CreateLexicalItems;
  SortLexicalItems;

finalization
  ClearLexicalItems;
  LexicalItems.Free;

end.
