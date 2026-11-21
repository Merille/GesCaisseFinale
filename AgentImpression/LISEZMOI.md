# Agent d'impression GesCaisse

Petit programme pour Windows, installé sur le **poste de caisse**. Il permet à l'écran de vente
d'imprimer les bons de préparation sur les **imprimantes réseau ESC/POS** de la cuisine et du bar
(Xprinter, Rongta, HPRT, Bixolon, anciennes Epson sans ePOS…), qui reçoivent les impressions sur le port 9100.

Un navigateur ne sait pas envoyer directement à ces imprimantes : l'écran de vente passe le bon,
déjà mis en forme, à l'agent (adresse `http://127.0.0.1:9101`, ce poste uniquement), et l'agent l'envoie
à l'adresse IP de l'imprimante. Les imprimantes **Epson ePOS** n'ont pas besoin de l'agent.

L'impression passe par le réseau local : elle continue même si Internet est coupé.

## Installation (une fois par poste de caisse)

1. Copiez sur le poste le dossier contenant `GesCaisseAgentImpression.exe`, `installer.cmd`
   et `desinstaller.cmd`.
2. Double-cliquez sur `installer.cmd` et indiquez l'adresse de GesCaisse telle qu'elle apparaît dans
   le navigateur (par exemple `https://caisse.masociete.com`) : seules les pages de cette adresse
   pourront imprimer par l'agent.
3. L'agent démarre aussitôt et se relancera à chaque démarrage de Windows (raccourci dans le dossier
   Démarrage de l'utilisateur ; aucun droit administrateur nécessaire).
4. Vérification : ouvrez `http://127.0.0.1:9101/etat` dans le navigateur, la réponse doit contenir `"ok":true`.
5. Dans GesCaisse, **Paramètres › Imprimantes** : créez l'imprimante avec le type
   « Autre imprimante réseau ESC/POS », son adresse IP (port 9100 par défaut), puis cliquez sur **Tester**.

Pare-feu : Windows peut demander d'autoriser le programme ; il n'écoute que sur ce poste (127.0.0.1),
l'autorisation n'est pas nécessaire pour imprimer.

## Sécurité

- L'agent n'accepte que les connexions venant du poste lui-même.
- Il n'envoie qu'aux adresses du réseau local (10.x.x.x, 172.16 à 172.31.x.x, 192.168.x.x) et
  qu'aux ports d'imprimante 9100 à 9109.
- Avec l'option `--origine`, seules les pages GesCaisse de cette adresse peuvent l'utiliser.

## Options (raccourci de démarrage)

| Option | Effet |
|---|---|
| `--origine https://caisse.masociete.com` | N'accepte que cette adresse (répétable pour plusieurs adresses) |
| `--port 9101` | Port d'écoute de l'agent (si vous le changez, indiquez la nouvelle adresse dans le navigateur du poste : voir ci-dessous) |
| `--ports-imprimantes 9100,9101` | Ports d'imprimante autorisés |

Adresse de l'agent sur un poste (si le port a été changé) : dans la console du navigateur de l'écran de vente,
`localStorage.setItem('gescaisse-agent-impression', 'http://127.0.0.1:9200')`.

Journal : `agent-impression.log`, à côté du programme (`%LOCALAPPDATA%\GesCaisse`).

## Désinstallation

Double-cliquez sur `desinstaller.cmd`.

## Fabriquer l'exécutable (développeurs)

`./publier.sh` (ou la commande `dotnet publish` qu'il contient) produit `publication/win-x64` :
un seul fichier `GesCaisseAgentImpression.exe`, autonome (.NET inutile sur le poste).
