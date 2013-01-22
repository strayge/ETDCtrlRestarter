unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Menus, Windows, jwatlhelp32, iniFiles;

type

  { TForm1 }

  TForm1 = class(TForm)
    miAbout: TMenuItem;
    miExit: TMenuItem;
    PopupMenu1: TPopupMenu;
    Timer1: TTimer;
    TrayIcon1: TTrayIcon;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure miAboutClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;
  cpu_time_old: real;
  process_name: String;
  path_to_file: String;
  timeout: Integer;
  percents_of_cpu_to_kill: Integer;

implementation

{$R *.lfm}

function RunApp(my_app : string; my_wait : bool) : bool;
var
  si : TStartupInfo;
  pi : TProcessInformation;
begin
  Result := false;
  try
    ZeroMemory(@si,SizeOf(si));
    si.cb := SizeOf(si);
    si.dwFlags := STARTF_USESHOWWINDOW;
    si.wShowWindow := SW_HIDE;
    if CreateProcess(nil,PChar(my_app),nil,nil,False,0,nil,nil,si,pi{%H-})=true then Result := true;
    try CloseHandle(pi.hThread); except ; end;
    if my_wait = true then WaitForSingleObject(pi.hProcess, INFINITE);
    try CloseHandle(pi.hProcess); except ; end;
  except
    Result := false;
  end;
end;

function GetProcID(name:string):Cardinal;
var
  SnapShot:THandle;
  process:TProcessEntry32;
begin
  result := 0;
  SnapShot := CreateToolHelp32Snapshot(TH32CS_SNAPPROCESS,0);
  process.dwSize := SizeOf(Process);
  Process32First(SnapShot,Process);
  repeat
    if LowerCase(process.szExeFile) = LowerCase(name) then
    begin
      result := process.th32ProcessID;
      CloseHandle(SnapShot);
      exit;
    end;
  until Process32Next(SnapShot,Process) <> true;
  CloseHandle(SnapShot);
end;

function GetTimeByName(name: String): real;
var
  cpu_time: real;
  pid: cardinal;
  timeCreate,timeExit,timeKernel,timeUser: TFileTime;
  ProcessHandle: handle;
begin
  result:=0;
  pid:=GetProcID(name);
  if pid<>0 then begin
    ProcessHandle:=OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_ALL_ACCESS,false,pid);
    if ProcessHandle<>0 then begin
      if GetProcessTimes(ProcessHandle,timeCreate{%H-},timeExit{%H-},timeKernel{%H-},timeUser{%H-}) then begin
        cpu_time := timeUser.dwHighDateTime*(4294967296/10000000)+timeUser.dwLowDateTime/10000000;
        cpu_time := cpu_time + timeKernel.dwHighDateTime*(4294967296/10000000)+timeKernel.dwLowDateTime/10000000;
        result:=cpu_time;
      end;
    end;
  end;
end;

function TerminateProcessByName(name: string): boolean;
var
  pid: cardinal;
  ProcessHandle: handle;
begin
  result:=false;
  pid:=GetProcID(name);
  if pid<>0 then begin
    ProcessHandle:=OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_ALL_ACCESS,false,pid);
    if ProcessHandle<>0 then begin
      Result:=TerminateProcess(ProcessHandle,0);
    end;
  end;
end;

procedure ReadSettings();
var
  ininame: string;
  ini: TIniFile;
begin
  ininame:=paramstr(0);                    //get current path\exe-name
  SetLength(ininame, Length(ininame)-4);   // cut '.exe'
  ininame:=ininame+'.ini';

  ini:=TIniFile.Create(ininame);
  try
    //process_name := ini.ReadString('Settings', 'process_name', 'ETDCtrl.exe');
    path_to_file := ini.ReadString('Settings', 'path_to_file', 'C:\Program Files\Elantech\ETDCtrl.exe');
    timeout := ini.ReadInteger('Settings', 'timeout', 30);
    percents_of_cpu_to_kill := ini.ReadInteger('Settings', 'percents_of_cpu_to_kill', 40); //of 1 core
  finally
    ini.Free;
  end;
  process_name := ExtractFileName(path_to_file);
  if not FileExists(path_to_file) then begin
     ShowMessage('File not found:'+#10+'"'+path_to_file+'"'+#10+'Press Ok to exit...');
     Application.Terminate;
  end;
end;

procedure WriteSettings();
var
  ininame: string;
  ini: TIniFile;
begin
  ininame:=paramstr(0);                    //get current path\exe-name
  SetLength(ininame, Length(ininame)-4);   // cut '.exe'
  ininame:=ininame+'.ini';

  ini:=TIniFile.Create(ininame);
  try
    //ini.WriteString('Settings', 'process_name', process_name);
    ini.WriteString('Settings', 'path_to_file', path_to_file);
    ini.WriteInteger('Settings', 'timeout', timeout);
    ini.WriteInteger('Settings', 'percents_of_cpu_to_kill', percents_of_cpu_to_kill); //of 1 core
  finally
    ini.Free;
  end;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  ReadSettings();
  Timer1.Interval:=TIMEOUT*1000;
  cpu_time_old:=GetTimeByName(PROCESS_NAME);
  Timer1.Enabled:=true;
  if GetProcID(process_name)=0 then
    RunApp(path_to_file, false);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  Form1.Hide;
end;

procedure TForm1.miAboutClick(Sender: TObject);
var
  info: string;
begin
  info:='ETDCtrlRestarter'+
        #10+''+
        #10+'Created by Str@y (2013)';
  MessageBox(0, PChar(info), '', MB_OK);
end;

procedure TForm1.miExitClick(Sender: TObject);
begin
  WriteSettings();
  Application.Terminate;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  cpu_time: real;
begin
  cpu_time:=GetTimeByName(PROCESS_NAME);
  if cpu_time<>0 then begin
    if ( (cpu_time - cpu_time_old) > (timeout * percents_of_cpu_to_kill/100) ) then begin
      TerminateProcessByName(PROCESS_NAME);
      cpu_time:=0;
      RunApp(path_to_file, false);
    end;
    cpu_time_old:=cpu_time;
  end;
end;


end.

