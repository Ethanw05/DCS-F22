@echo off
setlocal
set "sar_source=C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22"
set "sar_output=C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\F22-Build\radar-sar-20261028"
if not exist "%sar_output%" mkdir "%sar_output%"
cd /d "%sar_output%"
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cl /nologo /std:c++latest /O2 /EHsc /MD /W4 /WX /analyze /DNOMINMAX "%sar_source%\EFM\source\SarCore.cpp" "%sar_source%\tests\native\radar_sar_core.cpp" /Fe:radar_sar_core.exe >core-build.log 2>&1
if errorlevel 1 exit /b 1
radar_sar_core.exe >core-results.txt
if errorlevel 1 exit /b 1
cl /nologo /std:c++latest /O2 /EHsc /MD /W4 /WX /analyze /DNOMINMAX "%sar_source%\tests\native\radar_sar_scene.cpp" /Fe:radar_sar_scene.exe >scene-build.log 2>&1
if errorlevel 1 exit /b 1
radar_sar_scene.exe >scene-results.txt
exit /b %errorlevel%
