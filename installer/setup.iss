; ╔══════════════════════════════════════════════════════════════╗
; ║  XCred — Inno Setup installer script                        ║
; ║  Requires: Inno Setup 6.x  (https://jrsoftware.org/isinfo.php) ║
; ║  Build: run scripts\publish.ps1 first, then compile this    ║
; ╚══════════════════════════════════════════════════════════════╝

#define AppName      "XCred"
#define AppVersion   "1.2.0"
#define AppPublisher "XForce Inc"
#define AppExe       "XCred.Api.dll"
#define PublishDir   "..\publish"

; ── Basic installer settings ──────────────────────────────────────────────────
[Setup]
AppId={{8F3A1D2C-7B4E-4F9A-B3C6-1E2D4A5F6B7C}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/sgbhavsar-cpu/XCred
AppSupportURL=https://github.com/sgbhavsar-cpu/XCred/issues
AppUpdatesURL=https://github.com/sgbhavsar-cpu/XCred/releases
DefaultDirName={commonpf64}\XCred
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=XCred-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\XCred.Api.exe
DisableDirPage=no
SetupIconFile=branding\xcred.ico
WizardImageFile=branding\WizardImage.bmp
WizardSmallImageFile=branding\WizardSmallImage.bmp

; ── Languages ─────────────────────────────────────────────────────────────────
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ── Application files (from publish/ output) ─────────────────────────────────
[Files]
Source: "{#PublishDir}\*";          DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "scripts\Setup-XCred.ps1";   DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "scripts\Uninstall-XCred.ps1"; DestDir: "{app}"; Flags: ignoreversion
; Offline fallback for a SQL engine when the target machine has no internet access.
; Optional: only bundled if you've placed the file before compiling — see redist\README.md.
#ifexist "redist\SqlLocalDB.msi"
Source: "redist\SqlLocalDB.msi"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

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

; ── Registry (site name for uninstall; install dir so a future run can find
;    it before {app} is available — see DetectExistingInstall in [Code]) ──────
[Registry]
Root: HKLM; Subkey: "Software\XCred"; ValueType: string; ValueName: "SiteName"; ValueData: "{code:GetSiteName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\XCred"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"

; ╔══════════════════════════════════════════════════════════════╗
; ║  Pascal Script — custom wizard pages + config file writer   ║
; ╚══════════════════════════════════════════════════════════════╝
[Code]

var
  PageDB:       TInputQueryWizardPage;   // SQL Server / database
  PageIIS:      TInputQueryWizardPage;   // IIS site name / port / URL
  PageSecurity: TInputQueryWizardPage;   // JWT secret
  ProgressPage: TOutputProgressWizardPage; // shown during connection tests
  LogMemo:      TNewMemo;                // scrolling log textbox on ProgressPage
  DownloadPage: TDownloadWizardPage;      // shown during SQL Express / Hosting Bundle downloads — real byte progress

  // Resolved during the wizard, consumed by CurStepChanged when writing the JSON config.
  HostingBundlePath:  String;  // path to a Hosting Bundle installer to run, or '' if ANCM already present / skipped
  SqlInstallMode:     String;  // 'none' | 'express' | 'localdb'
  SqlBootstrapperPath: String; // path to the downloaded SQL Server Express bootstrapper (mode = express)
  SqlLocalDbMsiPath:  String;  // path to the bundled SqlLocalDB.msi (mode = localdb)

  // True when an existing XCred install was detected on this machine — the
  // Database/IIS/Security pages are then skipped entirely and pre-filled from
  // the already-installed config, so upgrading never re-asks questions the
  // admin already answered.
  IsUpgrade: Boolean;

// ── "Please wait" feedback for blocking calls (connection tests, downloads) ──
// Pascal Script is single-threaded, so a real animated progress bar can't move
// during the blocking call itself — but the message and hourglass appear
// immediately beforehand, so the wizard never just looks frozen.
procedure ShowBusy(const Msg: String);
begin
  ProgressPage.SetText(Msg, '');
  ProgressPage.SetProgress(0, 0);
  ProgressPage.Show;
  WizardForm.Cursor := crHourGlass;
end;

procedure UpdateBusy(const Msg: String);
begin
  ProgressPage.SetText(Msg, '');
  ProgressPage.SetProgress(0, 0);
end;

procedure HideBusy;
begin
  WizardForm.Cursor := crDefault;
  ProgressPage.Hide;
end;

// ── Live log textbox, used while the background install script runs ─────────
procedure ClearLog;
begin
  LogMemo.Text := '';
  LogMemo.Visible := False;
end;

// Callback for ExecAndLogOutput — invoked once per output line, in real time,
// while Setup-XCred.ps1 is running. This is what actually drives the live log.
procedure OnInstallScriptOutput(const S: String; const Error, FirstLine: Boolean);
begin
  LogMemo.Visible := True;
  LogMemo.Lines.Add(S);
  LogMemo.SelStart := Length(LogMemo.Text);
  if Trim(S) <> '' then
    UpdateBusy(Trim(S));
end;

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

// ── Helper: does a downloaded file look like a real installer, rather than an
// HTML error/landing page saved with an .exe name? A broken or changed URL
// can return a 200 OK with an HTML body instead of failing outright — that
// silently produces a multi-hundred-KB "installer" that later crashes with a
// cryptic "not a valid application for this OS platform" when run. Real
// bootstrapper installers here are multi-MB; treat anything under 1MB as
// suspect and refuse it rather than let it reach Start-Process.
function LooksLikeRealInstaller(const Path: String): Boolean;
var
  FindRec: TFindRec;
begin
  Result := False;
  if FindFirst(Path, FindRec) then
  begin
    Result := (FindRec.SizeHigh > 0) or (FindRec.SizeLow > 1024 * 1024);
    FindClose(FindRec);
  end;
end;

// ── Helper: download a file with a real progress bar (Inno's own download
// engine — handles TLS/redirects and shows live byte progress, unlike a
// hand-rolled WinHTTP call). Saves to {tmp}\<DestFileName> on success.
function DownloadFileWithProgress(const Url, DestFileName: String): Boolean;
var
  DestPath: String;
begin
  Result := False;
  DownloadPage.Clear;
  DownloadPage.Add(Url, DestFileName, '');
  DownloadPage.Show;
  try
    try
      DownloadPage.Download;
      DestPath := ExpandConstant('{tmp}\' + DestFileName);
      Result := LooksLikeRealInstaller(DestPath);
      if not Result then
        DeleteFile(DestPath);
    except
      Result := False;
    end;
  finally
    DownloadPage.Hide;
  end;
end;

// ── Helper: try to open one ADO connection string; used by TestSqlConnection ─
function TryOpenAdoConnection(const ConnStr: String; var ErrMsg: String): Boolean;
var
  Conn: Variant;
begin
  Result := False;
  try
    Conn := CreateOleObject('ADODB.Connection');
    Conn.ConnectionTimeout := 6;
    Conn.Open(ConnStr);
    Conn.Close;
    Result := True;
  except
    ErrMsg := GetExceptionMessage;
    Result := False;
  end;
end;

// ── Helper: candidate 'master'-scoped connection strings for a server/login,
// modern OLE DB providers first (MSOLEDBSQL / SQL Server Native Client),
// which understand Encrypt/TrustServerCertificate the same way SqlClient does
// and are what recent SQL Server versions (2022/2025) expect. Recent SqlClient
// and OLE DB drivers default to requiring an encrypted connection; if the
// target instance isn't set up with a trusted TLS certificate, that handshake
// can fail outright even with TrustServerCertificate set (it only skips
// certificate *validation*, not the encryption negotiation itself). Encrypt=no
// sidesteps that entirely for what's normally a same-host/same-LAN connection.
// Ends with the legacy in-box SQLOLEDB provider, since it predates these
// keywords and may not reach newer SQL Server versions at all.
function BuildMasterConnStrings(const Server, User, Pass: String): TArrayOfString;
var
  AuthPart: String;
begin
  if Trim(User) = '' then
    AuthPart := 'Integrated Security=SSPI;'
  else
    AuthPart := 'User ID=' + User + ';Password=' + Pass + ';';

  SetArrayLength(Result, 4);
  Result[0] := 'Provider=MSOLEDBSQL19;Data Source=' + Server + ';Initial Catalog=master;' + AuthPart + 'Encrypt=no;TrustServerCertificate=yes;';
  Result[1] := 'Provider=MSOLEDBSQL;Data Source=' + Server + ';Initial Catalog=master;' + AuthPart + 'Encrypt=no;TrustServerCertificate=yes;';
  Result[2] := 'Provider=SQLNCLI11;Data Source=' + Server + ';Initial Catalog=master;' + AuthPart + 'Encrypt=no;TrustServerCertificate=yes;';
  Result[3] := 'Provider=SQLOLEDB;Data Source=' + Server + ';Initial Catalog=master;' + AuthPart;
end;

// ── Helper: test SQL Server connectivity against the 'master' database ──────
function TestSqlConnection(const Server, User, Pass: String; var ErrMsg: String): Boolean;
var
  ConnStrs: TArrayOfString;
  i: Integer;
begin
  Result := False;
  ErrMsg := '';
  ConnStrs := BuildMasterConnStrings(Server, User, Pass);
  for i := 0 to GetArrayLength(ConnStrs) - 1 do
    if TryOpenAdoConnection(ConnStrs[i], ErrMsg) then
    begin
      Result := True;
      Exit;
    end;
end;

// ── Helper: run a scalar query against 'master' (e.g. cross-database checks),
// trying the same provider fallback chain as TestSqlConnection. Returns ''
// if no provider could run it — callers should treat that as "unknown",
// not as a specific query result.
function QueryScalarFromMaster(const Server, User, Pass, Sql: String): String;
var
  ConnStrs: TArrayOfString;
  i: Integer;
  Conn, Rs: Variant;
begin
  Result := '';
  ConnStrs := BuildMasterConnStrings(Server, User, Pass);
  for i := 0 to GetArrayLength(ConnStrs) - 1 do
  begin
    try
      Conn := CreateOleObject('ADODB.Connection');
      Conn.ConnectionTimeout := 6;
      Conn.Open(ConnStrs[i]);
      Rs := Conn.Execute(Sql);
      if not Rs.EOF then
        Result := Rs.Fields.Item(0).Value;
      Rs.Close;
      Conn.Close;
      Exit;
    except
      // try the next provider
    end;
  end;
end;

// ── Check whether the chosen database already exists, and if so, summarize
// its migration state so the user can decide whether to reuse it. dbcreator's
// auto-ownership (granted during install) only applies to databases the app
// pool identity creates itself — an existing database needs its own grant,
// which the install script handles, but the user should get to choose
// whether reusing it (and letting XCred update its schema) is what they want.
function CheckExistingDatabase(const Server, User, Pass, DbName: String; var Summary: String): Boolean;
var
  ExistsFlag, HistoryFlag, LastMigration: String;
begin
  Result := False;
  Summary := '';

  ExistsFlag := QueryScalarFromMaster(Server, User, Pass,
    'SELECT CASE WHEN DB_ID(N''' + DbName + ''') IS NOT NULL THEN 1 ELSE 0 END');
  if ExistsFlag <> '1' then Exit;

  Result := True;
  HistoryFlag := QueryScalarFromMaster(Server, User, Pass,
    'SELECT CASE WHEN EXISTS (SELECT 1 FROM [' + DbName + '].sys.tables WHERE name = ''__EFMigrationsHistory'') THEN 1 ELSE 0 END');

  if HistoryFlag = '1' then
  begin
    LastMigration := QueryScalarFromMaster(Server, User, Pass,
      'SELECT TOP 1 MigrationId FROM [' + DbName + '].dbo.__EFMigrationsHistory ORDER BY MigrationId DESC');
    if LastMigration <> '' then
      Summary := 'It already has an XCred schema — last applied migration: ' + LastMigration + '.'
    else
      Summary := 'It has an XCred migration history table, but no migrations recorded yet.';
  end
  else
    Summary := 'It exists, but has no XCred schema yet (it may be empty, or used by something else).';
end;

// ── Helper: index of the last occurrence of Ch in S, or 0 if none ───────────
function LastIndexOfChar(const Ch: Char; const S: String): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Length(S) downto 1 do
  begin
    if S[i] = Ch then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

// ── Helper: check whether a TCP port is already taken, and by what ──────────
// First asks IIS directly (so we can tell a harmless 'Default Web Site'
// binding apart from a real conflict); falls back to a raw netstat/tasklist
// scan so non-IIS processes (another app, a dev server, etc.) are caught too.
function CheckPortConflict(const Port: String; var Detail: String; var IsDefaultSite: Boolean): Boolean;
var
  TmpFile, AppCmdExe, Line, Pid, ProcLine: String;
  Lines, ProcLines: TArrayOfString;
  i, p1, p2, rc: Integer;
begin
  Result := False;
  IsDefaultSite := False;
  Detail := '';
  TmpFile := ExpandConstant('{tmp}\xcred_portcheck.txt');
  AppCmdExe := ExpandConstant('{sys}\inetsrv\appcmd.exe');

  // 1. Ask IIS directly, if it's installed
  if FileExists(AppCmdExe) then
  begin
    Exec(ExpandConstant('{cmd}'), '/c "' + AppCmdExe + '" list site > "' + TmpFile + '" 2>&1',
         '', SW_HIDE, ewWaitUntilTerminated, rc);
    if LoadStringsFromFile(TmpFile, Lines) then
    begin
      for i := 0 to GetArrayLength(Lines) - 1 do
      begin
        Line := Lines[i];
        if Pos(':' + Port + ':', Line) > 0 then
        begin
          Result := True;
          p1 := Pos('"', Line);
          p2 := 0;
          if p1 > 0 then p2 := Pos('"', Copy(Line, p1 + 1, Length(Line)));
          if (p1 > 0) and (p2 > 0) then
            Detail := Copy(Line, p1 + 1, p2 - 1)
          else
            Detail := 'an existing IIS site';
          IsDefaultSite := (Detail = 'Default Web Site');
          Exit;
        end;
      end;
    end;
  end;

  // 2. Fall back to a raw TCP listener scan (catches non-IIS processes)
  Exec(ExpandConstant('{cmd}'), '/c netstat -ano -p tcp > "' + TmpFile + '" 2>&1',
       '', SW_HIDE, ewWaitUntilTerminated, rc);
  if LoadStringsFromFile(TmpFile, Lines) then
  begin
    for i := 0 to GetArrayLength(Lines) - 1 do
    begin
      Line := Lines[i];
      if (Pos('LISTENING', Line) > 0) and (Pos(':' + Port + ' ', Line) > 0) then
      begin
        Result := True;
        Pid := Trim(Copy(Line, LastIndexOfChar(' ', Line) + 1, Length(Line)));
        Detail := 'another process (PID ' + Pid + ')';
        Exec(ExpandConstant('{cmd}'), '/c tasklist /FI "PID eq ' + Pid + '" /FO CSV /NH > "' + TmpFile + '" 2>&1',
             '', SW_HIDE, ewWaitUntilTerminated, rc);
        if LoadStringsFromFile(TmpFile, ProcLines) then
          if GetArrayLength(ProcLines) > 0 then
          begin
            ProcLine := ProcLines[0];
            p2 := Pos(',', ProcLine);
            if p2 > 2 then
              Detail := Trim(Copy(ProcLine, 2, p2 - 3)) + ' (PID ' + Pid + ')';
          end;
        Exit;
      end;
    end;
  end;
end;

// ── Helpers used to detect and read back an existing install's settings ─────
function SplitBySemicolon(const S: String): TArrayOfString;
var
  Rest, Part: String;
  P, Count: Integer;
begin
  SetArrayLength(Result, 0);
  Rest := S;
  Count := 0;
  while Length(Rest) > 0 do
  begin
    P := Pos(';', Rest);
    if P = 0 then
    begin
      Part := Rest;
      Rest := '';
    end
    else
    begin
      Part := Copy(Rest, 1, P - 1);
      Rest := Copy(Rest, P + 1, Length(Rest));
    end;
    if Trim(Part) <> '' then
    begin
      SetArrayLength(Result, Count + 1);
      Result[Count] := Part;
      Count := Count + 1;
    end;
  end;
end;

// Reads one key's value out of a 'Key1=Value1;Key2=Value2;...' connection string.
function ExtractConnStrValue(const ConnStr, Key: String): String;
var
  Parts: TArrayOfString;
  i, p: Integer;
  PartKey: String;
begin
  Result := '';
  Parts := SplitBySemicolon(ConnStr);
  for i := 0 to GetArrayLength(Parts) - 1 do
  begin
    p := Pos('=', Parts[i]);
    if p > 0 then
    begin
      PartKey := Trim(Copy(Parts[i], 1, p - 1));
      if CompareText(PartKey, Key) = 0 then
      begin
        Result := Trim(Copy(Parts[i], p + 1, Length(Parts[i])));
        Exit;
      end;
    end;
  end;
end;

// Crude but sufficient extractor for "Key": "Value" out of our own appsettings
// JSON files — good enough since we only ever read back JSON our own
// Setup-XCred.ps1 wrote via ConvertTo-Json, a known, consistent shape.
function ExtractJsonStringValue(const Content, Key: String): String;
var
  p1, p2, p3: Integer;
begin
  Result := '';
  p1 := Pos('"' + Key + '"', Content);
  if p1 = 0 then Exit;
  p1 := p1 + Length('"' + Key + '"');
  p2 := Pos('"', Copy(Content, p1, Length(Content) - p1 + 1));
  if p2 = 0 then Exit;
  p1 := p1 + p2;
  p3 := Pos('"', Copy(Content, p1, Length(Content) - p1 + 1));
  if p3 = 0 then Exit;
  Result := Copy(Content, p1, p3 - 1);
end;

// Finds the port an existing IIS site is bound to, by name (reuses the same
// appcmd text-scraping approach as CheckPortConflict).
function GetExistingSitePort(const SiteName: String): String;
var
  TmpFile, Line: String;
  Lines: TArrayOfString;
  i, p1, p2, rc: Integer;
  AppCmdExe: String;
begin
  Result := '';
  AppCmdExe := ExpandConstant('{sys}\inetsrv\appcmd.exe');
  if not FileExists(AppCmdExe) then Exit;

  TmpFile := ExpandConstant('{tmp}\xcred_siteport.txt');
  Exec(ExpandConstant('{cmd}'), '/c "' + AppCmdExe + '" list site > "' + TmpFile + '" 2>&1',
       '', SW_HIDE, ewWaitUntilTerminated, rc);
  if LoadStringsFromFile(TmpFile, Lines) then
  begin
    for i := 0 to GetArrayLength(Lines) - 1 do
    begin
      Line := Lines[i];
      if Pos('"' + SiteName + '"', Line) > 0 then
      begin
        p1 := Pos('http/*:', Line);
        if p1 > 0 then
        begin
          p1 := p1 + Length('http/*:');
          p2 := Pos(':', Copy(Line, p1, Length(Line) - p1 + 1));
          if p2 > 0 then
            Result := Copy(Line, p1, p2 - 1);
        end;
        Exit;
      end;
    end;
  end;
end;

// ── Detect an existing XCred install and pre-fill the wizard from it ────────
// Looks at the same files/registry key the previous install's Setup-XCred.ps1
// itself wrote — if they parse out to a usable connection string and site
// name, treat this run as an upgrade: ShouldSkipPage hides the Database/IIS/
// Security pages entirely, and NextButtonClick skips their validation/prompts.
// Any parsing hiccup safely falls back to IsUpgrade = False (i.e. behaves
// exactly like a fresh install, asking the normal questions) rather than
// risking a silent install with broken values.
procedure DetectExistingInstall;
var
  InstallDir, ProdConfigPath, BaseConfigPath: String;
  ProdContent, BaseContent: AnsiString;
  ConnStr: String;
  ExistingSiteName, ExistingPort, ParsedServer, ParsedDb: String;
begin
  IsUpgrade := False;

  if not RegQueryStringValue(HKLM, 'Software\XCred', 'SiteName', ExistingSiteName) then Exit;
  if Trim(ExistingSiteName) = '' then Exit;

  // {app} isn't resolved yet this early (InitializeWizard runs before the
  // Destination Folder page, even when it's about to be skipped) — read the
  // previous install's own directory back from the registry instead.
  if not RegQueryStringValue(HKLM, 'Software\XCred', 'InstallDir', InstallDir) then Exit;
  if Trim(InstallDir) = '' then Exit;

  ProdConfigPath := InstallDir + '\appsettings.Production.json';
  BaseConfigPath := InstallDir + '\appsettings.json';
  if not (FileExists(ProdConfigPath) and FileExists(BaseConfigPath)) then Exit;
  if not LoadStringFromFile(ProdConfigPath, ProdContent) then Exit;
  if not LoadStringFromFile(BaseConfigPath, BaseContent) then Exit;

  ConnStr := ExtractJsonStringValue(ProdContent, 'DefaultConnection');
  ParsedServer := ExtractConnStrValue(ConnStr, 'Server');
  ParsedDb := ExtractConnStrValue(ConnStr, 'Database');
  if (Trim(ParsedServer) = '') or (Trim(ParsedDb) = '') then Exit;

  IsUpgrade := True;

  PageDB.Values[0] := ParsedServer;
  PageDB.Values[1] := ParsedDb;
  PageDB.Values[2] := ExtractConnStrValue(ConnStr, 'User Id');
  PageDB.Values[3] := ExtractConnStrValue(ConnStr, 'Password');

  PageIIS.Values[0] := ExistingSiteName;
  ExistingPort := GetExistingSitePort(ExistingSiteName);
  if Trim(ExistingPort) <> '' then
    PageIIS.Values[1] := ExistingPort;
  PageIIS.Values[2] := ExtractJsonStringValue(ProdContent, 'AllowedOrigins');

  PageSecurity.Values[0] := ExtractJsonStringValue(BaseContent, 'Secret');
end;

// ── Auto-provision a local SQL engine when the user's SQL Server is unreachable
// Tries SQL Server Express (downloaded on demand); if that fails (e.g. no
// internet), falls back to the bundled SqlLocalDB.msi if one was shipped.
// On success, rewrites PageDB.Values to point at the new local instance.
function ProvisionLocalSqlEngine: Boolean;
var
  DlPath, LocalDbMsi: String;
  Downloaded: Boolean;
begin
  Result := False;

  Downloaded := DownloadFileWithProgress('https://go.microsoft.com/fwlink/?linkid=2215160', 'SQLEXPR-SSEI.exe');
  DlPath := ExpandConstant('{tmp}\SQLEXPR-SSEI.exe');

  if Downloaded then
  begin
    SqlInstallMode := 'express';
    SqlBootstrapperPath := DlPath;
    PageDB.Values[0] := '.\SQLEXPRESS';
    PageDB.Values[2] := '';
    PageDB.Values[3] := '';
    Result := True;
    Exit;
  end;

  LocalDbMsi := ExpandConstant('{tmp}\SqlLocalDB.msi');
  if FileExists(LocalDbMsi) then
  begin
    if MsgBox('Could not reach the internet to download SQL Server Express.' + #13#10#13#10 +
              'A SQL Server Express LocalDB engine is bundled with this installer instead. ' +
              'LocalDB runs per-machine rather than as a shared service, so it is best suited ' +
              'to single-server/offline setups rather than large shared deployments — but it will ' +
              'let XCred run fully offline.' + #13#10#13#10 +
              'Install LocalDB now?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      SqlInstallMode := 'localdb';
      SqlLocalDbMsiPath := LocalDbMsi;
      PageDB.Values[0] := '(localdb)\MSSQLLocalDB';
      PageDB.Values[2] := '';
      PageDB.Values[3] := '';
      Result := True;
    end;
  end
  else
  begin
    MsgBox('Could not download SQL Server Express, and no offline LocalDB package is bundled with this installer.' + #13#10#13#10 +
           'Install SQL Server manually, then re-run XCred Setup.', mbError, MB_OK);
  end;
end;

// ── Helper: is the ASP.NET Core Module V2 already present? Its install
// location has moved across Hosting Bundle versions — older ones placed it
// under System32\inetsrv; current ones install it under Program Files
// instead. Check both, so an already-working install isn't reported missing
// (which would trigger a needless ~100MB download here in the wizard).
function IsAncmInstalled: Boolean;
begin
  Result :=
    FileExists(ExpandConstant('{sys}\inetsrv\aspnetcorev2.dll')) or
    FileExists(ExpandConstant('{pf}\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll')) or
    FileExists(ExpandConstant('{pf32}\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll'));
end;

// ── Resolve the .NET Hosting Bundle before Install starts (still interactive,
// so a failed download can fall back to browsing for a local copy) ──────────
procedure ResolveHostingBundle;
var
  DlPath, Picked: String;
  Downloaded: Boolean;
begin
  HostingBundlePath := '';
  if IsAncmInstalled then Exit;

  // NOTE: the "permalink" URL (dotnet.microsoft.com/permalink/...) resolves to an
  // HTML "thank you" landing page, not the binary — its real download is started
  // by JavaScript on that page. aka.ms/dotnet/<channel>/dotnet-hosting-win.exe is
  // Microsoft's documented automation-friendly evergreen link and redirects
  // straight to the .exe (verified: 30x chain ending in application/octet-stream).
  Downloaded := DownloadFileWithProgress('https://aka.ms/dotnet/10.0/dotnet-hosting-win.exe', 'dotnet-hosting-win.exe');
  DlPath := ExpandConstant('{tmp}\dotnet-hosting-win.exe');
  if Downloaded then
  begin
    HostingBundlePath := DlPath;
    Exit;
  end;

  if MsgBox('Could not download the .NET Hosting Bundle (no internet access?).' + #13#10#13#10 +
            'If you already have the installer (dotnet-hosting-win.exe) on this machine or a USB drive, ' +
            'click Yes to browse for it. Click No to install it manually later.',
            mbConfirmation, MB_YESNO) = IDYES then
  begin
    Picked := '';
    if GetOpenFileName('Locate the .NET Hosting Bundle installer', Picked, '',
                        'Installer files (*.exe)|*.exe', 'exe') then
      HostingBundlePath := Picked
    else
      MsgBox('No installer selected. XCred will be installed, but the website will not start until the .NET Hosting Bundle is installed manually.', mbInformation, MB_OK);
  end
  else
    MsgBox('XCred will be installed, but the website will not start until the .NET Hosting Bundle is installed manually.', mbInformation, MB_OK);
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

// ── Build the connection string from the SQL page inputs ─────────────────────
function BuildConnectionString: String;
var
  Server, Database, User, Pass: String;
begin
  Server   := PageDB.Values[0];
  Database := PageDB.Values[1];
  User     := PageDB.Values[2];
  Pass     := PageDB.Values[3];

  // Encrypt=False: recent SqlClient/OLE DB drivers default to requiring an
  // encrypted connection, which can fail outright against a SQL Server
  // instance with no TLS certificate configured (common for local/on-prem
  // installs). This is a same-host/same-LAN connection in the vast majority
  // of setups this installer targets, so skip encryption negotiation entirely
  // rather than relying on TrustServerCertificate alone to paper over it.
  if User = '' then
    // Windows Authentication
    Result := 'Server=' + Server + ';Database=' + Database +
              ';Trusted_Connection=True;Encrypt=False;TrustServerCertificate=True;'
  else
    // SQL Server Authentication
    Result := 'Server=' + Server + ';Database=' + Database +
              ';User Id=' + User + ';Password=' + Pass +
              ';Encrypt=False;TrustServerCertificate=True;';
end;

// ── Create all custom pages ───────────────────────────────────────────────────
procedure InitializeWizard;
begin
  SqlInstallMode := 'none';
  SqlBootstrapperPath := '';
  SqlLocalDbMsiPath := '';
  HostingBundlePath := '';

  ProgressPage := CreateOutputProgressPage('Please wait', 'XCred Setup is working. This will only take a moment.');
  DownloadPage := CreateDownloadPage('Downloading', 'A required component is being downloaded.', nil);
  DownloadPage.ShowBaseNameInsteadOfUrl := True;

  // Scrolling log textbox, shown below the status text/progress bar. Only
  // made visible once there's something to show (see AppendLogLines) so the
  // short waits (SQL test, port check) keep their current simple look.
  LogMemo := TNewMemo.Create(ProgressPage);
  LogMemo.Left := 0;
  LogMemo.Top := ScaleY(48);
  LogMemo.Width := ProgressPage.SurfaceWidth;
  LogMemo.Height := ProgressPage.SurfaceHeight - LogMemo.Top;
  LogMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  LogMemo.ScrollBars := ssVertical;
  LogMemo.ReadOnly := True;
  LogMemo.Font.Name := 'Consolas';
  LogMemo.Font.Size := 8;
  LogMemo.Text := '';
  LogMemo.Visible := False;
  LogMemo.Parent := ProgressPage.Surface;

  // ── Page: Database ─────────────────────────────────────────────────────────
  PageDB := CreateInputQueryPage(wpSelectDir,
    'Database Configuration',
    'XCred stores encrypted credentials in SQL Server.',
    'Enter the SQL Server connection details. ' +
    'Leave Username blank to use Windows Authentication (recommended for domain environments). ' +
    'Clicking Next will test this connection.');

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

  // Must run last: it needs PageDB/PageIIS/PageSecurity to already exist so
  // it can pre-fill them from an existing install, if one is found.
  DetectExistingInstall;
end;

// Hides the Database/IIS/Security pages entirely once an existing install was
// detected — they're already pre-filled with working values in that case, so
// showing them would just be re-asking questions the admin already answered.
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := IsUpgrade and
    ((PageID = wpSelectDir) or (PageID = PageDB.ID) or (PageID = PageIIS.ID) or (PageID = PageSecurity.ID));
end;

// ── Input validation on Next ──────────────────────────────────────────────────
function NextButtonClick(CurPageID: Integer): Boolean;
var
  PortNum:    Integer;
  SqlErr:     String;
  SqlOk:      Boolean;
  Choice:     Integer;
  PortBusy:   Boolean;
  IsDefault:  Boolean;
  ConflictInfo: String;
  DbExists:   Boolean;
  DbSummary:  String;
begin
  Result := True;

  // Upgrading an existing install: values were already read back from the
  // current config in DetectExistingInstall — skip validation and any of the
  // prompts below entirely (matches ShouldSkipPage hiding these pages).
  // The Ready-to-install page's Hosting Bundle check further below still
  // runs — it's a no-op if already installed, and idempotent otherwise.
  if IsUpgrade and
     ((CurPageID = PageDB.ID) or (CurPageID = PageIIS.ID) or (CurPageID = PageSecurity.ID)) then
    Exit;

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

    // Test connectivity — unless we've already auto-provisioned a local engine
    // for a not-yet-created instance in a previous pass through this page.
    if SqlInstallMode = 'none' then
    begin
      ShowBusy('Testing the SQL Server connection...');
      SqlOk := TestSqlConnection(PageDB.Values[0], PageDB.Values[2], PageDB.Values[3], SqlErr);
      HideBusy;
      if not SqlOk then
      begin
        Choice := MsgBox(
          'Could not connect to SQL Server "' + PageDB.Values[0] + '":' + #13#10 + SqlErr + #13#10#13#10 +
          'XCred can install a local SQL Server Express instance for you now.' + #13#10#13#10 +
          'Click Yes to install SQL Server Express automatically (requires internet access on this machine).' + #13#10 +
          'Click No to go back and fix the connection details (e.g. if the server is remote).',
          mbConfirmation, MB_YESNO);

        if Choice = IDYES then
        begin
          if not ProvisionLocalSqlEngine then
          begin
            Result := False; Exit;
          end;
          // PageDB.Values now point at the instance the install script will create.
        end
        else
        begin
          Result := False; Exit;
        end;
      end
      else
      begin
        // Connection succeeded against the user's own server — check whether
        // this database name is a fresh one or already exists.
        ShowBusy('Checking whether the database already exists...');
        DbExists := CheckExistingDatabase(PageDB.Values[0], PageDB.Values[2], PageDB.Values[3], Trim(PageDB.Values[1]), DbSummary);
        HideBusy;
        if DbExists then
        begin
          if MsgBox('A database named "' + Trim(PageDB.Values[1]) + '" already exists on this SQL Server.' + #13#10#13#10 +
                    DbSummary + #13#10#13#10 +
                    'Click Yes to use this existing database — XCred will safely apply any pending schema updates to it when it starts.' + #13#10 +
                    'Click No to go back and choose a different database name instead.',
                    mbConfirmation, MB_YESNO) = IDNO then
          begin
            Result := False; Exit;
          end;
        end;
      end;
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

    ShowBusy('Checking whether port ' + Trim(PageIIS.Values[1]) + ' is available...');
    PortBusy := CheckPortConflict(Trim(PageIIS.Values[1]), ConflictInfo, IsDefault);
    HideBusy;
    if PortBusy then
    begin
      if IsDefault then
      begin
        if MsgBox('Port ' + PageIIS.Values[1] + ' is currently used by IIS''s "Default Web Site". ' +
                  'XCred will stop and replace it automatically during install.' + #13#10#13#10 +
                  'Continue with this port?', mbConfirmation, MB_YESNO) = IDNO then
        begin
          Result := False; Exit;
        end;
      end
      else
      begin
        MsgBox('Port ' + PageIIS.Values[1] + ' is already in use by ' + ConflictInfo + '.' + #13#10 +
               'Choose a different port, or free this one, then try again.', mbError, MB_OK);
        Result := False; Exit;
      end;
    end;
  end;

  if CurPageID = PageSecurity.ID then
  begin
    if (PageSecurity.Values[0] <> '') and (Length(Trim(PageSecurity.Values[0])) < 32) then begin
      MsgBox('The JWT secret key must be at least 32 characters. Leave it blank to auto-generate a secure key.', mbError, MB_OK);
      Result := False; Exit;
    end;
  end;

  if CurPageID = wpReady then
    ResolveHostingBundle;
end;

// ── Helper: open a file in Notepad, without blocking the installer on it ────
procedure OpenInNotepad(const Path: String);
var
  rc: Integer;
begin
  if FileExists(Path) then
    Exec('notepad.exe', '"' + Path + '"', '', SW_SHOW, ewNoWait, rc);
end;

// ── Write config JSON + kick off PowerShell setup ────────────────────────────
// ── Run the IIS/config PowerShell script and report success or failure ───────
// Uses Inno's built-in ExecAndLogOutput, which captures the child's output
// line-by-line in real time and invokes OnInstallScriptOutput for each line —
// this drives the live log textbox with no manual polling, temp-file
// signaling, or deadlock risk (Inno owns the pipe reading internally).
procedure RunSetupScript;
var
  ResultCode: Integer;
  Launched: Boolean;
  ScriptPath, ConfigPath, LogPath, Params: String;
begin
  ScriptPath := ExpandConstant('{tmp}\Setup-XCred.ps1');
  ConfigPath := ExpandConstant('{tmp}\xcred-install.json');
  LogPath    := ExpandConstant('{%TEMP}\XCred-Install.log');
  Params     := '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath +
                 '" -ConfigFile "' + ConfigPath + '"';

  ShowBusy('Configuring SQL Server, IIS and application settings...');
  ClearLog;
  try
    Launched := ExecAndLogOutput('powershell.exe', Params, '', SW_HIDE,
                                  ewWaitUntilTerminated, ResultCode, @OnInstallScriptOutput);
  finally
    HideBusy;
  end;

  if not Launched then
  begin
    MsgBox('Could not launch the configuration script (PowerShell).' + #13#10 +
           'XCred files were copied, but setup was not completed.', mbError, MB_OK);
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    MsgBox('XCred files were installed, but configuration failed (exit code '
           + IntToStr(ResultCode) + ').' + #13#10 + #13#10 +
           'The log file will now open in Notepad:' + #13#10 + '    ' + LogPath + #13#10 + #13#10 +
           'Common causes: a reboot is needed to finish enabling Windows features, ' +
           'the chosen port is in use, or SQL Server could not be reached. ' +
           'Fix the issue and re-run the installer.',
           mbError, MB_OK);
    OpenInNotepad(LogPath);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigPath, Json: String;
  InstallDir:       String;
begin
  // After files are copied, run the configuration script and report result.
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
    '  "InstallDir": "'            + EscapeJson(InstallDir)             + '",' + #13#10 +
    '  "ConnectionString": "'      + EscapeJson(BuildConnectionString)  + '",' + #13#10 +
    '  "JwtSecret": "'             + EscapeJson(GetJwtSecret)           + '",' + #13#10 +
    '  "SiteName": "'              + EscapeJson(GetSiteName(''))        + '",' + #13#10 +
    '  "Port": "'                  + EscapeJson(GetPort(''))            + '",' + #13#10 +
    '  "AppBaseUrl": "'            + EscapeJson(GetAppBaseUrl(''))      + '",' + #13#10 +
    '  "HostingBundlePath": "'     + EscapeJson(HostingBundlePath)      + '",' + #13#10 +
    '  "SqlInstallMode": "'        + EscapeJson(SqlInstallMode)         + '",' + #13#10 +
    '  "SqlBootstrapperPath": "'   + EscapeJson(SqlBootstrapperPath)    + '",' + #13#10 +
    '  "SqlLocalDbMsiPath": "'     + EscapeJson(SqlLocalDbMsiPath)      + '"'  + #13#10 +
    '}';

  if not SaveStringToFile(ConfigPath, Json, False) then
    MsgBox('Could not write configuration file. Installation may fail.', mbError, MB_OK);
end;
