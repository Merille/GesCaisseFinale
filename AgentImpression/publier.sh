#!/bin/sh
# Fabrique l'exécutable Windows autonome (sans .NET à installer sur le poste) et le paquet à copier sur la caisse.
cd "$(dirname "$0")"
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:PublishTrimmed=true -p:DebugType=none -o publication/win-x64
cp installer.cmd desinstaller.cmd LISEZMOI.md publication/win-x64/
echo "Paquet prêt : publication/win-x64 (GesCaisseAgentImpression.exe, installer.cmd, desinstaller.cmd, LISEZMOI.md)"
