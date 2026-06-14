@echo off
rem libseq.bat - one entry point for the libseq helpers on Windows.
rem
rem   libseq boot             set up this device (clones every graph)
rem   libseq add <GraphName>  create a new graph (branch + submodule)
rem   libseq remove <GraphName> [-y]  remove a graph (folder + branch + submodule)
rem   libseq clean [-y]       drop local graphs whose remote branch is gone
rem
rem Everything runs through Git Bash so there's no file-association prompt.
setlocal

rem Find Git Bash: prefer one on PATH, then the standard install locations.
set "BASH="
for %%B in (bash.exe) do if not defined BASH set "BASH=%%~$PATH:B"
if not defined BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"

if not defined BASH (
    echo libseq: Git Bash not found. Install Git for Windows first. 1>&2
    exit /b 1
)

set "CMD=%~1"

if /i "%CMD%"=="boot" (
    "%BASH%" "%~dp0sys\bootstrap.sh"
    exit /b %errorlevel%
)

if /i "%CMD%"=="add" (
    if "%~2"=="" (
        echo usage: libseq add ^<GraphName^> 1>&2
        exit /b 1
    )
    "%BASH%" "%~dp0sys\add-graph.sh" "%~2"
    exit /b %errorlevel%
)

if /i "%CMD%"=="remove" (
    if "%~2"=="" (
        echo usage: libseq remove ^<GraphName^> [-y] 1>&2
        exit /b 1
    )
    "%BASH%" "%~dp0sys\remove-graph.sh" "%~2" "%~3"
    exit /b %errorlevel%
)

if /i "%CMD%"=="clean" (
    "%BASH%" "%~dp0sys\clean.sh" "%~2"
    exit /b %errorlevel%
)

echo libseq: unknown command "%CMD%". 1>&2
echo usage: 1>&2
echo   libseq boot                    set up this device 1>&2
echo   libseq add ^<GraphName^>          create a new graph 1>&2
echo   libseq remove ^<GraphName^> [-y]  remove a graph 1>&2
echo   libseq clean [-y]              drop graphs whose branch is gone 1>&2
exit /b 1
