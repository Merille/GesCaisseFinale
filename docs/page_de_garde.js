// Section « page de garde » pleine page (image A4 de pages_de_garde/), commune aux documents.
const fs = require('fs');
const path = require('path');
const { Paragraph, ImageRun, HorizontalPositionRelativeFrom, VerticalPositionRelativeFrom, TextWrappingType } = require('docx');

module.exports = function sectionGarde(fichier, titre) {
    return {
        properties: { page: { margin: { top: 0, right: 0, bottom: 0, left: 0, header: 0, footer: 0 } } },
        children: [new Paragraph({ children: [new ImageRun({
            type: 'jpg', data: fs.readFileSync(path.join(__dirname, 'pages_de_garde', fichier)),
            transformation: { width: 794, height: 1123 },
            altText: { title: titre, description: titre, name: 'Page de garde' },
            floating: {
                horizontalPosition: { relative: HorizontalPositionRelativeFrom.PAGE, offset: 0 },
                verticalPosition: { relative: VerticalPositionRelativeFrom.PAGE, offset: 0 },
                wrap: { type: TextWrappingType.NONE }, behindDocument: true, allowOverlap: true
            }
        })] })]
    };
};
