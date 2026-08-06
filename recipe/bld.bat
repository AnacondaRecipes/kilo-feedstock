REM Install layout mirrors Homebrew: payload under Library\libexec\kilo,
REM wrapper in Library\bin so it is on PATH for conda envs on Windows.

setlocal EnableExtensions

set "LIBEXEC=%PREFIX%\Library\libexec\kilo"
set "BINDIR=%PREFIX%\Library\bin"

if not exist "%LIBEXEC%" mkdir "%LIBEXEC%"
if not exist "%BINDIR%" mkdir "%BINDIR%"

copy /Y kilo.exe "%LIBEXEC%\kilo.exe"
if errorlevel 1 exit /b 1
copy /Y kilo-sandbox-mutation-worker.js "%LIBEXEC%\kilo-sandbox-mutation-worker.js"
if errorlevel 1 exit /b 1

xcopy /E /I /Y tree-sitter "%LIBEXEC%\tree-sitter\"
if errorlevel 1 exit /b 1

if exist console (
  xcopy /E /I /Y console "%LIBEXEC%\console\"
  if errorlevel 1 exit /b 1
)

if exist kilo-sandbox-network-relay.js (
  copy /Y kilo-sandbox-network-relay.js "%LIBEXEC%\kilo-sandbox-network-relay.js"
  if errorlevel 1 exit /b 1
)

REM Wrapper bat sets asset env vars then execs the real binary.
(
  echo @echo off
  echo set "KILO_ROOT=%%~dp0.."
  echo if not defined KILO_TREE_SITTER_WASM_DIR set "KILO_TREE_SITTER_WASM_DIR=%%KILO_ROOT%%\libexec\kilo\tree-sitter"
  echo if not defined KILO_CONSOLE_ASSET_DIR if exist "%%KILO_ROOT%%\libexec\kilo\console\" set "KILO_CONSOLE_ASSET_DIR=%%KILO_ROOT%%\libexec\kilo\console"
  echo "%%KILO_ROOT%%\libexec\kilo\kilo.exe" %%*
) > "%BINDIR%\kilo.bat"
if errorlevel 1 exit /b 1

endlocal
