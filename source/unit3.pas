{
-----------------------------------------------------------------
FluxMyFluffyFloppy
v5.xx
-----------------------------------------------------------------
A Microsoft(r) Windows(r) GUI for Greseaweazle Host Tools
FREEWARE / OpenSource
License: GNU General Public License v2.0
(c) 2021-2025 FrankieTheFluff
Web: https://github.com/FrankieTheFluff/FluxMyFluffyFloppy
Mail: fluxmyfluffyfloppy@mail.de
-----------------------------------------------------------------
Uses code from the following projects:
UnTerminal 1.0 by Tito Hinostroza 02/10/2020
https://github.com/t-edson/UnTerminal
-----------------------------------------------------------------
}
unit Unit3;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn;

type

  { TFrmOptions }

  TFrmOptions = class(TForm)
    Cancel: TButton;
    folderTemplates: TDirectoryEdit;
    fileDiskdefs: TDirectoryEdit;
    GroupBox1: TGroupBox;
    lblDiskdefs: TLabel;
    lblTemplates: TLabel;
    OK: TButton;
    procedure CancelClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKClick(Sender: TObject);
  private

  public

  end;

var
  FrmOptions: TFrmOptions;

implementation
uses
  unit1;

{$R *.lfm}

{ TFrmOptions }

procedure TFrmOptions.CancelClick(Sender: TObject);
begin
  close;
end;

procedure TFrmOptions.FormShow(Sender: TObject);
begin
 fileDiskdefs.Text := INI.ReadString('FluxMyFluffyFloppy', 'Diskdefs', '');
 folderTemplates.Directory := INI.ReadString('FluxMyFluffyFloppy', 'FolderTemplates', '');
end;

procedure TFrmOptions.OKClick(Sender: TObject);
begin
 INI.WriteString('FluxMyFluffyFloppy', 'Diskdefs', fileDiskdefs.Text);
 INI.WriteString('FluxMyFluffyFloppy', 'FolderTemplates', folderTemplates.Directory);
 if fileDiskdefs.Text <> '' then
  begin
   Form1.Refresh_Diskdefs_DropDown;
  end;
 Form1.Refresh_Templates_Read_DropDown;
 Form1.Refresh_Templates_Write_DropDown;
 Form1.btReadTplNew.Click;
 Form1.btWriteTplNew.Click;
 Form1.CMD_Generate;
 close;
end;

end.

