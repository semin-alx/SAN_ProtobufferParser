unit reg_statements;

{*****************************************************************}
{                                                                 }
{                         ProtoBufParser                          }
{                                                                 }
{                   Copyright(c) 2024 Semin Alexey                }
{                        All rights reserved                      }
{                                                                 }
{*****************************************************************}

interface

implementation

uses parser, stm_import, stm_syntax, stm_package, stm_enum, stm_message,
  stm_pkg_option;

initialization
  RegisterStatmentClass1(TsmImportStatement);
  RegisterStatmentClass1(TsmSyntaxStatement);
  RegisterStatmentClass1(TsmPackageStatement);
  RegisterStatmentClass1(TsmEnumStatement);
  RegisterStatmentClass1(TsmMessageStatement);
  RegisterStatmentClass1(TsmPackageOptionStatement);
end.
