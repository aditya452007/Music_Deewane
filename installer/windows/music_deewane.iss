[Setup]
AppId={{B5E8A3A0-4K2L-9M1N-8P7Q-6R5S4T3U2V1W}
AppName=Music Deewane
AppVersion=2.0.0
AppPublisher=Music Deewane
AppPublisherURL=https://github.com/aditya452007/Music_Deewane
AppSupportURL=https://github.com/aditya452007/Music_Deewane/issues
AppUpdatesURL=https://github.com/aditya452007/Music_Deewane/releases/latest
DefaultDirName={autopf}\Music Deewane
DefaultGroupName=Music Deewane
AllowNoIcons=yes
OutputDir=..\..\windows_artifacts
OutputBaseFilename=MusicDeewaneSetup_{#SetupSetting("AppVersion")}
SetupIconFile=..\..\assets\logo.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\Music Deewane.exe
UninstallDisplayName=Music Deewane
VersionInfoVersion=2.0.0.0
VersionInfoDescription=Music Deewane Installer
VersionInfoCompany=Music Deewane

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Music Deewane"; Filename: "{app}\Music Deewane.exe"
Name: "{group}\{cm:UninstallProgram,Music Deewane}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Music Deewane"; Filename: "{app}\Music Deewane.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\Music Deewane"; Filename: "{app}\Music Deewane.exe"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\Music Deewane.exe"; Description: "{cm:LaunchProgram,Music Deewane}"; Flags: nowait postinstall skipifsilent
