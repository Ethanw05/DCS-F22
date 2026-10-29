@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cl /nologo /std:c++latest /EHsc /W4 /WX /analyze /DNOMINMAX /D_USE_MATH_DEFINES /I"C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22\EFM\include" "C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22\tests\native\radar_camera_admission.cpp" /Fe:radar_camera.exe /Fo:radar_camera.obj
if errorlevel 1 exit /b 1
radar_camera.exe
exit /b %ERRORLEVEL%
