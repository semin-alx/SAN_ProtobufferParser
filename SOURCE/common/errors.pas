unit errors;

interface

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

uses System.SysUtils, lexanalz;

type

  TsmParserPosition = record
    LineNum1: integer;
    PosOfLine1: integer;
    LineNum2: integer;
    PosOfLine2: integer;
    FileName: string;
  end;

  EsmParserError = class(Exception)
  private
    FPosOfFile1: integer;
    FPosOfFile2: integer;
    FPosition: TsmParserPosition;
  public
    constructor CreateByToken(Token: TsmProtoToken; Mes: string);
    function IsNotSetPosition: Boolean;
    procedure SetPosition(PositionA: TsmParserPosition);
    property Position: TsmParserPosition read FPosition;
    property PosOfFile1: integer read FPosOfFile1 write FPosOfFile1;
    property PosOfFile2: integer read FPosOfFile2 write FPosOfFile2;
  end;

resourcestring
  RsErr_IllegalCharacter = 'Illegal character: [%s]';
  RsErr_UnexpectedEndOfFile = 'Unexpected end of file';
  RsErr_UnknownKeyword = 'Illegal keyword: [%s]';
  RsErr_ErrorMessage = '%s at line: %d position: %d in %s';
  RsErr_DuplcateEnumName = 'Duplicate enum name %s';
  RsErr_DuplcateEnumValue = 'Duplicate enum value %d';
  RsErr_BadTypeAllowAlias = 'Invalid type [allow_alias], expected boolean type';
  RsErr_DuplicateFieldName = 'Duplicate field name [%s]';
  RsErr_DuplicateFieldId = 'Duplicate field number [%d]';
  RsErr_InvalidMapKeyType = 'Invalid map key type';
  RsErr_DuplicateOptionName = 'Duplicate option name [%s]';
  RsErr_OptionNotFound = 'Option [%s] not found';
  RsErr_InvalidConstantValue = 'Invalid constant value %s';
  RsErr_ExpectEnumName = 'Enum name expected but [%s] found';
  RsErr_ExpectBooleanType = 'Boolean type expected for [%s]';
  RsErr_ExpectFieldName = 'Field name expected but [%s] found';
  RsErr_InvalidImportOption = 'Illegal option for import statement: [%s]';
  RsErr_ExpectFileName = 'File name expected but [%s] found';
  RsErr_FileNotFound = 'File %s not found';
  RsErr_ExpectMessageName = 'Message name expected but [%s] found';
  RsErr_ExpectFieldLabel = 'Field label [required|optional|repeated] expected but [%s] found';
  RsErr_InvalidFieldLabelProto3 = 'Invalid field label [%s] for proto3 version';
  RsErr_ExpectFieldType = 'Field type expected but [%s] found';
  RsErr_UnknownFieldType = 'Unknown field type [%s]';
  RsErr_ExpectIntegerValue = 'Integer value expected but [%s] found';
  RsErr_ExpectOptionName = 'Option name expected but [%s] found';
  RsErr_ExpectPackageName = 'Package name expected but [%s] found';
  RsErr_ExpectVersion = 'Version expected but [%s] found';
  RsErr_UnknownVersion = 'Unknown version %s';
  RsErr_ExpectMapKeyType = 'Map key type expected but [%s] found';
  RsErr_ExpectChar = '[%s] expected but [%s] found';
  RsErr_ExpectMapName = 'Map name expected but [%s] found';
  RsErr_InvalidParentMessageType = 'It is applicable only inside message statement';
  RsErr_ExpectOneOfName = 'Oneof name expected but [%s] found';
  RsErr_TypeColision = '[%s] type colision detected, files:';
  RsErr_PublicImportRefToSelf = 'Import file [%s] refer to  itself';
  RsErr_PublicImportCyclicalDependence = 'Import file [%s] has cyclical dependence';
  RsErr_UnknownBaseFieldType = 'Unknown base field type';
  RsErr_UnknownFieldLabel = 'Unknown field label';
  RsErr_UnknownIdentifier = 'Unknown Identifier [%s]';
  RsErr_ExpectEnumType = 'Enum type expected, but [%s] found';
  RsErr_EnumItemNotFound = 'Enum item [%s] not found in [%s]';
  RsErr_WrongOptionPacked = 'The option [packed] is not applicable (Allowed only for [repeated] fields)';
  RsErrBuild_UnknownBaseProtoType = 'Build: Unknown BaseProtoType [%s]';
  RsErrBuild_UnknownFieldClass = 'Build: Unknown field class [%s]';
  RsErrBuild_UnknownFieldLabel = 'Build: Unknown field label [%s]';
  RsErrBuild_UnsupportedValueType = 'Variant type [%s] is unsupported';


implementation



{ EsmParserError }

constructor EsmParserError.CreateByToken(Token: TsmProtoToken; Mes: string);
begin
  FPosOfFile1:= Token.PosStart;
  FPosOfFile2:= Token.PosEnd;
  Message:= Mes;
end;

function EsmParserError.IsNotSetPosition: Boolean;
begin
  Result:= (FPosOfFile1 = 0) and (FPosOfFile2 = 0);
end;

procedure EsmParserError.SetPosition(PositionA: TsmParserPosition);
begin
  FPosition := PositionA;
end;

end.
