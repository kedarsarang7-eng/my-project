[Setup]
AppName=Myvyaparmitra
AppVersion=1.0.0
AppPublisher=Myvyaparmitra Software
AppPublisherURL=https://myvyaparmitra.com
AppSupportURL=https://myvyaparmitra.com/support
DefaultDirName={autopf}\Myvyaparmitra_Test
DefaultGroupName=Myvyaparmitra
OutputBaseFilename=Myvyaparmitra_Setup_Test
OutputDir=installer_output
Compression=lzma
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\myvyaparmitra.exe
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Myvyaparmitra"; Filename: "{app}\myvyaparmitra.exe"
Name: "{group}\Uninstall Myvyaparmitra"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Myvyaparmitra"; Filename: "{app}\myvyaparmitra.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\myvyaparmitra.exe"; Description: "Launch Myvyaparmitra now"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
