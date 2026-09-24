@echo on
setlocal EnableExtensions

REM Keep bun's install cache and the models.dev cache inside the work dir.
set "BUN_INSTALL_CACHE_DIR=%SRC_DIR%\.bun-cache"
set "USERPROFILE=%SRC_DIR%\.home"
if not exist "%USERPROFILE%" mkdir "%USERPROFILE%"

REM JS dependencies, exactly as pinned (with integrity hashes) by bun.lock.
bun install --frozen-lockfile
if errorlevel 1 exit 1

REM Release build for the native target only (--single), compiled with conda's
REM bun; see build.sh for the flags.
set "KILO_VERSION=%PKG_VERSION%"
set "KILO_CHANNEL=latest"
set "KILO_RELEASE=1"
set "KILO_SKIP_RELEASE_UPLOAD=1"
pushd packages\opencode
bun run script/build.ts --single --skip-install
if errorlevel 1 exit 1
popd

set "OUT=packages\opencode\dist\@kilocode\cli-windows-x64\bin"
set "LIBEXEC=%LIBRARY_PREFIX%\libexec\kilo"
if not exist "%LIBEXEC%" mkdir "%LIBEXEC%"
if not exist "%LIBRARY_BIN%" mkdir "%LIBRARY_BIN%"

xcopy /E /I /Q /Y "%OUT%" "%LIBEXEC%"
if errorlevel 1 exit 1
del /Q "%LIBEXEC%\*.map" 2>nul

REM Wrapper on PATH; kilo.exe finds its assets next to its own executable.
(
  echo @echo off
  echo "%%~dp0..\libexec\kilo\kilo.exe" %%*
) > "%LIBRARY_BIN%\kilo.bat"
if errorlevel 1 exit 1
