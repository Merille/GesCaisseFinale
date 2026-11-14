-- Toutes les opérations proposées pour chaque droit (sauf tableaux de bord et droits particuliers) :
-- l'écran de vente distingue maintenant encaisser / prendre une commande (ajouter), transférer,
-- addition, reprise (modifier) et suppression d'une commande en attente (supprimer) ; les rapports,
-- l'export (ajouter) et l'impression (modifier) ; les achats, le règlement (modifier). Les profils
-- existants gardent ce qu'ils pouvaient faire.
UPDATE Profils SET Droits = TRIM(BOTH ',' FROM REPLACE(CONCAT(',', Droits, ','), ',vendre,', ',vendre,vendre.a,vendre.m,vendre.s,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,vendre,%' AND Droits NOT LIKE '%vendre.%';
UPDATE Profils SET Droits = TRIM(BOTH ',' FROM REPLACE(CONCAT(',', Droits, ','), ',rapports,', ',rapports,rapports.a,rapports.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,rapports,%' AND Droits NOT LIKE '%rapports.%';
UPDATE Profils SET Droits = TRIM(BOTH ',' FROM REPLACE(CONCAT(',', Droits, ','), ',rapports_pdv,', ',rapports_pdv,rapports_pdv.a,rapports_pdv.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,rapports_pdv,%' AND Droits NOT LIKE '%rapports_pdv.%';
UPDATE Profils SET Droits = TRIM(BOTH ',' FROM REPLACE(CONCAT(',', Droits, ','), ',achats.a,', ',achats.a,achats.m,'))
WHERE CONCAT(',', Droits, ',') LIKE '%,achats.a,%' AND Droits NOT LIKE '%achats.m%';
