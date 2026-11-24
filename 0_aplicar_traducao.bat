@echo off
setlocal
rem Recria disc\Baroque (English) (Track 1).bin a partir do dump japones.
rem (Ja foi feito uma vez. So rode de novo se precisar refazer.)
rem O seu dump e de uma fonte diferente da que o tradutor usou, entao o xdelta
rem e aplicado sem checagem (-n) e depois os setores 16 e 22 tem EDC/ECC corrigidos.
cd /d "%~dp0"
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY ( echo Python nao encontrado. Instale em python.org. & pause & exit /b 1 )
set "ORIG=disc\Baroque - Yuganda Mousou (Japan) (Track 1).bin"
if not exist "%ORIG%" ( echo Coloque "%ORIG%" na pasta disc. & pause & exit /b 1 )
"tools\xdelta\xdelta3-3.1.0-x86_64.exe" -d -n -f -s "%ORIG%" "disc\baroque_english_v1.0.2\BAROQUE.xdelta" "disc\Baroque (English) (Track 1).bin"
if errorlevel 1 ( echo ERRO no xdelta. & pause & exit /b 1 )
%PY% tools\psxdisc.py fixsectors "disc\Baroque (English) (Track 1).bin" 16 22
pause
