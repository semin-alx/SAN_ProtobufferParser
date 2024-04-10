unit fMain;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

{$WARN UNIT_PLATFORM OFF}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons, Vcl.ComCtrls, pb_package,
  pb_container, enum_files, parser, reg_statements, bld_delphi, pb_base;

type

  TSourceType = (stDirectory = 0, stProtoFile = 1);

  TfrmMain = class(TForm)
    rgSourceType: TRadioGroup;
    Label1: TLabel;
    edtSource: TEdit;
    btnSelectSource: TButton;
    Label2: TLabel;
    edtOutput: TEdit;
    btnSelectOutput: TButton;
    rgProtoVersion: TRadioGroup;
    btnParse: TButton;
    sdOutput: TSaveDialog;
    odSourceFile: TOpenDialog;
    Label3: TLabel;
    reLog: TRichEdit;
    cbOutputUtf8: TCheckBox;
    Label4: TLabel;
    lbxSearchPath: TListBox;
    btnSearchPathAdd: TBitBtn;
    btnSearchPathRemove: TBitBtn;
    procedure btnSelectSourceClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnSelectOutputClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnParseClick(Sender: TObject);
    procedure btnSearchPathAddClick(Sender: TObject);
    procedure btnSearchPathRemoveClick(Sender: TObject);
  private
    FEnumFiles: TsmEnumFiles;
    FParser: TsmProtoBufParser;
    FContainer: TsmProtoBufContainer;
    FBuilder: TsmDelphiBuilder;
    FParsedFileCount: integer;
    function GetDefaultVersion: TsmSyntaxVersion;
    function GetSourceType: TSourceType;
    procedure SelectSourceDir;
    procedure SelectProtoFile;
    procedure SelectOutput;
    procedure AddLog(Text: string; Color: TColor = clBlack);
    procedure ParseFile(Sender: TObject; FileName: string);
    procedure DoSuccParseFile(Sender: TObject);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses FileCtrl;

{$R *.dfm}

resourcestring
  RSSelectSourceDir = 'Select source directory';
  RSSelectSearchDir = 'Select search directory';
  RSResultInfo = '%d files was parsed successfully. Output: %s';
  RSAppName = 'ProtoBufParser for Delphi v.1.0';

{ TfrmMain }

procedure TfrmMain.AddLog(Text: string; Color: TColor);
begin
  reLog.SelStart:= Length(reLog.Text);
  reLog.SelAttributes.Color:= Color;
  reLog.Lines.Add(Text);
  SendMessage(reLog.Handle, EM_SCROLL, SB_BOTTOM, 0);
end;

procedure TfrmMain.btnParseClick(Sender: TObject);
begin

  FContainer.Clear;
  FContainer.DefaultVersion:= GetDefaultVersion;
  reLog.Clear;
  FParsedFileCount:= 0;

  try

    case GetSourceType of
      stDirectory:
      begin
        FEnumFiles.OnEnumFile:= ParseFile;
        FEnumFiles.StartEnum(edtSource.Text);
      end;
      stProtoFile: ParseFile(nil, edtSource.Text);
    end;

    FBuilder.Utf8:= cbOutputUtf8.Checked;
    FBuilder.Build(FContainer, edtOutput.Text);

    AddLog('');
    AddLog(Format(RSResultInfo, [FParsedFileCount, edtOutput.Text]));

  except
    on E: Exception do begin
      AddLog('');
      AddLog(E.Message, clRed);
    end;
  end;

end;

procedure TfrmMain.btnSearchPathAddClick(Sender: TObject);
var
  Dir: string;
begin

  Dir:= '';

  if lbxSearchPath.ItemIndex <> -1 then begin
    Dir:= lbxSearchPath.Items[lbxSearchPath.ItemIndex];
  end;

  if SelectDirectory(RSSelectSearchDir, '', Dir) then begin
    if lbxSearchPath.Items.IndexOf(Dir) = -1 then begin
      lbxSearchPath.Items.Add(Dir);
      lbxSearchPath.ItemIndex:= lbxSearchPath.Items.Count - 1;
    end;
    FParser.SearchPath.Assign(lbxSearchPath.Items);
  end;

end;

procedure TfrmMain.btnSearchPathRemoveClick(Sender: TObject);
begin
  if lbxSearchPath.ItemIndex <> -1 then begin
    lbxSearchPath.Items.Delete(lbxSearchPath.ItemIndex);
  end;
end;

procedure TfrmMain.btnSelectOutputClick(Sender: TObject);
begin
  SelectOutput;
end;

procedure TfrmMain.btnSelectSourceClick(Sender: TObject);
begin
  case GetSourceType of
    stDirectory: SelectSourceDir;
    stProtoFile: SelectProtoFile;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin

  Caption:= RSAppName;

  FEnumFiles:= TsmEnumFiles.Create;

  FParser:= TsmProtoBufParser.Create('');
  FParser.OnAfterParse:= DoSuccParseFile;

  FContainer:= TsmProtoBufContainer.Create;

  FBuilder:= TsmDelphiBuilder.Create;
  FBuilder.AppName:= RSAppName;

  //----------------------------------
  //edtSource.Text:= 'C:\Smn_work_2\DelphiXE2\PROJECTS\ProtobufferParser\Tests\Data\Kontur\proto';
  edtSource.Text:= '';
  edtOutput.Text:= 'proto.pas';
  FParser.RootDir:= edtSource.Text;
  //----------------------------------

end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FBuilder.Free;
  FContainer.Free;
  FParser.Free;
  FEnumFiles.Free;
end;

function TfrmMain.GetDefaultVersion: TsmSyntaxVersion;
begin
  if rgProtoVersion.ItemIndex = 0 then begin
    Result:= svSyntax2;
  end else begin
    Result:= svSyntax3;
  end;
end;

function TfrmMain.GetSourceType: TSourceType;
begin
  Result:= TSourceType(rgSourceType.ItemIndex);
end;

procedure TfrmMain.DoSuccParseFile(Sender: TObject);
begin
  Inc(FParsedFileCount);
  AddLog('OK ' + TsmProtoBufParser(Sender).Package.FileName, clGreen);
end;

procedure TfrmMain.ParseFile(Sender: TObject; FileName: string);
begin
  FParser.Parse(FileName, FContainer);
end;

procedure TfrmMain.SelectOutput;
begin
  if sdOutput.Execute(Handle) then begin
    edtOutput.Text:= sdOutput.FileName;
  end;
end;

procedure TfrmMain.SelectProtoFile;
begin
  if odSourceFile.Execute(Handle) then begin
    edtSource.Text:= odSourceFile.FileName;
    FParser.RootDir:= '';
  end;
end;

procedure TfrmMain.SelectSourceDir;
var
  Dir: string;
begin
  if SelectDirectory(RSSelectSourceDir, '', Dir) then begin
    edtSource.Text:= Dir;
    FParser.RootDir:= Dir;
  end;
end;

end.
