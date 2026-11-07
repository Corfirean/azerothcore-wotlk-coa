@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
set NINJA_DIR=C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja
set PATH=%NINJA_DIR%;%PATH%
cd /d C:\games\source\multirealm-core\build
ninja -j 12 worldserver
if errorlevel 1 (
    echo === BUILD FAILED ===
    exit /b 1
)
echo === BUILD SUCCEEDED ===
