@echo off
setlocal
cd /d "%~dp0"
"tools\xdelta\xdelta3-3.1.0-x86_64.exe" -e -f -s "disc\Baroque (English) (Track 1).bin" "build\Baroque (Camera Hack) (Track 1).bin" "build\baroque_ptbr_camera_hack.xdelta"
if errorlevel 1 ( echo ERRO no xdelta. & pause & exit /b 1 )
echo Patch gerado em build\baroque_ptbr_camera_hack.xdelta
echo (aplica sobre o "Baroque (English) (Track 1).bin")
pause
