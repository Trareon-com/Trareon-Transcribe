; Inno Setup — Trareon Transcribe Windows installer (onedir)
#ifndef AppVersion
  #define AppVersion "0.1.1"
#endif

#define MyAppName "Trareon Transcribe"
#define MyAppExeName "TrareonTranscribe.exe"

[Setup]
AppId={{A7C3E2B1-4F5D-4A8E-9C1B-2D3E4F5A6B7C}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher=Trareon
DefaultDirName={localappdata}\Programs\Trareon Transcribe
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist-release
OutputBaseFilename=Trareon-Transcribe-{#AppVersion}-windows-x64-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\assets\trareon-transcribe-icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\..\dist\TrareonTranscribe\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
