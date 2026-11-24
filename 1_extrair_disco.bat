@echo off
setlocal
rem Extrai TODOS os arquivos do jogo em ingles para a pasta extracted (so para consulta).
rem Tambem cria a pasta "original", de onde a montagem le os arquivos intactos.
cd /d "%~dp0"
"tools\mkpsxiso\mkpsxiso-2.30-win64\dumpsxiso.exe" -x extracted -s extracted\baroque.xml "disc\Baroque (English).cue"
if errorlevel 1 ( echo ERRO ao extrair. & pause & exit /b 1 )
rem A montagem le os arquivos originais de "original" (copia intacta da extracao).
if not exist original xcopy /e /i /q /y extracted original >nul
pause
