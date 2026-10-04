; Inno Setup script for Trareon Transcribe.
;
; Produces a per-user installer so the owner (and anyone testing a beta) can
; install without an administrator prompt. A per-machine install would need
; elevation, which on a locked-down office laptop means the test simply does
; not happen.
;
; Built by scripts/package_windows_installer.ps1, which passes MyAppVersion
; and SourceDir on the command line:
;   iscc /DMyAppVersion=1.0.0 /DSourceDir=..\..\build\windows\x64\runner\Release trareon.iss
;
; The app is unsigned on the beta channel, so Windows SmartScreen shows
; "Windows protected your PC" on first run. That is expected and documented in
; docs/TESTING-ON-MAC-WINDOWS.md rather than hidden.

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

#define MyAppName "Trareon Transcribe"
#define MyAppPublisher "Trareon"
#define MyAppURL "https://github.com/Trareon-Transcribe/Trareon-Transcribe"
#define MyAppExeName "transcribe.exe"

[Setup]
AppId={{B3F2A4C1-6E9D-4A71-9C2E-7D1F0A5B8C34}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Per-user by design: see the header.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=TrareonTranscribe-{#MyAppVersion}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The app is Indonesian-first; the installer follows.
ShowLanguageDialog=no

[Languages]
Name: "id"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat pintasan di Desktop"; \
  GroupDescription: "Pintasan tambahan"; Flags: unchecked

[Files]
; The whole Flutter bundle: the exe, its DLLs (including rust_core.dll), the
; data/ tree, and models/ when the build bundled them.
Source: "{#SourceDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
  Description: "Jalankan {#MyAppName}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Flutter writes an ephemeral plugin cache next to the exe on first run.
Type: filesandordirs; Name: "{app}\data\flutter_assets\ephemeral"
