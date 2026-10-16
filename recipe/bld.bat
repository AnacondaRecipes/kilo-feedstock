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

REM Licences of the native npm modules embedded in the executable (meta.yaml
REM license_file: third-party-licenses/); see build.sh.
set "LIC=%SRC_DIR%\third-party-licenses"
if not exist "%LIC%" mkdir "%LIC%"
set "NM=packages\opencode\node_modules"
copy /Y "%NM%\@opentui\core\LICENSE" "%LIC%\opentui-core-LICENSE" || exit 1
copy /Y "%NM%\bun-pty\LICENSE" "%LIC%\bun-pty-LICENSE" || exit 1
copy /Y "%NM%\@parcel\watcher\LICENSE" "%LIC%\parcel-watcher-LICENSE" || exit 1
copy /Y "%NM%\web-tree-sitter\LICENSE" "%LIC%\web-tree-sitter-LICENSE" || exit 1
REM opentui's native library bundles ghostty, lcms2, libwebp, stb and wuffs.
REM bun's isolated linker puts it under node_modules\.bun; fall back to hoisted.
set "OT="
for /d %%d in ("node_modules\.bun\@opentui+core-*") do (
  for /d %%e in ("%%d\node_modules\@opentui\core-*") do if not defined OT set "OT=%%e"
)
if not defined OT for /d %%e in ("node_modules\@opentui\core-*") do if not defined OT set "OT=%%e"
if not defined OT exit 1
for %%f in ("%OT%\LICENSE*" "%OT%\AUTHORS*" "%OT%\PATENTS*") do (
  copy /Y "%%f" "%LIC%\opentui-native-%%~nxf" || exit 1
)

REM Wrapper on PATH; kilo.exe finds its assets next to its own executable.
(
  echo @echo off
  echo "%%~dp0..\libexec\kilo\kilo.exe" %%*
) > "%LIBRARY_BIN%\kilo.bat"
if errorlevel 1 exit 1
