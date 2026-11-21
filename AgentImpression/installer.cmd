@echo off
rem Installation de l'agent d'impression GesCaisse sur ce poste de caisse (sans droits administrateur).
rem Copie GesCaisseAgentImpression.exe dans %LOCALAPPDATA%\GesCaisse, le lance au démarrage de Windows et maintenant.
chcp 65001 >nul
setlocal
set "DOSSIER=%LOCALAPPDATA%\GesCaisse"
set "EXE=%DOSSIER%\GesCaisseAgentImpression.exe"
if not exist "%~dp0GesCaisseAgentImpression.exe" (
  echo GesCaisseAgentImpression.exe introuvable a cote de ce fichier.
  pause & exit /b 1
)
echo Adresse de GesCaisse dans le navigateur (ex. https://caisse.masociete.com).
echo Laissez vide pour accepter toutes les adresses (deconseille).
set /p ORIGINE="Adresse : "
set "ARGS="
if not "%ORIGINE%"=="" set "ARGS=--origine %ORIGINE%"
taskkill /im GesCaisseAgentImpression.exe /f >nul 2>&1
if not exist "%DOSSIER%" mkdir "%DOSSIER%"
copy /y "%~dp0GesCaisseAgentImpression.exe" "%EXE%" >nul
powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Startup')+'\GesCaisse - agent d''impression.lnk'); $s.TargetPath='%EXE%'; $s.Arguments='%ARGS%'; $s.WorkingDirectory='%DOSSIER%'; $s.Save()"
start "" "%EXE%" %ARGS%
echo.
echo Agent d'impression installe et demarre (il se lancera a chaque demarrage de Windows).
echo Verification : ouvrez http://127.0.0.1:9101/etat dans le navigateur.
pause
