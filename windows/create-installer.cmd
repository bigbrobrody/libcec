@echo off

set EXITCODE=1
SET MYDIR=%~dp0
set MSGPREFIX=%~n0: 

rem Check for support folder
IF NOT EXIST "%MYDIR%..\support\windows\p8-usbcec-driver-installer.exe" (
  echo. %MSGPREFIX%Support submodule was not checked out
  goto RETURNEXIT
)

rem Check for NSIS
IF EXIST "%ProgramFiles%\NSIS\makensis.exe" (
  set NSIS="%ProgramFiles%\NSIS\makensis.exe"
) ELSE IF EXIST "%ProgramFiles(x86)%\NSIS\makensis.exe" (
  set NSIS="%ProgramFiles(x86)%\NSIS\makensis.exe"
) ELSE GOTO NONSIS

rem Check for VC12
IF "%VS120COMNTOOLS%"=="" (
  set COMPILER12="%ProgramFiles(x86)%\Microsoft Visual Studio 14.0\Common7\IDE\devenv.com"
) ELSE IF EXIST "%VS120COMNTOOLS%\..\IDE\VCExpress.exe" (
  set COMPILER12="%VS120COMNTOOLS%\..\IDE\VCExpress.exe"
) ELSE IF EXIST "%VS120COMNTOOLS%\..\IDE\devenv.com" (
  set COMPILER12="%VS120COMNTOOLS%\..\IDE\devenv.com"
) ELSE GOTO NOSDK11

echo. %MSGPREFIX%COMPILER12=%COMPILER12%

echo. %MSGPREFIX%removing %MYDIR%..\build
rmdir /s /q %MYDIR%..\build
echo. %MSGPREFIX%Calling build.cmd
call build.cmd
IF NOT ERRORLEVEL 0 (
  GOTO ERRORCREATINGINSTALLER
)

copy "%MYDIR%..\support\windows\p8-usbcec-driver-installer.exe" "%MYDIR%..\build\."
cd "%MYDIR%..\project"

rem Skip to libCEC/x86 when we're running on win32
if "%PROCESSOR_ARCHITECTURE%"=="x86" if "%PROCESSOR_ARCHITEW6432%"=="" goto libcecx86

rem Compile libCEC and cec-client x64
echo.
echo. %MSGPREFIX%Cleaning libCEC (x64)
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Clean "Release|x64"
%COMPILER12% libcec.sln /Clean "Release|x64"
echo.
echo. %MSGPREFIX%Compiling libCEC (x64)
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Build "Release|x64" /Project LibCecSharp
%COMPILER12% libcec.sln /Build "Release|x64" /Project LibCecSharp
echo.
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Build "Release|x64"
%COMPILER12% libcec.sln /Build "Release|x64"
echo.
echo. %MSGPREFIX%Compiling .Net applications
echo. %MSGPREFIX%Running %COMPILER12% cec-dotnet.sln /Build "Release|x64"
cd "%MYDIR%..\src\dotnet\project"
%COMPILER12% cec-dotnet.sln /Build "Release|x64"
echo.
echo. %MSGPREFIX%Copying executables into %MYDIR%..\build\amd64
copy ..\build\x64\CecSharpTester.exe %MYDIR%..\build\amd64\CecSharpTester.exe
copy ..\build\x64\cec-tray.exe %MYDIR%..\build\amd64\cec-tray.exe

:libcecx86
rem Compile libCEC and cec-client Win32
cd "%MYDIR%..\project"
echo.
echo. %MSGPREFIX%Cleaning libCEC (x86)
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Clean "Release|x86"
%COMPILER12% libcec.sln /Clean "Release|x86"
echo.
echo. %MSGPREFIX%Compiling libCEC (x86)
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Build "Release|x86" /Project LibCecSharp
%COMPILER12% libcec.sln /Build "Release|x86" /Project LibCecSharp
echo.
echo. %MSGPREFIX%Running %COMPILER12% libcec.sln /Build "Release|x86"
%COMPILER12% libcec.sln /Build "Release|x86"
echo.
echo. %MSGPREFIX%Compiling .Net applications
echo. %MSGPREFIX%Running %COMPILER12% cec-dotnet.sln /Build "Release|x86"
cd "%MYDIR%..\src\dotnet\project"
%COMPILER12% cec-dotnet.sln /Build "Release|x86"
echo.
echo. %MSGPREFIX%Copying executables into %MYDIR%..\build\x86
copy ..\build\x86\CecSharpTester.exe %MYDIR%..\build\x86\CecSharpTester.exe
copy ..\build\x86\cec-tray.exe %MYDIR%..\build\x86\cec-tray.exe
cd "%MYDIR%..\project"

rem Clean things up before creating the installer
echo.
echo. %MSGPREFIX%Deleting .pdb files
del /q /f %MYDIR%..\build\x86\LibCecSharp.pdb
del /q /f %MYDIR%..\build\amd64\LibCecSharp.pdb

rem Check for sign-binary.cmd, only present on the Pulse-Eight production build system
rem Calls signtool.exe and signs the DLLs with Pulse-Eight's code signing key
IF NOT EXIST "..\support\private\sign-binary.cmd" GOTO CREATEINSTALLER
echo.
echo. %MSGPREFIX%Signing all binaries
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\cec.dll
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\LibCecSharp.dll
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\cec-client.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\cecc-client.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\cec-tray.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\x86\CecSharpTester.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\cec.dll
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\LibCecSharp.dll
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\cec-client.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\cecc-client.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\cec-tray.exe
CALL ..\support\private\sign-binary.cmd %MYDIR%..\build\amd64\CecSharpTester.exe

:CREATEINSTALLER
echo.
echo. %MSGPREFIX%Creating the installer
cd %MYDIR%..\build\x86
copy cec.dll libcec.dll
cd ..\amd64
copy cec.dll cec.x64.dll
cd %MYDIR%..\project
%NSIS% /V1 /X"SetCompressor /FINAL lzma" "libCEC.nsi"

FOR /F "delims=" %%F IN ('dir /b /s "%MYDIR%..\build\libCEC-*.exe" 2^>nul') DO SET INSTALLER=%%F
IF [%INSTALLER%] == [] GOTO :ERRORCREATINGINSTALLER

rem Sign the installer if sign-binary.cmd exists
IF EXIST "..\support\private\sign-binary.cmd" (
  echo.
  echo. %MSGPREFIX%Signing the installer binaries
  CALL ..\support\private\sign-binary.cmd %INSTALLER%
)

echo.
echo. %MSGPREFIX%The installer can be found here: %INSTALLER%
set EXITCODE=0
GOTO EXIT

:NOSDK11
echo.
echo. %MSGPREFIX%Visual Studio 2012 was not found on your system.
GOTO EXIT

:NOSIS
echo.
echo. %MSGPREFIX%NSIS could not be found on your system.
GOTO EXIT

:NODDK
echo.
echo. %MSGPREFIX%Windows DDK could not be found on your system
GOTO EXIT

:ERRORCREATINGINSTALLER
echo.
echo. %MSGPREFIX%The installer could not be created. The most likely cause is that something went wrong while compiling.
GOTO RETURNEXIT

:EXIT
cd %MYDIR%

:RETURNEXIT
exit /b %EXITCODE%
pause