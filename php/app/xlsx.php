<?php
// Lecture / écriture minimales de fichiers Excel (.xlsx) sans bibliothèque externe.
// Nécessite l'extension PHP "zip" (activée par défaut sur XAMPP / WAMP).

/**
 * Envoie un classeur .xlsx au navigateur.
 * $feuilles = ['Nom' => [['en-tête 1', ...], [valeur, ...], ...], ...]
 * La première ligne de chaque feuille est mise en forme comme en-tête.
 * Les nombres (int/float) sont écrits comme nombres, tout le reste comme texte.
 */
function xlsx_envoyer(string $nomFichier, array $feuilles): never
{
    $tmp = tempnam(sys_get_temp_dir(), 'xlsx');
    $zip = new ZipArchive();
    $zip->open($tmp, ZipArchive::OVERWRITE);

    $noms = array_keys($feuilles);
    $overrides = '';
    $sheetsXml = '';
    $rels = '';
    foreach ($noms as $i => $nom) {
        $n = $i + 1;
        $zip->addFromString("xl/worksheets/sheet$n.xml", xlsx_feuille($feuilles[$nom]));
        $overrides .= '<Override PartName="/xl/worksheets/sheet' . $n . '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
        $sheetsXml .= '<sheet name="' . xlsx_xml(mb_substr($nom, 0, 31)) . '" sheetId="' . $n . '" r:id="rId' . $n . '"/>';
        $rels .= '<Relationship Id="rId' . $n . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' . $n . '.xml"/>';
    }
    $nStyles = count($noms) + 1;

    $zip->addFromString('[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        . '<Default Extension="xml" ContentType="application/xml"/>'
        . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        . $overrides . '</Types>');
    $zip->addFromString('_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        . '</Relationships>');
    $zip->addFromString('xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        . '<sheets>' . $sheetsXml . '</sheets></workbook>');
    $zip->addFromString('xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' . $rels
        . '<Relationship Id="rId' . $nStyles . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        . '</Relationships>');
    // Style 1 : en-tête (gras, blanc sur bleu foncé).
    $zip->addFromString('xl/styles.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        . '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
        . '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        . '<fill><patternFill patternType="solid"><fgColor rgb="FF195D84"/><bgColor indexed="64"/></patternFill></fill></fills>'
        . '<borders count="1"><border/></borders>'
        . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        . '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        . '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs>'
        . '</styleSheet>');
    $zip->close();

    header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    header('Content-Disposition: attachment; filename="' . $nomFichier . '"');
    header('Content-Length: ' . filesize($tmp));
    readfile($tmp);
    unlink($tmp);
    exit;
}

function xlsx_feuille(array $lignes): string
{
    $largeurs = [];
    $xml = '';
    foreach (array_values($lignes) as $r => $ligne) {
        $xml .= '<row r="' . ($r + 1) . '">';
        foreach (array_values($ligne) as $c => $val) {
            $ref = xlsx_colonne($c) . ($r + 1);
            $style = $r === 0 ? ' s="1"' : '';
            $largeurs[$c] = max($largeurs[$c] ?? 8, min(60, mb_strlen((string) $val) + 2));
            if (is_int($val) || is_float($val)) {
                $xml .= '<c r="' . $ref . '"' . $style . '><v>' . $val . '</v></c>';
            } elseif ($val !== null && $val !== '') {
                $xml .= '<c r="' . $ref . '"' . $style . ' t="inlineStr"><is><t xml:space="preserve">' . xlsx_xml((string) $val) . '</t></is></c>';
            }
        }
        $xml .= '</row>';
    }
    $cols = '';
    foreach ($largeurs as $c => $l) {
        $cols .= '<col min="' . ($c + 1) . '" max="' . ($c + 1) . '" width="' . $l . '" customWidth="1"/>';
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        . ($cols ? '<cols>' . $cols . '</cols>' : '')
        . '<sheetData>' . $xml . '</sheetData></worksheet>';
}

function xlsx_colonne(int $index): string
{
    $s = '';
    for ($n = $index + 1; $n > 0; $n = intdiv($n - 1, 26)) {
        $s = chr(65 + ($n - 1) % 26) . $s;
    }
    return $s;
}

function xlsx_xml(string $s): string
{
    // Supprime les caractères de contrôle interdits en XML.
    $s = preg_replace('/[^\x09\x0A\x0D\x20-\x{D7FF}\x{E000}-\x{FFFD}]/u', '', $s) ?? '';
    return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');
}

/**
 * Lit la première feuille d'un fichier .xlsx.
 * Renvoie un tableau de lignes ; chaque ligne est indexée par numéro de colonne (0 = A)
 * et porte son numéro de ligne Excel dans la clé '_ligne'.
 */
function xlsx_lire(string $chemin): array
{
    $zip = new ZipArchive();
    if ($zip->open($chemin) !== true) {
        throw new RuntimeException('Fichier Excel illisible.');
    }

    $partages = [];
    if (($xml = $zip->getFromName('xl/sharedStrings.xml')) !== false) {
        $sx = simplexml_load_string($xml);
        foreach ($sx->si as $si) {
            $texte = '';
            if (isset($si->t)) {
                $texte = (string) $si->t;
            }
            foreach ($si->r as $run) {
                $texte .= (string) $run->t;
            }
            $partages[] = $texte;
        }
    }

    // Première feuille déclarée dans le classeur.
    $cible = 'xl/worksheets/sheet1.xml';
    $wb = $zip->getFromName('xl/workbook.xml');
    $relsXml = $zip->getFromName('xl/_rels/workbook.xml.rels');
    if ($wb !== false && $relsXml !== false) {
        $w = simplexml_load_string($wb);
        $w->registerXPathNamespace('m', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main');
        $premiere = $w->xpath('//m:sheets/m:sheet')[0] ?? null;
        if ($premiere) {
            $rid = (string) $premiere->attributes('http://schemas.openxmlformats.org/officeDocument/2006/relationships')['id'];
            foreach (simplexml_load_string($relsXml)->Relationship as $rel) {
                if ((string) $rel['Id'] === $rid) {
                    $cible = 'xl/' . ltrim(preg_replace('#^/?xl/#', '', (string) $rel['Target']), '/');
                }
            }
        }
    }

    $feuille = $zip->getFromName($cible);
    $zip->close();
    if ($feuille === false) {
        throw new RuntimeException('Feuille Excel introuvable.');
    }

    $lignes = [];
    foreach (simplexml_load_string($feuille)->sheetData->row as $row) {
        $ligne = ['_ligne' => (int) $row['r']];
        foreach ($row->c as $cell) {
            preg_match('/^([A-Z]+)/', (string) $cell['r'], $m);
            $col = 0;
            foreach (str_split($m[1]) as $ch) {
                $col = $col * 26 + (ord($ch) - 64);
            }
            $type = (string) $cell['t'];
            if ($type === 's') {
                $val = $partages[(int) $cell->v] ?? '';
            } elseif ($type === 'inlineStr') {
                $val = (string) $cell->is->t;
            } else {
                $val = (string) $cell->v;
            }
            $ligne[$col - 1] = trim($val);
        }
        $lignes[] = $ligne;
    }
    return $lignes;
}
