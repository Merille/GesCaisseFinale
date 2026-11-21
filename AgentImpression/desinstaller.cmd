@echo off
rem Désinstallation de l'agent d'impression GesCaisse de ce poste.
taskkill /im GesCaisseAgentImpression.exe /f >nul 2>&1
del /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\GesCaisse - agent d'impression.lnk" >nul 2>&1
del /q "%LOCALAPPDATA%\GesCaisse\GesCaisseAgentImpression.exe" >nul 2>&1
echo Agent d'impression desinstalle.
pause
