@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
set CMAKE="C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set NINJA_DIR=C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja
set PATH=%NINJA_DIR%;%PATH%

if not exist C:\games\source\multirealm-core\build mkdir C:\games\source\multirealm-core\build
cd /d C:\games\source\multirealm-core\build

echo === CONFIGURING CMAKE ===
%CMAKE% -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
  -DCMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake ^
  -DVCPKG_TARGET_TRIPLET=x64-windows-static-md ^
  -DVCPKG_MANIFEST_MODE=OFF ^
  -DVCPKG_INSTALLED_DIR=C:/vcpkg/installed ^
  -DAPPS_BUILD=world-only ^
  -DTOOLS_BUILD=none ^
  -DBUILD_TESTING=OFF ^
  -DMODULES=static ^
  -DSCRIPTS=static ^
  -DCMAKE_POLICY_DEFAULT_CMP0167=NEW ^
  "-DCMAKE_EXE_LINKER_FLAGS=/FORCE:MULTIPLE" ^
  -DWITH_WARNINGS=OFF ^
  -DMYSQL_INCLUDE_DIR=C:/vcpkg/installed/x64-windows-static-md/include/mysql ^
  -DMYSQL_LIBRARY=C:/vcpkg/installed/x64-windows-static-md/lib/mysqlclient.lib ^
  -DMYSQL_EXECUTABLE=C:/vcpkg/installed/x64-windows-static-md/tools/libmysql/mysql.exe ^
  -DBoost_DIR=C:/vcpkg/installed/x64-windows-static-md/share/boost ^
  C:\games\source\multirealm-core

if errorlevel 1 (
    echo === CMAKE CONFIGURE FAILED ===
    exit /b 1
)

echo === BUILDING WORLDSERVER ===
ninja -j 12 worldserver
if errorlevel 1 (
    echo === BUILD FAILED ===
    exit /b 1
)

echo === BUILD SUCCEEDED ===
