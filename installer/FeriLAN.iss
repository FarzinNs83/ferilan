; FeriLAN installer: the app, n2n (bin\feri-edge.exe), the TAP-Windows driver and the FeriLAN adapter.
; Build: flutter build windows --release, then
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\FeriLAN.iss
; Output: dist\FeriLAN-Setup-<version>.exe

#define AppName "FeriLAN"
#define AppVersion "1.0.0"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{AB6EC3E7-A2E9-40BB-9B8F-5A06157DCEE9}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppName}.exe
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppName}.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppName}.exe"; Tasks: desktopicon

[Registry]
; ferilan://join?… invite links open the app
Root: HKA; Subkey: "Software\Classes\ferilan"; ValueType: string; ValueData: "URL:{#AppName} invite"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\ferilan"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\ferilan\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppName}.exe,0"
Root: HKA; Subkey: "Software\Classes\ferilan\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppName}.exe"" ""%1"""

[Run]
; shellexec: the app asks for admin itself
Filename: "{app}\{#AppName}.exe"; Description: "Launch {#AppName}"; Flags: postinstall nowait skipifsilent shellexec

[Code]
procedure Kill(const Image: String);
var
  Rc: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM ' + Image, '', SW_HIDE, ewWaitUntilTerminated, Rc);
end;

function PowerShell(const Args: String): Integer;
begin
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass ' + Args, '', SW_HIDE, ewWaitUntilTerminated, Result) then
    Result := -1;
end;

// a running app or edge would lock the files being replaced
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Kill('{#AppName}.exe');
  Kill('feri-edge.exe');
  Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Installing the virtual network adapter (TAP-Windows)...';
    if PowerShell('-File "' + ExpandConstant('{app}\bin\adapter.ps1') + '"') <> 0 then
      MsgBox('The virtual network adapter could not be installed now.' + #13#10 +
        'FeriLAN will try again when you press Connect.', mbInformation, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Rc: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    Kill('{#AppName}.exe');
    Kill('feri-edge.exe');
    Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /F /TN {#AppName}', '', SW_HIDE, ewWaitUntilTerminated, Rc);
    // only our adapter; the TAP driver stays in the driver store, where OpenVPN may share it
    PowerShell('-Command "$a = Get-NetAdapter -Name ''{#AppName}'' -ErrorAction SilentlyContinue; if ($a) { pnputil /remove-device $a.PnPDeviceID | Out-Null }; Remove-NetFirewallRule -Name ''FeriLAN-In'',''FeriLAN-P2P'' -ErrorAction SilentlyContinue"');
  end;
end;
