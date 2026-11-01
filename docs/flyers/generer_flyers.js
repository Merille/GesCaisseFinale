// Flyers GesCaisse (A4) : généraliste, restaurants et bars, commerces — PDF vectoriels prêts à imprimer.
// Usage : node docs/flyers/generer_flyers.js   (nécessite Playwright et Chromium)
// Produit docs/flyers/Flyer_GesCaisse_*.pdf, images/*.png (300 dpi) et images/*.jpg (1240 px, partage) ; captures : docs/manuel_images, logo : docs/logo_mitech_africa.png.
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path'); const os = require('os');
const D = __dirname, IMG = path.join(D, '..', 'manuel_images') + '/';
const FA = 'file://' + path.join(D, 'fontawesome', 'css', 'all.min.css');
const uri = f => 'data:image/' + (f.endsWith('png') ? 'png' : 'jpeg') + ';base64,' + fs.readFileSync(f).toString('base64');
const logo = uri(path.join(D, '..', 'logo_mitech_africa.png'));
const im = n => uri(IMG + n + '.jpg');
const B = '#1d5f8a', BF = '#0f3b57', G = '#9b9b9b', VERT = '#1f8a4c', OR = '#e08a1e';
const arcs = (cx, cy, rs, c, e) => rs.map((r, i) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${c[i]}" stroke-width="${e[i]}"/>`).join('');
const base = `*{margin:0;padding:0;box-sizing:border-box} #page{width:794px;height:1123px;overflow:hidden;font-family:Inter,sans-serif;position:relative;color:#1b2b38}
.ph{font-weight:600}`;
const contact = (fond, texte) => `<div class="contact" style="position:absolute;left:0;right:0;bottom:0;height:120px;background:${fond};color:${texte};display:flex;align-items:center;padding:0 56px;gap:34px">
 <img src="${logo}" style="height:58px;background:#fff;border-radius:10px;padding:6px 10px">
 <div style="font-size:14px;line-height:1.9;flex:1"><div><i class="fas fa-phone" style="width:22px"></i> <span class="ph">076 32 81 80 · 065 61 44 53</span></div><div><i class="fas fa-envelope" style="width:22px"></i> <span class="ph">info@mitech-africa.com</span></div></div>
 <div style="font-size:14px;line-height:1.9;flex:1"><div><i class="fas fa-globe" style="width:22px"></i> <span class="ph">www.mitech-africa.com</span></div><div><i class="fas fa-location-dot" style="width:22px"></i> <span class="ph">Libreville, Gabon</span></div></div></div>`;
const atout = (ic, t, d, c = B) => `<div class="at"><div class="ic" style="background:${c}"><i class="fas ${ic}"></i></div><div><b>${t}</b><span>${d}</span></div></div>`;

const flyers = {
// 1 — Généraliste : fond bleu profond, accroche, capture tablette, 6 atouts
generaliste: `<style>${base}
#page{background:linear-gradient(160deg,${B} 0%,${BF} 55%,#0a2a40 100%);color:#fff}
.fond{position:absolute;right:-260px;top:-240px}
.logo{position:absolute;left:56px;top:46px;height:62px;background:#fff;border-radius:12px;padding:8px 14px}
.tag{position:absolute;left:56px;top:150px;font-size:14px;letter-spacing:4px;color:#9cc3dd;font-weight:700}
h1{position:absolute;left:56px;top:178px;font-size:54px;line-height:1.05;font-weight:800;letter-spacing:-1px;width:560px}
.sous{position:absolute;left:56px;top:312px;font-size:18px;line-height:1.5;color:#d4e5f1;width:520px}
.tab{position:absolute;left:56px;top:400px;width:682px;border-radius:22px;background:#0b1f2e;padding:14px;box-shadow:0 40px 80px rgba(0,0,0,.45)}
.tab img{width:100%;height:296px;object-fit:cover;object-position:top;border-radius:10px;display:block}
.badge{position:absolute;right:40px;top:372px;background:${VERT};color:#fff;font-weight:700;font-size:15px;padding:12px 18px;border-radius:40px;box-shadow:0 10px 24px rgba(0,0,0,.3)}
.grille{position:absolute;left:56px;right:56px;top:750px;display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px 22px}
.at{display:flex;gap:12px;align-items:flex-start}.at .ic{flex:none;width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:17px;background:rgba(255,255,255,.14)!important}
.at b{display:block;font-size:15px}.at span{font-size:12.5px;color:#c4d9e8;line-height:1.4}
.cta{position:absolute;left:56px;right:56px;top:952px;text-align:center;font-size:17px;font-weight:700;color:#fff}
.cta span{background:${OR};padding:10px 26px;border-radius:30px}</style>
<svg class="fond" width="760" height="760">${arcs(380, 380, [330, 280, 230], ['rgba(255,255,255,.10)', 'rgba(255,255,255,.06)', 'rgba(255,255,255,.10)'], [30, 16, 30])}</svg>
<img class="logo" src="${logo}">
<div class="tag">GESCAISSE</div>
<h1>Votre caisse, enfin sous contrôle.</h1>
<div class="sous">Caisse, point de vente, stock et restauration réunis dans une seule application web, sur ordinateur, tablette ou écran tactile.</div>
<div class="badge"><i class="fas fa-mobile-screen"></i> Tactile · Multi-postes</div>
<div class="tab"><img src="${im('20_pos_vente')}"></div>
<div class="grille">
${atout('fa-cash-register', 'Journées de caisse', 'Ouverture, opérations, validation et clôture avec écart.')}
${atout('fa-store', 'Point de vente', 'Vente tactile, douchette, tickets et paiements mixtes.')}
${atout('fa-boxes-stacked', 'Stock', 'Entrées, inventaire et alertes de stock bas.')}
${atout('fa-utensils', 'Restaurant & bar', 'Plan de salle, commandes et écran cuisine.')}
${atout('fa-chart-line', 'Rapports', 'Ventes, opérations et export Sage.')}
${atout('fa-building', 'Multi-sociétés', 'Données cloisonnées, accès par profil.')}
</div>
<div class="cta"><span>Demandez votre démonstration gratuite</span></div>
${contact('#fff', '#1b2b38')}`,

// 2 — Restaurants et bars : clair, plan de salle + écran cuisine, parcours en 4 étapes
restaurant: `<style>${base}
#page{background:#fbf8f4}
.haut{position:absolute;left:0;top:0;right:0;height:440px;background:${BF};overflow:hidden}
.haut svg{position:absolute;left:-200px;top:-200px}
.logo{position:absolute;left:56px;top:44px;height:58px;background:#fff;border-radius:12px;padding:7px 13px}
.tag{position:absolute;right:56px;top:62px;color:#fff;font-size:13px;letter-spacing:3px;font-weight:700;background:${OR};padding:8px 16px;border-radius:20px}
h1{position:absolute;left:56px;top:140px;color:#fff;font-size:44px;line-height:1.08;font-weight:800;letter-spacing:-1px;width:690px}
.sous{position:absolute;left:56px;top:262px;color:#cfe0ec;font-size:18px;line-height:1.5;width:560px}
.c1{position:absolute;left:56px;top:370px;width:420px;border-radius:12px;border:6px solid #fff;box-shadow:0 26px 50px rgba(15,59,87,.35)}
.c2{position:absolute;left:392px;top:440px;width:350px;border-radius:12px;border:6px solid #fff;box-shadow:0 26px 50px rgba(15,59,87,.35)}
.leg{position:absolute;font-size:12px;font-weight:700;color:${BF};background:#fff;padding:5px 12px;border-radius:14px;box-shadow:0 4px 12px rgba(0,0,0,.12)}
h2{position:absolute;left:56px;top:700px;font-size:22px;color:${BF};font-weight:800}
.etapes{position:absolute;left:56px;right:56px;top:742px;display:grid;grid-template-columns:repeat(4,1fr);gap:14px}
.e{background:#fff;border-radius:14px;padding:16px 14px;box-shadow:0 6px 18px rgba(15,59,87,.08);border-top:4px solid ${B}}
.e .n{font-size:13px;font-weight:800;color:${OR}}.e b{display:block;font-size:15px;margin:4px 0 6px;color:${BF}}.e span{font-size:12.5px;color:#55687a;line-height:1.45}
.plus{position:absolute;left:56px;right:56px;top:918px;display:flex;flex-wrap:wrap;gap:8px}
.plus span{font-size:12.5px;background:#e8f0f6;color:${BF};padding:6px 12px;border-radius:16px;font-weight:600}</style>
<div class="haut"><svg width="700" height="700">${arcs(350, 350, [300, 255, 210], ['rgba(255,255,255,.09)', 'rgba(255,255,255,.05)', 'rgba(255,255,255,.09)'], [28, 14, 28])}</svg></div>
<img class="logo" src="${logo}"><div class="tag"><i class="fas fa-utensils"></i> RESTAURANTS & BARS</div>
<h1>Du plan de salle à l’addition, sans fausse note.</h1>
<div class="sous">GesCaisse suit chaque table, envoie les commandes en cuisine et au bar, et encaisse en quelques secondes.</div>
<img class="c1" src="${im('35_plan_salle_occupe')}"><img class="c2" src="${im('37_ecran_cuisine')}">
<div class="leg" style="left:70px;top:640px">Plan de salle en temps réel</div><div class="leg" style="left:560px;top:650px">Écran cuisine / bar</div>
<h2>Le service, en 4 étapes</h2>
<div class="etapes">
<div class="e"><div class="n">01</div><b>J’ouvre la table</b><span>Couverts, notes « bien cuit », menus et suppléments.</span></div>
<div class="e"><div class="n">02</div><b>J’envoie</b><span>Un bon par poste : la cuisine et le bar reçoivent leur part.</span></div>
<div class="e"><div class="n">03</div><b>Je sers</b><span>Écran cuisine avec temps d’attente et bouton « Prêt ».</span></div>
<div class="e"><div class="n">04</div><b>J’encaisse</b><span>Addition, partage, transfert de table et pourboire.</span></div>
</div>
<div class="plus"><span><i class="fas fa-check"></i> Menus et combos</span><span><i class="fas fa-check"></i> Plusieurs salles</span><span><i class="fas fa-check"></i> Plusieurs serveurs</span><span><i class="fas fa-check"></i> Stock des boissons</span><span><i class="fas fa-check"></i> Rapports de ventes</span><span><i class="fas fa-check"></i> Tickets 80 mm</span></div>
${contact(BF, '#fff')}`,

// 3 — Commerces et boutiques : blanc, arcs du logo, « avant / après », ticket + tableau de bord
commerce: `<style>${base}
#page{background:#fff}
.arc{position:absolute;right:-330px;top:-330px}
.logo{position:absolute;left:56px;top:48px;height:62px}
.tag{position:absolute;left:56px;top:150px;font-size:14px;letter-spacing:4px;color:${G};font-weight:700}
h1{position:absolute;left:56px;top:176px;font-size:50px;line-height:1.06;font-weight:800;color:${BF};letter-spacing:-1px;width:430px}
.sous{position:absolute;left:56px;top:330px;font-size:17px;line-height:1.55;color:#45586a;width:420px}
.ticket{position:absolute;z-index:2;left:505px;top:110px;width:240px;border-radius:4px;box-shadow:0 30px 60px rgba(15,59,87,.25);transform:rotate(4deg);overflow:hidden;background:#fff}
.ticket img{display:block;width:100%}
.dash{position:absolute;left:56px;top:470px;width:470px;border-radius:12px;border:6px solid #fff;box-shadow:0 26px 50px rgba(15,59,87,.25)}
.chiffre{position:absolute;left:556px;top:575px;width:184px;background:${B};color:#fff;border-radius:16px;padding:16px 18px}
.chiffre b{display:block;font-size:22px;margin:4px 0}.chiffre span{font-size:12.5px;color:#d4e5f1}
.av{position:absolute;left:56px;right:56px;top:775px;display:grid;grid-template-columns:1fr 1fr;gap:18px}
.col{border-radius:16px;padding:18px 20px}.col h3{font-size:16px;margin-bottom:10px}
.col div{font-size:13.5px;line-height:1.5;margin:6px 0;display:flex;gap:10px}
.avant{background:#f4f6f8;color:#5a6b78}.avant h3{color:#5a6b78}.avant i{color:#b04a3a;margin-top:3px}
.apres{background:#e9f4ee;color:#1d3b2b}.apres h3{color:${VERT}}.apres i{color:${VERT};margin-top:3px}</style>
<svg class="arc" width="800" height="800">${arcs(400, 400, [360, 315, 270], ['#e3edf4', '#efefef', '#e3edf4'], [34, 18, 34])}</svg>
<img class="logo" src="${logo}">
<div class="tag">GESCAISSE · COMMERCES</div>
<h1>Vendez plus vite. Comptez juste.</h1>
<div class="sous">Boutiques, supérettes, pharmacies ou quincailleries&nbsp;: un point de vente simple pour vos caissiers, et des chiffres clairs pour vous.</div>
<div class="ticket"><img src="${uri(path.join(D, 'ticket_demo.jpg'))}"></div>
<img class="dash" src="${im('02_tableau_de_bord')}">
<div class="chiffre"><i class="fas fa-bolt"></i><b>Temps réel</b><span>Solde de caisse, ventes et alertes, où que vous soyez.</span></div>
<div class="av">
<div class="col avant"><h3>Sans GesCaisse</h3>
<div><i class="fas fa-xmark"></i>Cahiers de caisse et calculs à la main</div>
<div><i class="fas fa-xmark"></i>Écarts de caisse inexpliqués</div>
<div><i class="fas fa-xmark"></i>Ruptures de stock découvertes trop tard</div>
<div><i class="fas fa-xmark"></i>Saisie comptable en double</div></div>
<div class="col apres"><h3>Avec GesCaisse</h3>
<div><i class="fas fa-check"></i>Ticket imprimé, monnaie calculée</div>
<div><i class="fas fa-check"></i>Clôture avec comptage et écart justifié</div>
<div><i class="fas fa-check"></i>Alertes de stock bas et inventaire</div>
<div><i class="fas fa-check"></i>Export direct vers Sage</div></div>
</div>
${contact('#f1f5f8', '#1b2b38')}`
};

const noms = { generaliste: 'Flyer_GesCaisse_General', restaurant: 'Flyer_GesCaisse_Restaurants_Bars', commerce: 'Flyer_GesCaisse_Commerces' };

(async () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'flyers-'));
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 794, height: 1123 } });
  for (const [k, html] of Object.entries(flyers)) {
    const f = path.join(tmp, k + '.html');
    fs.writeFileSync(f, `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="${FA}">
<style>@page{size:A4;margin:0} html,body{margin:0;width:794px;height:1123px;overflow:hidden;-webkit-print-color-adjust:exact;print-color-adjust:exact}</style></head><body><div id="page">${html}</div></body></html>`);
    await p.goto('file://' + f, { waitUntil: 'networkidle' });
    await p.evaluate(() => document.fonts.ready);
    await p.pdf({ path: path.join(D, noms[k] + '.pdf'), width: '210mm', height: '297mm', printBackground: true, margin: { top: 0, right: 0, bottom: 0, left: 0 }, pageRanges: '1' });
    console.log('ok', noms[k] + '.pdf');
  }
  // Images : PNG 300 dpi (2481 × 3509 px) pour l'impression, JPEG 1240 px pour WhatsApp / réseaux sociaux.
  fs.mkdirSync(path.join(D, 'images'), { recursive: true });
  for (const [echelle, ext, opts] of [[3.125, 'png', {}], [1.5617, 'jpg', { type: 'jpeg', quality: 88 }]]) {
    const pi = await b.newPage({ viewport: { width: 794, height: 1123 }, deviceScaleFactor: echelle });
    for (const k of Object.keys(flyers)) {
      await pi.goto('file://' + path.join(tmp, k + '.html'), { waitUntil: 'networkidle' });
      await pi.evaluate(() => document.fonts.ready);
      await pi.screenshot({ path: path.join(D, 'images', noms[k] + '.' + ext), ...opts });
      console.log('ok', 'images/' + noms[k] + '.' + ext);
    }
    await pi.close();
  }
  await b.close();
  fs.rmSync(tmp, { recursive: true, force: true });
})();
