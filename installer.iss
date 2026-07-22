; =============================================================================
; DIPS Management — Inno Setup 6 (Flutter Windows x64)
; Prerequisites: flutter build windows --release
; App version: keep in sync with pubspec.yaml (version: x.y.z+build)
; =============================================================================

#define MyAppName "DIPS Management"
#define MyAppExeName "dipsmanagment.exe"
#define MyAppVersion "1.2.2"
#define MyAppPublisher "DIPS"
#define MyAppBuildOutput "build\windows\x64\runner\Release"
#define MyAppIcon "windows\runner\resources\app_icon.ico"
#define MyWelcomeImage "assets\installer\welcome.bmp"
#define MyLicenseFile "LICENSE.txt"

[Setup]
; Unique AppId — keep constant across releases for in-place upgrades
AppId={{C4D8E1F2-5A3B-4C6D-9E8F-0A1B2C3D4E5F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppMutex={#MyAppName}SetupMutex

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir=dist
OutputBaseFilename=DIPS_Management_Setup_{#MyAppVersion}

Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Visual / legal
SetupIconFile={#MyAppIcon}
WizardImageFile={#MyWelcomeImage}
WizardImageStretch=no
LicenseFile={#MyLicenseFile}

; Uninstaller appearance (icon path stored at install time)
UninstallDisplayIcon={app}\{#MyAppExeName}

; Version info on setup executable
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=Copyright (C) {#MyAppPublisher}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppBuildOutput}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
; Install location for integrations / IT scripts
Root: HKLM64; Subkey: "Software\DIPS"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey

[UninstallDelete]
; Remove any files left in the install folder after the standard uninstall (user data, logs, etc.)
Type: filesandordirs; Name: "{app}"

[Code]
const
  VC_REDIST_URL = 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
  VC_REDIST_EXE = 'vc_redist.x64.exe';

function IsProcessRunning(const ExeName: String): Boolean;
var
  TempFile: String;
  Lines: TArrayOfString;
  I, ExitCode: Integer;
  Needle: String;
begin
  Result := False;
  TempFile := ExpandConstant('{tmp}\dips_proc_check.txt');
  DeleteFile(TempFile);
  if Exec(ExpandConstant('{cmd}'), '/c tasklist /FI "IMAGENAME eq ' + ExeName + '" /FO CSV /NH > "' + TempFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
  begin
    Needle := LowerCase(ExeName);
    if LoadStringsFromFile(TempFile, Lines) then
      for I := 0 to GetArrayLength(Lines) - 1 do
        if Pos(Needle, LowerCase(Trim(Lines[I]))) > 0 then
          Result := True;
  end;
  DeleteFile(TempFile);
end;

function KillProcessByName(const ExeName: String): Boolean;
var
  ExitCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/c taskkill /F /T /IM "' + ExeName + '"', '', SW_HIDE, ewWaitUntilTerminated, ExitCode);
end;

function EnsureAppNotRunning: Boolean;
var
  Btn: Integer;
begin
  Result := True;
  while IsProcessRunning('{#MyAppExeName}') do
  begin
    Btn := MsgBox(
      '{#MyAppName} is running (process {#MyAppExeName}).' + #13#10 + #13#10 +
      'You must close it before installation can continue.' + #13#10 + #13#10 +
      'Do you want the installer to force-close the application?' + #13#10 +
      '(Choose No to exit the setup.)',
      mbError,
      MB_YESNO
    );
    if Btn = IDNO then
    begin
      Result := False;
      Exit;
    end;
    KillProcessByName('{#MyAppExeName}');
    Sleep(800);
  end;
end;

function NeedVCRedistX64: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) then
    if Installed = 1 then
      Result := False;
end;

function DownloadVCRedistX64: Boolean;
var
  ExitCode: Integer;
  PsLine: String;
  OutPath: String;
begin
  Result := False;
  OutPath := ExpandConstant('{tmp}\' + VC_REDIST_EXE);
  DeleteFile(OutPath);

  PsLine :=
    '-NoProfile -ExecutionPolicy Bypass -Command ' +
    '"$ProgressPreference=''SilentlyContinue''; ' +
    '[Net.ServicePointManager]::SecurityProtocol = ' +
    '[Net.SecurityProtocolType]::Tls12; ' +
    'try { Invoke-WebRequest -Uri ''' + VC_REDIST_URL + ''' -OutFile ''' + OutPath + ''' -UseBasicParsing; exit 0 } catch { exit 1 }"';

  if Exec('powershell.exe', PsLine, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) and (ExitCode = 0) then
    Result := FileExists(OutPath);
end;

function InitializeSetup: Boolean;
begin
  Result := EnsureAppNotRunning;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode: Integer;
  VcPath: String;
begin
  Result := '';
  NeedsRestart := False;

  if not EnsureAppNotRunning then
  begin
    Result := 'Setup was cancelled because the application is still running.';
    Exit;
  end;

  if NeedVCRedistX64 then
  begin
    VcPath := ExpandConstant('{tmp}\' + VC_REDIST_EXE);

    if not DownloadVCRedistX64 then
    begin
      Result :=
        'Failed to download Microsoft Visual C++ 2015-2022 Redistributable (x64).' + #13#10 +
        'Check your internet connection and try again.';
      Exit;
    end;

    if not Exec(VcPath, '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
    begin
      Result := 'Could not start the Visual C++ Redistributable installer.';
      DeleteFile(VcPath);
      Exit;
    end;

    { 0 = success; 1638 = newer/already present; 3010 = success, restart required }
    if (ExitCode <> 0) and (ExitCode <> 1638) and (ExitCode <> 3010) then
    begin
      Result := 'Visual C++ Redistributable setup failed (exit code ' + IntToStr(ExitCode) + ').';
      DeleteFile(VcPath);
      Exit;
    end;

    if ExitCode = 3010 then
      NeedsRestart := True;

    DeleteFile(VcPath);
  end;
end;
