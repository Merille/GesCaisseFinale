-- Point de vente, étape 4 : après-vente (retours liés à la vente d'origine, motif de retour ou d'annulation).
ALTER TABLE CommandesPos
    ADD COLUMN CommandeOrigineId INT NULL,
    ADD COLUMN Motif VARCHAR(300) NULL,
    ADD KEY IX_CommandesPos_Origine (CommandeOrigineId);

ALTER TABLE LignesCommandePos
    ADD COLUMN LigneOrigineId INT NULL,
    ADD KEY IX_LignesCommandePos_Origine (LigneOrigineId);
