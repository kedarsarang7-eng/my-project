; ============================================================================
; DukanX Installer — Inno Setup Script
; ============================================================================
; Builds a professional Windows installer that:
;   1. Bundles the entire Release build output
;   2. Installs VC++ Redistributable automatically
;   3. Creates Desktop & Start Menu shortcuts
;   4. Supports uninstallation
;   5. Handles upgrade installs
;
; Prerequisites:
;   - Inno Setup 6.x installed (https://jrsoftware.org/isinfo.php)
;   - flutter build windows --release completed
;   - VC++ Redistributable x64 EXE in installer/ directory
;
; Build command:
;   iscc installer\dukanx_installer.iss
; ============================================================================

#define MyAppName "DukanX"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "DukanX Engineering"
#define MyAppURL "https://dukanx.com"
#define MyAppExeName "dukanx.exe"

; Path to the Release build output (relative to this .iss file's parent dir)
#define BuildOutputDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=
OutputDir=..\build\installer
OutputBaseFilename=DukanX-{#MyAppVersion}-Setup
SetupIconFile=..\assets\logo.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
MinVersion=10.0

; Sign the installer (uncomment when code signing cert is available)
; SignTool=signtool sign /f "$qcert.pfx$q" /p "$qpassword$q" /t http://timestamp.digicert.com $f

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
; Main executable
Source: "{#BuildOutputDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Flutter engine DLL
Source: "{#BuildOutputDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion

; All plugin DLLs
Source: "{#BuildOutputDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data directory (flutter_assets, icudtl.dat, app.so)
Source: "{#BuildOutputDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; VC++ Redistributable (bundled for machines without it)
Source: "vcredist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: NeedsVCRedist

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if needed
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Check: NeedsVCRedist; Flags: waituntilterminated

; Launch app after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}"

[Code]
// ============================================================================
// Check if VC++ Redistributable is installed
// ============================================================================
function NeedsVCRedist: Boolean;
var
  RegKey: String;
  Installed: Cardinal;
begin
  Result := True;

  // Check 64-bit registry for VC++ 2015-2022 Redistributable
  RegKey := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, RegKey, 'Installed', Installed) then
  begin
    if Installed = 1 then
    begin
      Result := False; // Already installed
      Exit;
    end;
  end;

  // Alternative registry path
  RegKey := 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, RegKey, 'Installed', Installed) then
  begin
    if Installed = 1 then
    begin
      Result := False;
      Exit;
    end;
  end;

  // Also check if the DLLs exist directly
  if FileExists(ExpandConstant('{sys}\vcruntime140.dll')) and
     FileExists(ExpandConstant('{sys}\msvcp140.dll')) then
  begin
    Result := False;
  end;
end;

// ============================================================================
// Close running instance before upgrade
// ============================================================================
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  WasRunning: Boolean;
  ResultCode: Integer;
begin
  Result := '';
  WasRunning := False;

  // Try to close running instances
  if Exec('taskkill', '/f /im ' + '{#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      WasRunning := True;
  end;

  // Wait a moment for the process to fully exit
  if WasRunning then
    Sleep(1000);
end;

// ============================================================================
// Create %APPDATA%\DukanX directory structure on install
// ============================================================================
procedure CurStepChanged(CurStep: TSetupStep);
var
  AppDataDir: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Create app data directories
    AppDataDir := ExpandConstant('{userappdata}\DukanX');
    ForceDirectories(AppDataDir + '\logs');
    ForceDirectories(AppDataDir + '\backups');
  end;
end;
