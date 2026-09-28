const unzipper = require('unzipper');
const fs = require('fs');
const path = require('path');

const EXCEL_PATH = 'C:\\D\\@Fortbras\\projeto nuvemshop\\catalog\\2026-09-25T01_42_44Z_produtos-e-skus_fortbras.xlsx';
const OUTPUT_NDJSON = path.join(__dirname, 'vtex_tags_index.ndjson');

async function buildNdjson() {
  console.log('================================================================');
  console.log('⚡ GERANDO ÍNDICE NDJSON DE "PALAVRAS SIMILARES" DA VTEX');
  console.log('Origem:', EXCEL_PATH);
  console.log('Destino:', OUTPUT_NDJSON);
  console.log('================================================================\n');

  const t0 = Date.now();
  const directory = await unzipper.Open.file(EXCEL_PATH);
  const sheetFile = directory.files.find(d => d.path === 'xl/worksheets/sheet1.xml');
  const stream = sheetFile.stream();

  const outStream = fs.createWriteStream(OUTPUT_NDJSON, { flags: 'w', encoding: 'utf8' });

  let buffer = '';
  let rowCount = 0;
  let savedCount = 0;

  for await (const chunk of stream) {
    buffer += chunk.toString('utf8');
    const rowRegex = /<row r="(\d+)"[^>]*>([\s\S]*?)<\/row>/g;
    let rMatch;
    let lastIndex = 0;

    while ((rMatch = rowRegex.exec(buffer)) !== null) {
      lastIndex = rowRegex.lastIndex;
      const rowNum = parseInt(rMatch[1]);
      const rowContent = rMatch[2];
      rowCount++;

      if (rowNum > 2) {
        // Células sequenciais
        const cellRegex = /<c[^>]*>(?:<is><t>([\s\S]*?)<\/t><\/is>|<v>([\s\S]*?)<\/v>)?<\/c>|<c[^>]*\/>/g;
        let cMatch;
        let colIdx = 0;
        let rowCols = [];
        while ((cMatch = cellRegex.exec(rowContent)) !== null) {
          const val = cMatch[1] !== undefined ? cMatch[1] : (cMatch[2] !== undefined ? cMatch[2] : '');
          rowCols[colIdx++] = val;
        }

        const palavras = (rowCols[20] || '').trim();
        if (palavras) {
          const record = {
            prodId: (rowCols[0] || '').trim(),
            name: (rowCols[1] || '').trim(),
            palavras: palavras,
            prodRef: (rowCols[21] || '').trim(),
            skuId: (rowCols[23] || '').trim(),
            skuRef: (rowCols[28] || '').trim(),
            ean: (rowCols[29] || '').trim()
          };
          outStream.write(JSON.stringify(record) + '\n');
          savedCount++;
        }
      }

      if (rowCount % 25000 === 0) {
        const mem = (process.memoryUsage().heapUsed / (1024*1024)).toFixed(0);
        console.log(`Linhas: ${rowCount} | Tags salvas: ${savedCount} | Heap: ${mem}MB | Tempo: ${((Date.now() - t0)/1000).toFixed(1)}s`);
      }
    }

    if (lastIndex > 0) {
      buffer = buffer.slice(lastIndex);
    }
  }

  outStream.end();
  const dur = ((Date.now() - t0)/1000).toFixed(1);
  console.log(`\n🎉 Concluído em ${dur}s!`);
  console.log(`Total de linhas processadas: ${rowCount}`);
  console.log(`Total de produtos com palavras similares gravados no NDJSON: ${savedCount}`);
  const stats = fs.statSync(OUTPUT_NDJSON);
  console.log(`Tamanho do arquivo: ${(stats.size / (1024*1024)).toFixed(2)} MB`);
}

buildNdjson().catch(console.error);
