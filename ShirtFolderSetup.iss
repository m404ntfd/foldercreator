#ifndef AppVersion
  #define AppVersion "2.4.0"
#endif

#define AppName "J&M Apparel Shirt Design Folder Builder"
#define AppExeName "ShirtDesignFolderBuilder.exe"

[Setup]
AppId={{A9D1225E-B427-43D1-B5A7-F597D3BD9D40}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=J&M Apparel
AppPublisherURL=https://jmapparel.us
AppSupportURL=https://github.com/m404ntfd/foldercreator/issues
AppUpdatesURL=https://github.com/m404ntfd/foldercreator/releases/latest
DefaultDirName={autopf}\J&M Apparel\Shirt Design Folder Builder
DefaultGroupName=J&M Apparel
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=ShirtFolderSetup
SetupIconFile=JM-Folder-Creator.ico
UninstallDisplayIcon={app}\JM-Folder-Creator.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Files]
Source: "dist\ShirtDesignFolderBuilder.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "JM-Folder-Creator.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "GITHUB-UPDATE-SETUP.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "VERSION.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\J&M Apparel\Shirt Design Folder Builder"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\JM-Folder-Creator.ico"
Name: "{autodesktop}\Shirt Design Folder Builder"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\JM-Folder-Creator.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch Shirt Design Folder Builder"; Flags: nowait postinstall skipifsilent
