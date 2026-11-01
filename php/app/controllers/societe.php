<?php
// Ma société (Paramètres) : l'administrateur modifie les coordonnées et le logo de sa société
// (en-tête des tickets, factures et impressions). Le nom, le code, la licence et les modules
// restent gérés par le SuperAdmin (Administration › Sociétés).

const SOCIETE_CHAMPS = ['Adresse', 'Ville', 'Pays', 'Email', 'Telephone', 'NIF'];
const SOCIETE_LONGUEURS = ['Adresse' => 250, 'Ville' => 100, 'Pays' => 100, 'Email' => 150, 'Telephone' => 50, 'NIF' => 50];

function societe_index(): void
{
    $t = societe_courante();
    if (!$t) {
        flash('warning', 'Choisissez d\'abord la société concernée dans le menu « Société consultée ».');
        redirect('dashboard/index');
    }
    if (is_post()) {
        $valeurs = [];
        foreach (SOCIETE_CHAMPS as $c) {
            $texte = mb_substr(trim((string) post($c, '')), 0, SOCIETE_LONGUEURS[$c]);
            $valeurs[$c] = $texte === '' ? null : $texte;
        }
        $logo = image_televersee('Logo');
        $erreur = $valeurs['Email'] !== null && !filter_var($valeurs['Email'], FILTER_VALIDATE_EMAIL)
            ? "L'adresse e-mail n'est pas valide." : (is_string($logo) ? $logo : null);
        if ($erreur) {
            flash('danger', $erreur);
            $t = $valeurs + $t;
        } else {
            $set = implode(', ', array_map(fn($c) => "$c = ?", SOCIETE_CHAMPS));
            run("UPDATE Tenants SET $set WHERE Id = ?", [...array_values($valeurs), $t['Id']]);
            enregistrer_image('logo', (int) $t['Id'], $logo, (bool) post('SupprimerLogo'));
            flash('success', 'Informations de la société enregistrées.');
            redirect('societe/index');
        }
    }
    render('societe/index', ['t' => $t]);
}
