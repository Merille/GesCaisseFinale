// Pages de garde (modèle « C — Moderne ») des documents GesCaisse, rendues en images A4 300 dpi.
// Usage : node docs/generer_pages_de_garde.js   (nécessite Playwright et Chromium)
// Produit docs/pages_de_garde/garde_manuel.jpg et garde_cahier.jpg, insérées en pleine page
// par generer_manuel_utilisateur.js et generer_cahier_des_charges.js.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const D = __dirname;
const dataUri = (f, type) => `data:${type};base64,` + fs.readFileSync(path.join(D, f)).toString('base64');
const logo = dataUri('logo_mitech_africa.png', 'image/png');
const ecran1 = dataUri('manuel_images/02_tableau_de_bord.jpg', 'image/jpeg');
const ecran2 = dataUri('manuel_images/20_pos_vente.jpg', 'image/jpeg');
const B = '#1d5f8a', BF = '#0f3b57', G = '#9b9b9b';

const documents = [
    { fichier: 'garde_manuel.jpg', titre: 'Manuel<br>utilisateur', sous: 'Gestion de caisse, point de vente,<br>stock et restauration', version: 'Version 1.0' },
    { fichier: 'garde_cahier.jpg', titre: 'Cahier des<br>charges', sous: 'Application de gestion de caisse, de point<br>de vente et de restauration', version: 'Version 1.1' }
];

const arcs = (cx, cy, rs, couleurs, ep) => rs.map((r, i) =>
    `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${couleurs[i]}" stroke-width="${ep[i]}"/>`).join('');

const page = d => `<!doctype html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{width:794px;height:1123px;overflow:hidden;font-family:Inter,Arial,sans-serif;position:relative;background:#fff;color:#1b2b38}
.col{position:absolute;left:0;top:0;width:250px;height:100%;background:${BF};overflow:hidden}
.col svg{position:absolute;left:-180px;bottom:-120px}
.v{position:absolute;left:60px;top:70px;color:#fff;font-size:12px;letter-spacing:3px;writing-mode:vertical-rl;transform:rotate(180deg);opacity:.7}
.logo{position:absolute;left:300px;top:70px;width:300px}
.titre{position:absolute;left:300px;top:250px;right:60px}
.sur{font-size:14px;letter-spacing:4px;color:${G};font-weight:600}
h1{font-size:58px;line-height:1.03;font-weight:800;color:${BF};margin-top:12px;letter-spacing:-1px}
.sous{font-size:18px;color:#45586a;margin-top:18px;line-height:1.45}
.meta{position:absolute;left:300px;top:505px;font-size:13px;color:#5a6b78} .meta b{color:#1b2b38;font-weight:600}
.capture{position:absolute;left:120px;top:560px;width:640px;border-radius:12px;box-shadow:0 30px 60px rgba(15,59,87,.35);border:6px solid #fff;transform:rotate(-4deg)}
.capture2{position:absolute;left:330px;top:760px;width:430px;border-radius:10px;box-shadow:0 24px 50px rgba(15,59,87,.35);border:5px solid #fff;transform:rotate(3deg)}
</style></head><body>
<div class="col"><svg width="520" height="520" viewBox="0 0 520 520">${arcs(260, 260, [230, 190, 150], [B, '#5f7f96', B], [22, 12, 22])}</svg></div>
<div class="v">M-ITECH AFRICA · LA TECHNOLOGIE EN MAIN</div>
<img class="logo" src="${logo}">
<div class="titre"><div class="sur">GESCAISSE</div><h1>${d.titre}</h1><div class="sous">${d.sous}</div></div>
<div class="meta"><b>${d.version}</b> · Novembre 2026</div>
<img class="capture" src="${ecran1}"><img class="capture2" src="${ecran2}">
</body></html>`;

(async () => {
    fs.mkdirSync(path.join(D, 'pages_de_garde'), { recursive: true });
    const b = await chromium.launch();
    // 794 × 1123 px à l'échelle 3,125 = 2481 × 3509 px (A4 à 300 dpi).
    const p = await b.newPage({ viewport: { width: 794, height: 1123 }, deviceScaleFactor: 3.125 });
    for (const d of documents) {
        await p.setContent(page(d), { waitUntil: 'load' });
        await p.screenshot({ path: path.join(D, 'pages_de_garde', d.fichier), type: 'jpeg', quality: 88 });
        console.log('ok', d.fichier);
    }
    await b.close();
})();
