const fs = require('fs');
const path = require('path');
const readline = require('readline');
const https = require('https');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

function apiRequest(method, endpoint, body = null) {
  return new Promise((resolve) => {
    const dataStr = body ? JSON.stringify(body) : null;
    const req = https.request({
      hostname: 'api.nuvemshop.com.br',
      path: endpoint,
      method: method,
      headers: {
        'Authentication': 'bearer ' + ACCESS_TOKEN,
        'Content-Type': 'application/json',
        'Content-Length': dataStr ? Buffer.byteLength(dataStr) : 0,
        'User-Agent': 'FortbrasCategorySync/1.0'
      }
    }, res => {
      let resData = '';
      res.on('data', chunk => resData += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(resData) });
        } catch(e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: resData });
        }
      });
    });
    req.on('error', (err) => resolve({ status: 500, error: err }));
    if (dataStr) req.write(dataStr);
    req.end();
  });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function getExistingCategories() {
  const res = await apiRequest('GET', `/v1/${STORE_ID}/categories`);
  if (!Array.isArray(res.data)) return [];
  return res.data;
}

async function extractUniqueCategoriesFromVtex() {
  console.log('Extraindo todas as categorias únicas de vtex_products_master.ndjson...');
  const filePath = 'C:/D/@Fortbras/projeto nuvemshop/catalog/vtex_products_master.ndjson';
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

  const categoryTreeSet = new Set();

  for await (const line of rl) {
    if (!line.trim()) continue;
    const idx = line.indexOf('"categoryPath":');
    if (idx !== -1) {
      const endIdx = line.indexOf(']', idx);
      if (endIdx !== -1) {
        const catStr = line.substring(idx + 15, endIdx + 1);
        try {
          const arr = JSON.parse(catStr);
          if (Array.isArray(arr) && arr.length > 0) {
            categoryTreeSet.add(JSON.stringify(arr.map(c => c.trim())));
          }
        } catch(e) {}
      }
    }
  }

  const result = Array.from(categoryTreeSet).map(s => JSON.parse(s));
  console.log(`Encontradas ${result.length} estruturas de categorias únicas na VTEX.`);
  return result;
}

async function syncCategories() {
  console.log('================================================================');
  console.log('🌳 SINCRONIZAÇÃO E CRIAÇÃO DA ÁRVORE DE CATEGORIAS NA NUVEMSHOP');
  console.log('================================================================\n');

  // 1. Busca categorias existentes
  let existing = await getExistingCategories();
  console.log(`Categorias atualmente existentes na Nuvemshop: ${existing.length}\n`);

  const catMap = new Map();
  existing.forEach(c => {
    const parentId = c.parent || null;
    const nameUpper = (c.name?.pt || '').trim().toUpperCase();
    catMap.set(`${nameUpper}_${parentId}`, c.id);
  });

  // 2. Extrai categorias da VTEX
  const vtexTrees = await extractUniqueCategoriesFromVtex();

  // 3. Garante criação de nível 1, nível 2 e nível 3
  let createdCount = 0;

  for (const tree of vtexTrees) {
    let parentId = null;

    for (let level = 0; level < tree.length; level++) {
      const catName = tree[level];
      if (!catName || catName.toUpperCase() === 'INTEGRAÇÃO') continue;

      const key = `${catName.toUpperCase()}_${parentId}`;

      if (!catMap.has(key)) {
        console.log(`Criando categoria na Nuvemshop: "${catName}" (Parent ID: ${parentId})...`);
        const payload = {
          name: { pt: catName },
          parent: parentId, // null para raiz ou número para filha
          google_shopping_category: 'Veículos e peças > Peças e acessórios para veículos'
        };

        const res = await apiRequest('POST', `/v1/${STORE_ID}/categories`, payload);
        if (res.status === 201 && res.data?.id) {
          const newId = res.data.id;
          catMap.set(key, newId);
          parentId = newId;
          createdCount++;
          console.log(`  ✅ Criada com ID: ${newId}`);
        } else {
          console.error(`  ❌ Falha ao criar categoria "${catName}":`, res.status, res.data);
          break;
        }
        await sleep(150);
      } else {
        parentId = catMap.get(key);
      }
    }
  }

  console.log(`\n🎉 Criação de categorias concluída! Novas categorias criadas: ${createdCount}`);

  // 4. Salva mapa final de categorias para o agente sincronizador
  const finalExisting = await getExistingCategories();
  console.log(`Total de categorias na Nuvemshop agora: ${finalExisting.length}`);

  const categoryLookup = {};
  vtexTrees.forEach(tree => {
    let parentId = null;
    let lastId = null;
    for (const catName of tree) {
      if (catName.toUpperCase() === 'INTEGRAÇÃO') continue;
      const key = `${catName.toUpperCase()}_${parentId}`;
      if (catMap.has(key)) {
        parentId = catMap.get(key);
        lastId = parentId;
      }
    }
    if (lastId) {
      const pathStr = tree.join(' > ').toUpperCase();
      categoryLookup[pathStr] = lastId;
      const leafName = tree[tree.length - 1].toUpperCase();
      if (!categoryLookup[leafName]) categoryLookup[leafName] = lastId;
    }
  });

  fs.writeFileSync('nuvemshop_category_map.json', JSON.stringify(categoryLookup, null, 2), 'utf8');
  console.log(`Mapeamento salvo em nuvemshop_category_map.json com ${Object.keys(categoryLookup).length} caminhos mapeados!\n`);
}

syncCategories().catch(console.error);
