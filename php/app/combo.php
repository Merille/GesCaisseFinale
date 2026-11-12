<?php
// Combos (menus, formules) : groupes de choix d'un produit combo, contrôle des composants choisis
// à la vente, stock des composants. Commun au point de vente et aux retours.

/** Choix de chaque combo d'une société : [comboId => { id, nom, quantite, choix: [{ produitId, supplement }] }]. */
function combos_liste(int $tenant): array
{
    $combos = [];
    foreach (q('SELECT * FROM Combos WHERE TenantId = ? ORDER BY Ordre, Nom, Id', [$tenant]) as $c) {
        $combos[(int) $c['Id']] = ['id' => (int) $c['Id'], 'nom' => $c['Nom'], 'quantite' => (int) $c['Quantite'], 'choix' => []];
    }
    if ($combos) {
        $marques = implode(',', array_fill(0, count($combos), '?'));
        foreach (q("SELECT * FROM ComboChoix WHERE ComboId IN ($marques) ORDER BY Ordre, Id", array_keys($combos)) as $ch) {
            $combos[(int) $ch['ComboId']]['choix'][] = ['produitId' => (int) $ch['ProduitId'], 'supplement' => (float) $ch['Supplement']];
        }
    }
    return $combos;
}

/** Combos qui composent chaque produit combo d'une société : [produitId => [combo, …]] (dans l'ordre). */
function combos_societe(int $tenant): array
{
    $combos = combos_liste($tenant);
    $parProduit = [];
    foreach (q('SELECT pc.* FROM ProduitCombos pc JOIN Produits p ON p.Id = pc.ProduitId WHERE p.TenantId = ? ORDER BY pc.Ordre', [$tenant]) as $l) {
        if (isset($combos[(int) $l['ComboId']])) {
            $parProduit[(int) $l['ProduitId']][] = $combos[(int) $l['ComboId']];
        }
    }
    return $parProduit;
}

/**
 * Composants choisis pour un combo, contrôlés : chaque groupe doit avoir exactement le nombre
 * d'articles prévu, parmi ses produits proposés. Renvoie [composants, total des suppléments]
 * ou un message d'erreur. Composant : { produitId, nom, qte (par combo), supplement, groupe }.
 */
function combo_composants(array $combo, array $saisis): array|string
{
    $groupes = combos_societe((int) $combo['TenantId'])[(int) $combo['Id']] ?? [];
    if (!$groupes) {
        return 'Le produit « ' . $combo['Nom'] . " n'est plus composé d'aucun combo.";
    }
    $composants = [];
    $supplements = 0.0;
    foreach ($groupes as $g) {
        $permis = array_column($g['choix'], 'supplement', 'produitId');
        $total = 0.0;
        foreach ($saisis as $s) {
            if ((int) ($s['groupeId'] ?? 0) !== $g['id']) {
                continue;
            }
            $pid = (int) ($s['produitId'] ?? 0);
            $qte = max(0, round((float) ($s['qte'] ?? 1), 2));
            $p = $qte > 0 && array_key_exists($pid, $permis)
                ? q1('SELECT Id, Nom FROM Produits WHERE Id = ? AND TenantId = ? AND Actif = 1 AND Consommable = 0', [$pid, $combo['TenantId']]) : null;
            if (!$p) {
                return 'Un article choisi pour « ' . $combo['Nom'] . ' › ' . $g['nom'] . " » n'est pas proposé ou n'est plus actif.";
            }
            $composants[] = ['produitId' => $pid, 'nom' => $p['Nom'], 'qte' => $qte, 'supplement' => (float) $permis[$pid], 'groupe' => $g['nom']];
            $supplements += $qte * (float) $permis[$pid];
            $total += $qte;
        }
        if (abs($total - $g['quantite']) > 0.001) {
            return 'Choisissez ' . $g['quantite'] . ' article(s) dans « ' . $combo['Nom'] . ' › ' . $g['nom'] . ' ».';
        }
    }
    return [$composants, $supplements];
}

/** Composants d'une ligne vendue (JSON de LignesCommandePos.Composants). */
function ligne_composants(?string $json): array
{
    $c = json_decode((string) $json, true);
    return is_array($c) ? array_values(array_filter($c, 'is_array')) : [];
}

/** Mouvement de stock d'une ligne vendue (dans le dépôt donné) : le produit, ou les composants d'un combo. */
function ligne_mouvement_stock(array $ligne, float $qte, string $type, ?string $reference, ?int $commandeId,
                               ?string $commentaire = null, ?int $depotId = null): void
{
    $composants = ligne_composants($ligne['Composants'] ?? null);
    if (!$composants) {
        mouvement_stock((int) $ligne['ProduitId'], $qte, $type, $reference, $commandeId, $commentaire, $depotId);
        return;
    }
    foreach ($composants as $c) {
        mouvement_stock((int) $c['produitId'], $qte * (float) $c['qte'], $type, $reference, $commandeId, $commentaire, $depotId);
    }
}

/** Sortie de stock d'une ligne vendue, répartie entre les dépôts de la caisse : le produit, ou les composants d'un combo. */
function ligne_sortie_stock(array $ligne, float $qte, ?string $reference, ?int $commandeId, array $depots): void
{
    $composants = ligne_composants($ligne['Composants'] ?? null);
    foreach ($composants ?: [['produitId' => (int) $ligne['ProduitId'], 'qte' => 1]] as $c) {
        sortie_stock_caisse((int) $c['produitId'], $qte * (float) $c['qte'], 'Vente', $reference, $commandeId, null, $depots);
    }
}
