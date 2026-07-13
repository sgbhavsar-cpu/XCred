; ╔══════════════════════════════════════════════════════════════╗
; ║  XCred — Inno Setup installer script                        ║
; ║  Requires: Inno Setup 6.x  (https://jrsoftware.org/isinfo.php) ║
; ║  Build: run scripts\publish.ps1 first, then compile this    ║
; ╚══════════════════════════════════════════════════════════════╝

#define AppName      "XCred"
#define AppVersion   "1.0.0"
#define AppPublisher "Your Company"
#define AppExe       "XCred.Api.dll"
#define PublishDir   "..\publish"

; ── Basic installer settings ──────────────────────────────────────────────────
[Setup]
AppId={{8F3A1D2C-7B4E-4F9A-B3C6-1E2D4A5F6B7C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/yourusername/XCred
AppSupportURL=https://github.com/yourusername/XCred/issues
AppUpdatesURL=https://github.com/yourusername/XCred/releases
DefaultDirName={commonpf64}\XCred
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=XCred-Setup-{#AppVersion}
SetupIconFile=
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\XCred.Api.exe
DisableDirPage=no

; ── Languages ─────────────────────────────────────────────────────────────────
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ── Application files (from publish/ output) ─────────────────────────────────
[Files]
Source: "{#PublishDir}\*";          DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "scripts\Setup-XCred.ps1";   DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "scripts\Uninstall-XCred.ps1"; DestDir: "{app}"; Flags: ignoreversion

; ── Start Menu shortcuts ──────────────────────────────────────────────────────
[Icons]
Name: "{group}\{#AppName} (Open in Browser)"; Filename: "{code:GetBrowserUrl}"
Name: "{group}\Uninstall {#AppName}";         Filename: "{uninstallexe}"

; ── Run after install ─────────────────────────────────────────────────────────
; NOTE: the IIS/configuration PowerShell script is launched from [Code]
; (CurStepChanged → ssPostInstall) so its exit code is checked and failures are
; reported to the user instead of being silently ignored.
[Run]
Filename: "{code:GetBrowserUrl}"; \
    Description: "Open {#AppName} in browser"; \
    Flags: shellexec postinstall skipifsilent nowait

; ── Uninstall ─────────────────────────────────────────────────────────────────
[UninstallRun]
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall-XCred.ps1"" -SiteName ""{code:GetStoredSiteName}"""; \
    RunOnceId: "RemoveXCredSite"; \
    Flags: runhidden waituntilterminated

; ── Registry (store site name for uninstall) ──────────────────────────────────
[Registry]
Root: HKLM; Subkey: "Software\XCred"; ValueType: string; ValueName: "SiteName"; ValueData: "{code:GetSiteName}"; Flags: uninsdeletekey

; ╔══════════════════════════════════════════════════════════════╗
; ║  Pascal Script — custom wizard pages + config file writer   ║
; ╚══════════════════════════════════════════════════════════════╝
[Code]

var
  PageDB:       TInputQueryWizardPage;   // SQL Server / database
  PageIIS:      TInputQueryWizardPage;   // IIS site name / port / URL
  PageSecurity: TInputQueryWizardPage;   // JWT secret

// ── Helper: generate a random 64-char alphanumeric JWT secret ────────────────
function GenerateSecret: String;
var
  Chars: String;
  i, idx: Integer;
begin
  Chars  := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  Result := '';
  for i := 1 to 64 do
  begin
    idx    := Random(Length(Chars)) + 1;
    Result := Result + Copy(Chars, idx, 1);
  end;
end;

// ── Helper: escape a string for JSON (backslash + double-quote) ──────────────
function EscapeJson(const S: String): String;
var
  i: Integer;
  C: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    C := S[i];
    if C = '\' then Result := Result + '\\'
    else if C = '"' then Result := Result + '\"'
    else Result := Result + C;
  end;
end;

// ── Build the connection string from the SQL page inputs ─────────────────────
function BuildConnectionString: String;
var
  Server, Database, User, Pass: String;
begin
  Server   := PageDB.Values[0];
  Database := PageDB.Values[1];
  User     := PageDB.Values[2];
  Pass     := PageDB.Values[3];

  if User = '' then
    // Windows Authentication
    Result := 'Server=' + Server + ';Database=' + Database +
              ';Trusted_Connection=True;TrustServerCertificate=True;'
  else
    // SQL Server Authentication
    Result := 'Server=' + Server + ';Database=' + Database +
              ';User Id=' + User + ';Password=' + Pass +
              ';TrustServerCertificate=True;';
end;

// ── Wizard page accessors (used in [Run] / [Icons] / [Registry]) ─────────────
function GetSiteName(Param: String): String;
begin
  if Assigned(PageIIS) then Result := PageIIS.Values[0]
  else Result := 'XCred';
end;

function GetPort(Param: String): String;
begin
  if Assigned(PageIIS) then Result := PageIIS.Values[1]
  else Result := '80';
end;

function GetAppBaseUrl(Param: String): String;
begin
  if Assigned(PageIIS) then Result := PageIIS.Values[2]
  else Result := 'http://localhost';
end;

function GetBrowserUrl(Param: String): String;
begin
  Result := GetAppBaseUrl('');
  if GetPort('') <> '80' then
    Result := 'http://localhost:' + GetPort('');
end;

function GetStoredSiteName(Param: String): String;
var
  Reg: String;
begin
  if RegQueryStringValue(HKLM, 'Software\XCred', 'SiteName', Reg) then
    Result := Reg
  else
    Result := 'XCred';
end;

function GetJwtSecret: String;
begin
  if Assigned(PageSecurity) and (PageSecurity.Values[0] <> '') then
    Result := PageSecurity.Values[0]
  else
    Result := GenerateSecret;
end;

// ── Create all custom pages ───────────────────────────────────────────────────
procedure InitializeWizard;
begin
  // ── Page: Database ─────────────────────────────────────────────────────────
  PageDB := CreateInputQueryPage(wpSelectDir,
    'Database Configuration',
    'XCred stores encrypted credentials in SQL Server.',
    'Enter the SQL Server connection details. ' +
    'Leave Username blank to use Windows Authentication (recommended for domain environments).');

  PageDB.Add('SQL Server instance (e.g. .\SQLEXPRESS or myserver\MSSQLSERVER):', False);
  PageDB.Add('Database name:', False);
  PageDB.Add('SQL Username   (blank = Windows Authentication):', False);
  PageDB.Add('SQL Password   (blank = Windows Authentication):', True);  // True = password field

  PageDB.Values[0] := '.\SQLEXPRESS';
  PageDB.Values[1] := 'XCredDb';
  PageDB.Values[2] := '';
  PageDB.Values[3] := '';

  // ── Page: IIS ──────────────────────────────────────────────────────────────
  PageIIS := CreateInputQueryPage(PageDB.ID,
    'IIS Configuration',
    'XCred runs as an IIS website.',
    'Choose the IIS site name, port, and the public URL that will appear in notification emails.');

  PageIIS.Add('IIS Website name:', False);
  PageIIS.Add('Port number (80 for HTTP, 443 for HTTPS):', False);
  PageIIS.Add('Base URL (used in notification emails, e.g. https://xcred.company.com):', False);

  PageIIS.Values[0] := 'XCred';
  PageIIS.Values[1] := '80';
  PageIIS.Values[2] := 'http://localhost';

  // ── Page: Security ─────────────────────────────────────────────────────────
  PageSecurity := CreateInputQueryPage(PageIIS.ID,
    'Security — JWT Secret Key',
    'XCred signs authentication tokens with a secret key.',
    'Leave this blank to auto-generate a secure random key (recommended). ' +
    'If you need to keep an existing installation''s sessions alive after an upgrade, ' +
    'enter the current key from appsettings.json.');

  PageSecurity.Add('JWT Secret Key (64+ characters, or leave blank to generate):', False);
  PageSecurity.Values[0] := '';
end;

// ── Input validation on Next ──────────────────────────────────────────────────
function NextButtonClick(CurPageID: Integer): Boolean;
var
  PortNum: Integer;
begin
  Result := True;

  if CurPageID = PageDB.ID then
  begin
    if Trim(PageDB.Values[0]) = '' then begin
      MsgBox('Please enter the SQL Server instance.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if Trim(PageDB.Values[1]) = '' then begin
      MsgBox('Please enter the database name.', mbError, MB_OK);
      Result := False; Exit;
    end;
    // If one SQL Auth field is set, both must be set
    if (Trim(PageDB.Values[2]) <> '') and (Trim(PageDB.Values[3]) = '') then begin
      MsgBox('You entered a SQL username but no password. Enter both, or clear the username to use Windows Authentication.', mbError, MB_OK);
      Result := False; Exit;
    end;
  end;

  if CurPageID = PageIIS.ID then
  begin
    if Trim(PageIIS.Values[0]) = '' then begin
      MsgBox('Please enter the IIS website name.', mbError, MB_OK);
      Result := False; Exit;
    end;
    PortNum := StrToIntDef(Trim(PageIIS.Values[1]), 0);
    if (PortNum < 1) or (PortNum > 65535) then begin
      MsgBox('Please enter a valid port number between 1 and 65535.', mbError, MB_OK);
      Result := False; Exit;
    end;
    if Trim(PageIIS.Values[2]) = '' then begin
      MsgBox('Please enter the base URL.', mbError, MB_OK);
      Result := False; Exit;
    end;
  end;

  if CurPageID = PageSecurity.ID then
  begin
    if (PageSecurity.Values[0] <> '') and (Length(Trim(PageSecurity.Values[0])) < 32) then begin
      MsgBox('The JWT secret key must be at least 32 characters. Leave it blank to auto-generate a secure key.', mbError, MB_OK);
      Result := False; Exit;
    end;
  end;
end;

// ── Write config JSON + kick off PowerShell setup ────────────────────────────
// ── Run the IIS/config PowerShell script and report success or failure ───────
procedure RunSetupScript;
var
  ResultCode: Integer;
  ScriptPath, ConfigPath, LogPath, Params: String;
begin
  ScriptPath := ExpandConstant('{tmp}\Setup-XCred.ps1');
  ConfigPath := ExpandConstant('{tmp}\xcred-install.json');
  LogPath    := ExpandConstant('{%TEMP}\XCred-Install.log');
  Params     := '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath +
                '" -ConfigFile "' + ConfigPath + '"';

  WizardForm.StatusLabel.Caption := 'Configuring IIS and application settings...';

  if not Exec('powershell.exe', Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox('Could not launch the IIS configuration script (PowerShell).' + #13#10 +
           'XCred files were copied, but IIS was not configured.', mbError, MB_OK);
    Exit;
  end;

  if ResultCode <> 0 then
    MsgBox('XCred files were installed, but configuring IIS failed (exit code '
           + IntToStr(ResultCode) + ').' + #13#10 + #13#10 +
           'See the log for details:' + #13#10 + '    ' + LogPath + #13#10 + #13#10 +
           'Common causes: the .NET 10 Hosting Bundle is not installed, or the '
           + 'chosen port is in use. Fix the issue and re-run the installer.',
           mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigPath, Json: String;
  InstallDir:       String;
begin
  // After files are copied, run the IIS configuration script and report result.
  if CurStep = ssPostInstall then
  begin
    RunSetupScript;
    Exit;
  end;

  // At install start, write the config JSON the script will read.
  if CurStep <> ssInstall then Exit;

  InstallDir := ExpandConstant('{app}');
  ConfigPath := ExpandConstant('{tmp}\xcred-install.json');

  // Build JSON manually — avoids dependency on external tools
  Json :=
    '{' + #13#10 +
    '  "InstallDir": "'       + EscapeJson(InstallDir)             + '",' + #13#10 +
    '  "ConnectionString": "' + EscapeJson(BuildConnectionString)  + '",' + #13#10 +
    '  "JwtSecret": "'        + EscapeJson(GetJwtSecret)           + '",' + #13#10 +
    '  "SiteName": "'         + EscapeJson(GetSiteName(''))        + '",' + #13#10 +
    '  "Port": "'             + EscapeJson(GetPort(''))            + '",' + #13#10 +
    '  "AppBaseUrl": "'       + EscapeJson(GetAppBaseUrl(''))      + '"'  + #13#10 +
    '}';

  if not SaveStringToFile(ConfigPath, Json, False) then
    MsgBox('Could not write configuration file. Installation may fail.', mbError, MB_OK);
end;
