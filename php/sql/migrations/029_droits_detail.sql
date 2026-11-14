-- Droits détaillés par opération : consulter, ajouter / créer, modifier, supprimer. Les profils
-- existants gardent exactement ce qu'ils pouvaient faire : chaque droit reçoit toutes ses opérations ;
-- « caisses » (caisses et journées) devient « caisses » + « journees », et « caisses_gerer » les
-- opérations ajouter / modifier / supprimer des caisses.
UPDATE Profils SET Droits = TRIM(BOTH ',' FROM
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CONCAT(',', Droits, ','),
        ',caisses,', ',caisses,journees,journees.a,journees.m,journees.s,'),
        ',caisses_gerer,', ',caisses,caisses.a,caisses.m,caisses.s,'),
        ',tiers,', ',tiers,tiers.a,tiers.m,tiers.s,'),
        ',ventes,', ',ventes,ventes.a,ventes.m,ventes.s,'),
        ',cuisine,', ',cuisine,cuisine.m,'),
        ',stock,', ',stock,stock.a,stock.m,'),
        ',achats,', ',achats,achats.a,achats.s,'),
        ',catalogue,', ',catalogue,catalogue.a,catalogue.m,catalogue.s,'),
        ',synchro,', ',synchro,synchro.m,'),
        ',parametres,', ',parametres,parametres.a,parametres.m,parametres.s,'),
        ',config_pdv,', ',config_pdv,config_pdv.a,config_pdv.m,config_pdv.s,'))
WHERE Droits NOT LIKE '%.%';
