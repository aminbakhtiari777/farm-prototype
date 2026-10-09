@echo off
rem ===================================================================
rem  Farm Town - LOCAL NETWORK (home Wi-Fi) server for Windows 10/11
rem  Just DOUBLE-CLICK this file. Keep the black window open while
rem  playing; close it to stop the server.
rem  Game port 9080 (WebSocket), player count / keep-alive port 9081.
rem  Matches config/server.cfg [local_network] (192.168.1.57:9080).
rem ===================================================================
setlocal
title Farm Town server - home Wi-Fi - port 9080
cd /d "%~dp0"
set "PORT=9080"
set "HEALTH=9081"
set "EXE="
set "GODOT="
set "PROJ="

rem 1) Exported game: FarmTown.exe next to this file (Windows zip) or in ..\builds\windows\
for %%F in ("%~dp0FarmTown.console.exe" "%~dp0FarmTown.exe" "%~dp0..\builds\windows\FarmTown.console.exe" "%~dp0..\builds\windows\FarmTown.exe") do (
  if not defined EXE if exist "%%~fF" set "EXE=%%~fF"
)

rem 2) Otherwise: project folder + Godot 4.7.2 editor exe
if exist "%~dp0project.godot" set "PROJ=%~dp0."
if exist "%~dp0..\project.godot" set "PROJ=%~dp0.."
if not defined EXE if defined PROJ (
  for %%G in ("%PROJ%\Godot*console*.exe" "%PROJ%\..\Godot*console*.exe" "%USERPROFILE%\Desktop\Godot*console*.exe" "%USERPROFILE%\Downloads\Godot*console*.exe" "%PROJ%\Godot*.exe" "%PROJ%\..\Godot*.exe" "%USERPROFILE%\Desktop\Godot*.exe" "%USERPROFILE%\Downloads\Godot*.exe") do (
    if not defined GODOT set "GODOT=%%~fG"
  )
)

echo.
echo  ==========  Farm Town - home Wi-Fi server  ==========
echo.
echo  This PC's address on your Wi-Fi - phones must use this one:
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /c:"IPv4"') do echo        %%A
echo  The game expects 192.168.1.57. If the address above is different,
echo  type ws://THAT-ADDRESS:9080 under "Direct connect" in the lobby.
echo.
echo  FIRST TIME: Windows Firewall asks to allow FarmTown / Godot.
echo  Tick "Private networks" and press "Allow access".
echo.
echo  Check on the phone browser:  http://192.168.1.57:9081/health
echo  It should show  {"ok":true,...}
echo.
echo  On each phone / laptop on the SAME Wi-Fi:
echo     Play - Online - Server: Local network - Host, or type the code - Join
echo.
echo  Keep this window open. Close it to stop the server.
echo  =====================================================
echo.

if defined EXE goto run_exe
if defined GODOT goto run_editor
echo  ERROR: FarmTown.exe was not found.
echo  Put this file in the same folder as FarmTown.exe - from the Windows zip -
echo  or in the "tools" folder of the game project next to a Godot 4.7.2 exe.
echo.
pause
exit /b 1

:run_exe
echo  Starting: %EXE%
rem Official export templates refuse a scene path on the command line; the Boot scene switches to the server on "-- --server".
"%EXE%" --headless -- --server --port=%PORT% --health-port=%HEALTH% --bind=0.0.0.0
goto done

:run_editor
echo  Starting with Godot: %GODOT%
if not exist "%PROJ%\.godot\" echo  First run: preparing the project, this takes a few minutes...
if not exist "%PROJ%\.godot\" "%GODOT%" --headless --path "%PROJ%" --import
"%GODOT%" --headless --path "%PROJ%" res://scenes/server/Server.tscn -- --server --port=%PORT% --health-port=%HEALTH% --bind=0.0.0.0

:done
echo.
echo  Server stopped. If it closed right away, port 9080 or 9081 may already be in use
echo  - another server window is open - close it and double-click again.
pause
