// Illustrations des articles de démonstration (JPEG 600 × 300, sans droits d'auteur) : pictogramme
// Font Awesome sur la couleur de la catégorie de l'article. Le pictogramme reste au centre : il est
// entier sur les tuiles larges de l'écran de vente comme dans un recadrage carré.
// Usage : node Scripts/images_demo/generer_images_demo.js
// Prérequis : npm install playwright @fortawesome/fontawesome-free (NODE_PATH vers ces modules).
// Les images obtenues (Scripts/images_demo/<CODE>.jpg) sont reprises dans les scripts et la base de démonstration.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ARTICLES = [
    // code, couleur de la catégorie, pictogramme
    ['ACC01', '#ca8a04', 'bowl-food'], ['ACC02', '#ca8a04', 'plate-wheat'], ['ACC03', '#ca8a04', 'bowl-rice'],
    ['PLA01', '#b91c1c', 'drumstick-bite'], ['PLA02', '#b91c1c', 'fish'], ['PLA03', '#b91c1c', 'bacon'], ['MEN01', '#b91c1c', 'utensils'],
    ['BIE01', '#15803d', 'wine-bottle'], ['BIE02', '#15803d', 'beer-mug-empty'],
    ['BOI01', '#195d84', 'glass-water'], ['BOI02', '#195d84', 'bottle-water'], ['BOI03', '#195d84', 'lemon'],
    ['EPI01', '#0f7a4a', 'jar-wheat'], ['EPI02', '#0f7a4a', 'bottle-droplet'], ['EPI03', '#0f7a4a', 'cubes-stacked'],
    ['BOU01', '#c2410c', 'wheat-awn'], ['BOU02', '#c2410c', 'moon'], ['BOU03', '#c2410c', 'bread-slice'],
    ['LAI01', '#6d28d9', 'cow'], ['LAI02', '#6d28d9', 'jar'], ['LAI03', '#6d28d9', 'cheese'],
    ['HYG01', '#0e7490', 'soap'], ['HYG02', '#0e7490', 'tooth'], ['HYG03', '#0e7490', 'toilet-paper'],
    ['ENT01', '#a16207', 'jug-detergent'], ['ENT02', '#a16207', 'shirt'], ['ENT03', '#a16207', 'pump-soap'],
    ['PAP01', '#be185d', 'file-lines'], ['PAP02', '#be185d', 'pen'], ['PAP03', '#be185d', 'book'],
    ['ELE01', '#334155', 'battery-full'], ['ELE02', '#334155', 'plug'], ['ELE03', '#334155', 'headphones'],
    ['SNA01', '#9333ea', 'cookie'], ['SNA02', '#9333ea', 'bag-shopping'], ['SNA03', '#9333ea', 'candy-cane'],
    ['SER01', '#64748b', 'copy'], ['SER02', '#64748b', 'print'], ['SER03', '#64748b', 'keyboard']
];

(async () => {
    const fa = path.dirname(require.resolve('@fortawesome/fontawesome-free/package.json'));
    // Polices intégrées à la page (une page sans adresse ne charge pas les fichiers locaux).
    const css = fs.readFileSync(path.join(fa, 'css/all.min.css'), 'utf8')
        .replace(/url\(\.\.\/webfonts\/([^)]+?\.woff2)\)/g, (m, f) =>
            'url(data:font/woff2;base64,' + fs.readFileSync(path.join(fa, 'webfonts', f)).toString('base64') + ')')
        .replace(/,\s*url\(\.\.\/webfonts\/[^)]+?\.ttf\) format\("truetype"\)/g, '');
    const vignette = (code, couleur, icone) =>
        '<div class="v" id="' + code + '" style="--c:' + couleur + '"><span class="rond"></span><span class="rond deux"></span>'
        + '<span class="disque"><i class="fa-solid fa-' + icone + '"></i></span></div>';
    const html = '<!doctype html><html><head><meta charset="utf-8"><style>' + css + `
        body { margin: 0; background: #fff; display: flex; flex-wrap: wrap; }
        .v { position: relative; width: 600px; height: 300px; overflow: hidden;
             background: linear-gradient(145deg, color-mix(in srgb, var(--c) 72%, #fff) 0%, var(--c) 58%, color-mix(in srgb, var(--c) 78%, #000) 100%); }
        .rond { position: absolute; width: 360px; height: 360px; border-radius: 50%; right: -110px; top: -190px; background: rgba(255,255,255,.10); }
        .rond.deux { width: 260px; height: 260px; left: -80px; bottom: -150px; top: auto; right: auto; background: rgba(0,0,0,.08); }
        .disque { position: absolute; left: 50%; top: 50%; width: 190px; height: 190px; margin: -95px 0 0 -95px; border-radius: 50%;
                  background: #fff; box-shadow: 0 18px 40px rgba(0,0,0,.22), inset 0 -8px 0 rgba(0,0,0,.05);
                  display: flex; align-items: center; justify-content: center; }
        .disque i { font-size: 96px; color: var(--c); filter: drop-shadow(0 4px 0 rgba(0,0,0,.08)); }
    </style></head><body>` + ARTICLES.map(a => vignette(...a)).join('') + '</body></html>';
    const b = await chromium.launch();
    const p = await b.newPage({ viewport: { width: 1800, height: 300 } });
    await p.setContent(html, { waitUntil: 'load' });
    await p.evaluate(() => document.fonts.ready);
    for (const [code] of ARTICLES) {
        await p.locator('#' + code).screenshot({ path: path.join(__dirname, code + '.jpg'), type: 'jpeg', quality: 82 });
    }
    await b.close();
    console.log(ARTICLES.length + ' images générées dans ' + __dirname);
})();
