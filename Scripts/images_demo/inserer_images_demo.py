# Recopie les images de Scripts/images_demo dans les scripts de démonstration (MySQL et SQL Server).
# Usage : python3 Scripts/images_demo/inserer_images_demo.py  (depuis la racine du dépôt)
# Le bloc est placé entre deux repères ; relancer le script le remplace.
import os

D = os.path.dirname(os.path.abspath(__file__))
CODES = ['BOI01', 'BOI02', 'BOI03', 'EPI01', 'EPI02', 'EPI03', 'BOU01', 'BOU02', 'BOU03', 'LAI01', 'LAI02', 'LAI03',
         'HYG01', 'HYG02', 'HYG03', 'ENT01', 'ENT02', 'ENT03', 'PAP01', 'PAP02', 'PAP03', 'ELE01', 'ELE02', 'ELE03',
         'SNA01', 'SNA02', 'SNA03', 'SER01', 'SER02', 'SER03']
DEBUT = '-- [images des articles : début]\n'
FIN = '-- [images des articles : fin]\n'
ENTETE = '-- Images des articles (illustrations générées par Scripts/images_demo/generer_images_demo.js).\n'

hexa = {c: open(os.path.join(D, c + '.jpg'), 'rb').read().hex().upper() for c in CODES}
liste = ', '.join("'%s'" % c for c in CODES)
mysql = ENTETE + ''.join(
    "INSERT INTO ProduitImages (ProduitId, TypeContenu, Donnees) SELECT Id, 'image/jpeg', 0x%s FROM Produits WHERE TenantId = @t AND Code = '%s'\n"
    "    ON DUPLICATE KEY UPDATE TypeContenu = VALUES(TypeContenu), Donnees = VALUES(Donnees);\n" % (hexa[c], c) for c in CODES)
mysql += 'UPDATE Produits SET ImageMaj = NOW() WHERE TenantId = @t AND Code IN (%s);\n' % liste
sqlserver = ENTETE + 'DELETE FROM ProduitImages WHERE ProduitId IN (SELECT Id FROM Produits WHERE TenantId = @t AND Code IN (%s));\n' % liste
sqlserver += ''.join("INSERT INTO ProduitImages (ProduitId, TypeContenu, Donnees) SELECT Id, 'image/jpeg', 0x%s FROM Produits WHERE TenantId = @t AND Code = '%s';\n"
                     % (hexa[c], c) for c in CODES)
sqlserver += 'UPDATE Produits SET ImageMaj = GETDATE() WHERE TenantId = @t AND Code IN (%s);\n' % liste

for chemin, bloc, enc in [('php/sql/demo/demo_pos_mysql.sql', mysql, 'utf-8'), ('Scripts/demo_pos_sqlserver.sql', sqlserver, 'utf-8-sig')]:
    s = open(chemin, encoding=enc).read()
    if DEBUT in s:
        s = s[:s.index(DEBUT)] + s[s.index(FIN) + len(FIN):]
    i = s.index('-- Dépôts de stockage : le stock de démonstration')
    s = s[:i] + DEBUT + bloc + FIN + '\n' + s[i:]
    open(chemin, 'w', encoding=enc).write(s)
    print(chemin, ':', len(CODES), 'images')
