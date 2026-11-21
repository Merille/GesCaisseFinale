// Imprimantes de préparation en réseau (cuisine, bar) : la caisse leur envoie directement les bons.
// Partagé par les versions .NET et PHP (écran de vente et page Paramètres › Imprimantes).
//
// - Epson (ePOS) : le navigateur envoie le bon à l'imprimante (http(s)://IP/cgi-bin/epos/service.cgi),
//   sans rien installer. Application en HTTPS : HTTPS activé sur l'imprimante et son certificat accepté
//   une fois sur le poste (ouvrir https://IP dans le navigateur).
// - Réseau (ESC/POS, port 9100) : un navigateur ne peut pas ouvrir cette connexion ; l'agent d'impression
//   GesCaisse, installé sur le poste, reçoit le bon (http://127.0.0.1:9101) et le transmet à l'imprimante.
//
// Imprimante : { id, nom, type: 'Epson' | 'Reseau', ip, port, largeur: 80 | 58, encodage: 'PC850' | 'SansAccents', bip, categories: [id] }
// Bon : { numero, poste, table, couverts, serveur, date, horsLigne, lignes: [{ libelle, qte, note, categorieId }] }
(function () {
    'use strict';

    const AGENT_DEFAUT = 'http://127.0.0.1:9101';
    const DELAI = 12000;

    function adresseAgent() {
        try { return localStorage.getItem('gescaisse-agent-impression') || AGENT_DEFAUT; } catch (e) { return AGENT_DEFAUT; }
    }

    // ------------------------------------------------------------------
    // Mise en page : liste d'éléments indépendante de l'imprimante
    // { t: 'texte', s, centre, grand (double largeur et hauteur), haut (double hauteur), gras } | { t: 'trait' } | { t: 'bip' } | { t: 'coupe' }
    // ------------------------------------------------------------------
    function qte(n) {
        const v = Math.round(Math.abs(n) * 100) / 100;
        return String(v).replace('.', ',');
    }
    function dateFr(d) {
        const x = d instanceof Date ? d : new Date(String(d || '').replace(' ', 'T'));
        if (isNaN(x)) return '';
        const z = n => String(n).padStart(2, '0');
        return z(x.getDate()) + '/' + z(x.getMonth() + 1) + '/' + x.getFullYear() + ' ' + z(x.getHours()) + ':' + z(x.getMinutes());
    }

    function documentBon(bon, imprimante, lignes) {
        const doc = [];
        if (imprimante.bip) doc.push({ t: 'bip' });
        doc.push({ t: 'texte', s: String(bon.poste || 'Préparation').toUpperCase(), centre: true, grand: true, gras: true });
        doc.push({ t: 'texte', s: (bon.table || '') + (bon.couverts ? ' · ' + bon.couverts + ' couv.' : ''), centre: true, haut: true, gras: true });
        doc.push({ t: 'texte', s: (bon.numero ? 'Bon N° ' + bon.numero + ' · ' : '') + dateFr(bon.date || new Date()), centre: true });
        if (bon.serveur) doc.push({ t: 'texte', s: 'Serveur : ' + bon.serveur, centre: true });
        if (bon.horsLigne) doc.push({ t: 'texte', s: '(envoyé hors ligne)', centre: true });
        doc.push({ t: 'trait' });
        lignes.forEach(l => {
            doc.push({ t: 'texte', s: (l.qte < 0 ? 'ANNULÉ ' : '') + qte(l.qte) + ' x ' + l.libelle, haut: true, gras: true });
            if (l.note) doc.push({ t: 'texte', s: '   » ' + l.note });
        });
        doc.push({ t: 'trait' });
        doc.push({ t: 'coupe' });
        return doc;
    }

    function documentTest(imprimante) {
        return [
            ...(imprimante.bip ? [{ t: 'bip' }] : []),
            { t: 'texte', s: 'GESCAISSE', centre: true, grand: true, gras: true },
            { t: 'texte', s: 'Page d\'essai', centre: true, haut: true },
            { t: 'trait' },
            { t: 'texte', s: 'Imprimante : ' + imprimante.nom },
            { t: 'texte', s: 'Adresse : ' + imprimante.ip + (imprimante.port ? ':' + imprimante.port : '') },
            { t: 'texte', s: 'Papier : ' + imprimante.largeur + ' mm · ' + colonnes(imprimante) + ' caractères' },
            { t: 'texte', s: 'Accents : é è à ç ô ù « » €' },
            { t: 'texte', s: dateFr(new Date()) },
            { t: 'trait' },
            { t: 'coupe' }
        ];
    }

    // ------------------------------------------------------------------
    // Texte : colonnes, coupure des lignes, jeu de caractères
    // ------------------------------------------------------------------
    function colonnes(imp) { return Number(imp.largeur) === 58 ? 32 : 48; }

    function couper(texte, largeur) {
        const res = [];
        String(texte).split('\n').forEach(para0 => {
            // Retrait conservé sur chaque ligne (notes).
            const retrait = para0.match(/^ */)[0], para = para0.slice(retrait.length), larg = Math.max(8, largeur - retrait.length);
            const res0 = res.length;
            let ligne = '';
            para.split(' ').filter(m => m !== '').forEach(mot => {
                while (mot.length > larg) {
                    if (ligne) { res.push(ligne); ligne = ''; }
                    res.push(mot.slice(0, larg)); mot = mot.slice(larg);
                }
                if (!ligne) ligne = mot;
                else if ((ligne + ' ' + mot).length <= larg) ligne += ' ' + mot;
                else { res.push(ligne); ligne = mot; }
            });
            res.push(ligne);
            for (let i = res0; i < res.length; i++) res[i] = retrait + res[i];
        });
        return res;
    }

    const REMPLACEMENTS = { '’': "'", '‘': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', 'œ': 'oe', 'Œ': 'OE', '€': 'EUR', ' ': ' ', ' ': ' ' };
    function sansAccents(s) {
        return String(s).replace(/[’‘“”–—…œŒ€  ]/g, c => REMPLACEMENTS[c]).normalize('NFD').replace(/[̀-ͯ]/g, '')
            .replace(/[«»]/g, '"').replace(/·/g, '.').replace(/°/g, 'o').replace(/[^\x20-\x7e\n]/g, '?');
    }
    // Page de codes 850 (Europe de l'Ouest), sélectionnée par ESC t 2 sur les imprimantes ESC/POS.
    const PC850 = 'ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜø£Ø×ƒáíóúñÑªº¿®¬½¼¡«»░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐└┴┬├─┼ãÃ╚╔╩╦╠═╬¤ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀ÓßÔÒõÕµþÞÚÛÙýÝ¯´­±‗¾¶§÷¸°¨·¹³²■ ';
    const VERS_PC850 = new Map([...PC850].map((c, i) => [c, 0x80 + i]));

    function octetsTexte(s, encodage) {
        const out = [];
        if (encodage === 'SansAccents') {
            for (const c of sansAccents(s)) out.push(c.charCodeAt(0));
            return out;
        }
        for (const c0 of String(s)) {
            const c = REMPLACEMENTS[c0] !== undefined && c0 !== ' ' ? REMPLACEMENTS[c0] : c0;
            for (const c1 of c) {
                const code = c1.charCodeAt(0);
                if (code >= 0x20 && code < 0x7f) out.push(code);
                else if (VERS_PC850.has(c1)) out.push(VERS_PC850.get(c1));
                else { const simple = sansAccents(c1); for (const x of simple) out.push(x.charCodeAt(0)); }
            }
        }
        return out;
    }

    // ------------------------------------------------------------------
    // ESC/POS (imprimantes réseau, port 9100)
    // ------------------------------------------------------------------
    function escpos(doc, imp) {
        const cols = colonnes(imp);
        const o = [0x1b, 0x40];                                       // ESC @ : initialisation
        if (imp.encodage !== 'SansAccents') o.push(0x1b, 0x74, 0x02);  // ESC t 2 : page de codes 850
        doc.forEach(e => {
            if (e.t === 'bip') o.push(0x1b, 0x42, 0x02, 0x02);         // ESC B : signal sonore (2 bips)
            else if (e.t === 'trait') o.push(0x1b, 0x61, 0x00, 0x1d, 0x21, 0x00, 0x1b, 0x45, 0x00, ...octetsTexte('-'.repeat(cols), 'SansAccents'), 0x0a);
            else if (e.t === 'coupe') o.push(0x1b, 0x64, 0x04, 0x1d, 0x56, 0x42, 0x00);  // avance de 4 lignes, coupe
            else if (e.t === 'texte') {
                o.push(0x1b, 0x61, e.centre ? 0x01 : 0x00);
                o.push(0x1d, 0x21, e.grand ? 0x11 : e.haut ? 0x01 : 0x00);
                o.push(0x1b, 0x45, e.gras ? 0x01 : 0x00);
                couper(e.s, e.grand ? Math.floor(cols / 2) : cols).forEach(l => o.push(...octetsTexte(l, imp.encodage), 0x0a));
            }
        });
        o.push(0x1d, 0x21, 0x00, 0x1b, 0x45, 0x00, 0x1b, 0x61, 0x00);
        return new Uint8Array(o);
    }

    function base64(octets) {
        let s = '';
        for (let i = 0; i < octets.length; i += 0x8000) s += String.fromCharCode.apply(null, octets.subarray(i, i + 0x8000));
        return btoa(s);
    }

    // ------------------------------------------------------------------
    // Epson ePOS-Print (XML)
    // ------------------------------------------------------------------
    function xml(s) {
        return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }
    function epos(doc, imp) {
        const cols = colonnes(imp);
        const t = s => imp.encodage === 'SansAccents' ? sansAccents(s) : s;
        let x = '<epos-print xmlns="http://www.epson-pos.com/schemas/2011/03/epos-print"><text lang="en"/><text smooth="true"/>';
        doc.forEach(e => {
            if (e.t === 'bip') x += '<sound pattern="pattern_a" repeat="2"/>';
            else if (e.t === 'trait') x += '<text align="left"/><text dw="false" dh="false"/><text em="false"/><text>' + '-'.repeat(cols) + '&#10;</text>';
            else if (e.t === 'coupe') x += '<feed line="3"/><cut type="feed"/>';
            else if (e.t === 'texte') {
                x += '<text align="' + (e.centre ? 'center' : 'left') + '"/>'
                    + '<text dw="' + (e.grand ? 'true' : 'false') + '" dh="' + (e.grand || e.haut ? 'true' : 'false') + '"/>'
                    + '<text em="' + (e.gras ? 'true' : 'false') + '"/>'
                    + '<text>' + couper(e.s, e.grand ? Math.floor(cols / 2) : cols).map(l => xml(t(l))).join('&#10;') + '&#10;</text>';
            }
        });
        return x + '</epos-print>';
    }

    // ------------------------------------------------------------------
    // Envoi
    // ------------------------------------------------------------------
    async function requete(url, options) {
        const ctrl = new AbortController();
        const minuterie = setTimeout(() => ctrl.abort(), DELAI);
        try { return await fetch(url, { ...options, signal: ctrl.signal, cache: 'no-store', credentials: 'omit' }); }
        finally { clearTimeout(minuterie); }
    }

    async function envoyerEpson(imp, docs) {
        const proto = location.protocol === 'https:' ? 'https:' : 'http:';
        const base = proto + '//' + imp.ip + (imp.port ? ':' + imp.port : '');
        const corps = '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
            + docs.map(d => epos(d, imp)).join('').replace(/<\/epos-print><epos-print[^>]*>/g, '')
            + '</s:Body></s:Envelope>';
        let res;
        try {
            res = await requete(base + '/cgi-bin/epos/service.cgi?devid=local_printer&timeout=10000', {
                method: 'POST', body: corps,
                headers: { 'Content-Type': 'text/xml; charset=utf-8', 'If-Modified-Since': 'Thu, 01 Jan 1970 00:00:00 GMT', 'SOAPAction': '""' }
            });
        } catch (e) {
            throw new Error('imprimante injoignable (adresse, alimentation, réseau'
                + (proto === 'https:' ? ', HTTPS de l\'imprimante : ouvrez ' + base + ' une fois sur ce poste et acceptez le certificat' : '') + ')');
        }
        const texte = await res.text().catch(() => '');
        if (!res.ok) throw new Error('réponse de l\'imprimante : ' + res.status);
        if (!/success="true"/.test(texte)) {
            const code = (texte.match(/code="([^"]*)"/) || [])[1];
            throw new Error('impression refusée par l\'imprimante' + (code ? ' (' + code + ')' : '') + ' : papier, capot, mode ePOS ?');
        }
    }

    async function envoyerAgent(imp, docs) {
        const parts = docs.map(d => escpos(d, imp));
        const total = new Uint8Array(parts.reduce((s, p) => s + p.length, 0));
        let pos = 0; parts.forEach(p => { total.set(p, pos); pos += p.length; });
        let res;
        try {
            res = await requete(adresseAgent() + '/imprimer', {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ ip: imp.ip, port: imp.port || 9100, donnees: base64(total) })
            });
        } catch (e) {
            throw new Error('agent d\'impression injoignable sur ce poste (installé et démarré ?)');
        }
        const r = await res.json().catch(() => ({}));
        if (!res.ok || !r.ok) throw new Error(r.erreur || ('agent d\'impression : erreur ' + res.status));
    }

    function envoyer(imp, docs) {
        return imp.type === 'Reseau' ? envoyerAgent(imp, docs) : envoyerEpson(imp, docs);
    }

    // Bons répartis entre les imprimantes selon leurs catégories (une ligne peut partir sur plusieurs
    // imprimantes si sa catégorie y est cochée). Résultat : [{ imprimante, ok, erreur, bons }].
    async function imprimerBons(bons, imprimantes) {
        const travaux = (imprimantes || []).map(imp => {
            const cats = new Set((imp.categories || []).map(Number));
            const parts = (bons || []).map(b => ({ bon: b, lignes: (b.lignes || []).filter(l => cats.has(Number(l.categorieId))) })).filter(x => x.lignes.length);
            return { imp, parts };
        }).filter(x => x.parts.length);
        return Promise.all(travaux.map(async ({ imp, parts }) => {
            try {
                await envoyer(imp, parts.map(x => documentBon(x.bon, imp, x.lignes)));
                return { imprimante: imp, ok: true, bons: parts.map(x => x.bon) };
            } catch (e) {
                return { imprimante: imp, ok: false, erreur: e.message, bons: parts.map(x => x.bon) };
            }
        }));
    }

    // Une imprimante au moins couvre-t-elle ces catégories ?
    function couvre(imprimantes, categorieId) {
        return (imprimantes || []).some(i => (i.categories || []).map(Number).includes(Number(categorieId)));
    }

    async function tester(imp) {
        try { await envoyer(imp, [documentTest(imp)]); return { ok: true }; }
        catch (e) { return { ok: false, erreur: e.message }; }
    }

    window.GCImprimantes = { imprimerBons, tester, couvre, adresseAgent, escpos, epos, documentBon, AGENT_DEFAUT };
})();
