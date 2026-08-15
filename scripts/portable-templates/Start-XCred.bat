@echo off
REM Launches XCred in the foreground - this console window IS the "app is running"
REM indicator; closing it stops the app. For something that keeps running after you close
REM this window or log out, use Install-Service.ps1 instead (run once, as Administrator).
cd /d "%~dp0app"
echo Starting XCred...
echo Once it says "Now listening on...", open http://localhost:1507 in your browser.
echo (This window will open it for you automatically in a moment.)
echo.
echo Press Ctrl+C to stop XCred.
echo.
start "" http://localhost:1507
XCred.Api.exe
