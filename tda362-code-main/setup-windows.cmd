@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
set "setupExitCode=%ERRORLEVEL%"
echo.
if not "%setupExitCode%"=="0" echo Setup did not finish. Read the error above or send build\setup-windows.log to a lab assistant.
pause
exit /b %setupExitCode%
