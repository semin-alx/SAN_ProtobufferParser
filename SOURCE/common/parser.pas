unit parser;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

uses System.SysUtils, System.Classes, System.Generics.Collections, pb_container,
  lexanalz, pb_package, pb_item, pb_message, errors;

type

  TsmProtoBufParser = class;

  TsmStatement = class(TObject)
  private
    FParser: TsmProtoBufParser;
    function GetContainer: TsmProtoBufContainer;
    function GetRootDir: string;
  protected
    property Parser: TsmProtoBufParser read FParser;
    property Container: TsmProtoBufContainer read GetContainer;
    property RootDir: string read GetRootDir;
  public
    constructor Create(ParserA: TsmProtoBufParser); virtual;
  end;

  TsmContextStatement = class(TsmStatement)
  public
    procedure Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer); virtual; abstract;
  end;

  TsmSlaveStatement = class(TsmStatement)
  public
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; virtual; abstract;
  end;

  TsmMasterStatement = class(TsmStatement)
  public
    function Parse(Parent: TsmProtoItem; LexAnalyzer: TsmLexicalAnalyzer): Boolean; virtual; abstract;
  end;

  TsmMasterStatementClass = class of TsmMasterStatement;

  TsmProtoBufParser = class(TObject)
  private
    FLexAnalyzer: TsmLexicalAnalyzer;
    FStatements: TList<TsmMasterStatement>;
    FRootDir: string;
    FPackage: TsmProtoPackage;
    FContainer: TsmProtoBufContainer;
    FSourceUtf8: Boolean;
    FOnBeforeParse: TNotifyEvent;
    FOnAfterParse: TNotifyEvent;
    FSearchPath: TStrings;
    procedure FreeStatements;
    procedure CreateStatements;
    procedure SetErrPosition(E: EsmParserError);
    procedure ParseStatements;
    procedure SetSearchPath(const Value: TStrings);
  public
    constructor Create(RootDir: string);
    destructor Destroy; override;
    procedure Parse(ProtoFile: string; Dest: TsmProtoBufContainer);
    property RootDir: string read FRootDir write FRootDir;
    property SearchPath: TStrings read FSearchPath write SetSearchPath;
    property Package: TsmProtoPackage read FPackage;
    property SourceUtf8: Boolean read FSourceUtf8 write FSourceUtf8;
    property OnBeforeParse: TNotifyEvent read FOnBeforeParse write FOnBeforeParse;
    property OnAfterParse: TNotifyEvent read FOnAfterParse write FOnAfterParse;
  end;

procedure RegisterStatmentClass1(StatementClass: TsmMasterStatementClass);

implementation

var
  RegisterStatmentClasses: TList<TsmMasterStatementClass>;

procedure RegisterStatmentClass1(StatementClass: TsmMasterStatementClass);
begin
  RegisterStatmentClasses.Add(StatementClass);
end;

{ TsmProtoBufParser }

constructor TsmProtoBufParser.Create(RootDir: string);
begin
  FPackage:= nil;
  FContainer:= nil;
  FOnBeforeParse:= nil;
  FOnAfterParse:= nil;
  FRootDir:= RootDir;
  FSourceUtf8:= True;
  FLexAnalyzer:= TsmLexicalAnalyzer.Create;
  FStatements:= TList<TsmMasterStatement>.Create;
  FSearchPath:= TStringList.Create;
  CreateStatements;
end;

procedure TsmProtoBufParser.CreateStatements;
var
  I: integer;
  Stm: TsmMasterStatement;
begin

  for I := 1 to RegisterStatmentClasses.Count do begin
    Stm:= RegisterStatmentClasses.Items[I-1].Create(Self);
    FStatements.Add(Stm);
  end;

end;

destructor TsmProtoBufParser.Destroy;
begin
  FSearchPath.Free;
  FreeStatements;
  FStatements.Free;
  FLexAnalyzer.Free;
  inherited;
end;

procedure TsmProtoBufParser.FreeStatements;
var
  I: integer;
begin
  for I := 1 to FStatements.Count do FStatements.Items[I-1].Free;
  FStatements.Clear;
end;

procedure TsmProtoBufParser.Parse(ProtoFile: string;
  Dest: TsmProtoBufContainer);
begin

  FPackage:= Dest.FindPackageByFileName(ProtoFile);
  FContainer:= Dest;

  if Not Assigned(FPackage) then begin

    if Assigned(FOnBeforeParse) then FOnBeforeParse(Self);

    FPackage:= Dest.AddPackage(ProtoFile);
    FLexAnalyzer.Start(ProtoFile, FSourceUtf8);

    try
      ParseStatements;
      FPackage.DoBindings;
    except
      on E: EsmParserError do begin
        SetErrPosition(E);
        raise;
      end;
    end;

    if Assigned(FOnAfterParse) then FOnAfterParse(Self);
  end;

end;

procedure TsmProtoBufParser.ParseStatements;
var
  I: integer;
  Position: integer;
begin

  while (FLexAnalyzer.GetToken^.TokenType <> ttEof) do begin

    Position:= FLexAnalyzer.Position;

    for I := 1 to FStatements.Count do begin
      if FStatements.Items[I-1].Parse(nil, FLexAnalyzer) then break;
    end;

    if Position = FLexAnalyzer.Position then begin
      raise EsmParserError.CreateFmt(RsErr_UnknownKeyword,[FLexAnalyzer.GetToken^.Value]);
    end;

  end;

end;

procedure TsmProtoBufParser.SetErrPosition(E: EsmParserError);
var
  Position: TsmParserPosition;
begin

  if E.IsNotSetPosition then begin

    E.PosOfFile1:= FLexAnalyzer.GetToken^.PosStart;
    E.PosOfFile2:= FLexAnalyzer.GetToken^.PosEnd;

    Position.FileName:= FLexAnalyzer.FileName;
    FLexAnalyzer.GetLineFromPos(E.PosOfFile1, Position.LineNum1, Position.PosOfLine1);
    FLexAnalyzer.GetLineFromPos(E.PosOfFile2, Position.LineNum2, Position.PosOfLine2);

    E.SetPosition(Position);
    E.Message:= Format(RsErr_ErrorMessage,
      [E.Message, Position.LineNum1, Position.PosOfLine1, Position.FileName]);

  end;

end;

procedure TsmProtoBufParser.SetSearchPath(const Value: TStrings);
begin
  FSearchPath.Assign(Value);
end;

{ TsmStatement }

constructor TsmStatement.Create(ParserA: TsmProtoBufParser);
begin
  FParser:= ParserA;
end;

function TsmStatement.GetContainer: TsmProtoBufContainer;
begin
  Result:= FParser.FContainer;
end;

function TsmStatement.GetRootDir: string;
begin
  Result:= FParser.FRootDir;
end;

initialization
   RegisterStatmentClasses:= TList<TsmMasterStatementClass>.Create;

finalization
   RegisterStatmentClasses.Free;

end.
