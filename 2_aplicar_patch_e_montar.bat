@echo off
setlocal
cd /d "%~dp0"
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY ( echo Python nao encontrado. Instale em python.org. & pause & exit /b 1 )
set "BASE=disc\Baroque (English) (Track 1).bin"
set "OUT=build\Baroque (Camera Hack) (Track 1).bin"
set "T2=Baroque - Yuganda Mousou (Japan) (Track 2).bin"
if not exist "%BASE%" ( echo Falta "%BASE%". & pause & exit /b 1 )
if not exist "%OUT%" (
  echo Copiando a imagem base para build, so na primeira vez...
  copy /y "%BASE%" "%OUT%" >nul
)
if not exist "build\%T2%" copy /y "disc\%T2%" "build\%T2%" >nul

echo [1/3] Aplicando patch\main.asm no executavel...
copy /y original\SLPM_863.41 build\SLPM_863.41 >nul
"tools\armips\armips.exe" patch\main.asm
if errorlevel 1 ( echo ERRO no armips. & pause & exit /b 1 )

echo [2/3] Gerando fonte com acentos e textos traduzidos...
if not exist patch\files\ETC mkdir patch\files\ETC
%PY% tools\fontaccents.py original\ETC\FONT.BIN patch\files\ETC\FONT.BIN
if errorlevel 1 ( echo ERRO na fonte. & pause & exit /b 1 )
%PY% tools\textpack.py .
if errorlevel 1 ( echo ERRO no texto. & pause & exit /b 1 )
%PY% tools\enciclopedia.py .
if errorlevel 1 ( echo ERRO na enciclopedia. & pause & exit /b 1 )
"tools\armips\armips.exe" patch\overlays.asm
if errorlevel 1 ( echo ERRO no armips dos overlays. & pause & exit /b 1 )

echo [3/3] Gravando executavel e arquivos na imagem...
%PY% tools\psxdisc.py inject "%OUT%" SLPM_863.41 build\SLPM_863.41
if errorlevel 1 ( echo ERRO ao gravar na imagem. & pause & exit /b 1 )
%PY% tools\psxdisc.py injectdir "%OUT%" patch\files
if errorlevel 1 ( echo ERRO ao gravar na imagem. & pause & exit /b 1 )
echo.
echo Pronto. Abra "build\Baroque (Camera Hack).cue" no DuckStation.
pause
