<?php
// Combos (menus, formules) : groupes de choix d'un produit combo, contrôle des composants choisis
// à la vente, stock des composants. Commun au point de vente et aux retours.

/** Groupes de choix des combos d'une société, par produit : [produitId => [{ id, nom, quantite, choix }]]. */
function combos_societe(int $tenant): array
{
    $groupes = [];
    foreach (q('SELECT g.* FROM ComboGroupes g JOIN Produits p ON p.Id = g.ProduitId WHERE p.TenantId = ? ORDER BY g.Ordre, g.Id', [$tenant]) as $g) {
        $groupes[(int) $g['Id']] = ['id' => (int) $g['Id'], 'produitId' => (int) $g['ProduitId'], 'nom' => $g['Nom'], 'quantite' => (int) $g['Quantite'], 'choix' => []];
    }
    if ($groupes) {
        $marques = implode(',', array_fill(0, count($groupes), '?'));
        foreach (q("SELECT * FROM ComboChoix WHERE GroupeId IN ($marques) ORDER BY Ordre, Id", array_keys($groupes)) as $c) {
            $groupes[(int) $c['GroupeId']]['choix'][] = ['produitId' => (int) $c['ProduitId'], 'supplement' => (float) $c['Supplement']];
        }
    }
    $parProduit = [];
    foreach ($groupes as $g) {
        $parProduit[$g['produitId']][] = $g;
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
        return 'Le combo « ' . $combo['Nom'] . " n'a plus de groupes de choix.";
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
                ? q1('SELECT Id, Nom FROM Produits WHERE Id = ? AND TenantId = ? AND Actif = 1', [$pid, $combo['TenantId']]) : null;
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

/** Mouvement de stock d'une ligne vendue : le produit, ou les composants d'un combo. */
function ligne_mouvement_stock(array $ligne, float $qte, string $type, ?string $reference, ?int $commandeId, ?string $commentaire = null): void
{
    $composants = ligne_composants($ligne['Composants'] ?? null);
    if (!$composants) {
        mouvement_stock((int) $ligne['ProduitId'], $qte, $type, $reference, $commandeId, $commentaire);
        return;
    }
    foreach ($composants as $c) {
        mouvement_stock((int) $c['produitId'], $qte * (float) $c['qte'], $type, $reference, $commandeId, $commentaire);
    }
}
