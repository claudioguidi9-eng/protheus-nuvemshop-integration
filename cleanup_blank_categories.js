const fs = require('fs');
const path = require('path');
const https = require('https');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

const RECOVERED_FILE = path.join(__dirname, 'recovered_cat_names.json');
const recoveredNames = fs.existsSync(RECOVERED_FILE) ? JSON.parse(fs.readFileSync(RECOVERED_FILE, 'utf8')) : {};

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
        'User-Agent': 'FortbrasCatCleaner/1.0'
      }
    }, res => {
      let resData = '';
      res.on('data', chunk => resData += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(resData) });
        } catch(e) {
          resolve({ status: res.statusCode, raw: resData });
        }
      });
    });
    req.on('error', (err) => resolve({ status: 500, error: err }));
    if (dataStr) req.write(dataStr);
    req.end();
  });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function fetchAllCategories() {
  let all = [];
  let page = 1;
  while (true) {
    const res = await apiRequest('GET', `/v1/${STORE_ID}/categories?per_page=200&page=${page}`);
    if (res.status !== 200 || !Array.isArray(res.data) || res.data.length === 0) break;
    all = all.concat(res.data);
    page++;
    await sleep(100);
  }
  return all;
}

async function runCleanup() {
  console.log('================================================================');
  console.log('🧹 LIMPEZA E RESTAURAÇÃO COMPLETA DE CATEGORIAS DA NUVEMSHOP');
  console.log('================================================================\n');

  console.log('1. Obtendo todas as categorias atuais da Nuvemshop...');
  const categories = await fetchAllCategories();
  console.log(`Total encontrado: ${categories.length} categorias.\n`);

  // Identifica categorias em branco
  const blankCats = categories.filter(c => !c.name || !c.name.pt || c.name.pt.trim() === '');
  console.log(`Categorias em branco encontradas: ${blankCats.length}`);

  // Separa as que são pais (possuem subcategorias) das que são folhas (sem subcategorias)
  const parentsToRestore = blankCats.filter(c => c.subcategories && c.subcategories.length > 0);
  const leavesToDelete = blankCats.filter(c => !c.subcategories || c.subcategories.length === 0);

  console.log(`- Pais a restaurar o nome: ${parentsToRestore.length}`);
  console.log(`- Folhas em branco a excluir: ${leavesToDelete.length}\n`);

  // 1. Restaura o nome dos Pais
  console.log('--- ETAPA 1: RESTAURANDO NOMES DOS PAIS ---');
  for (const p of parentsToRestore) {
    const originalName = recoveredNames[p.id] || 'Autopeças';
    console.log(`Restaurando Categoria Pai ${p.id} -> "${originalName}"...`);
    const upRes = await apiRequest('PUT', `/v1/${STORE_ID}/categories/${p.id}`, {
      name: { pt: originalName },
      google_shopping_category: 'Veículos e peças > Peças e acessórios para veículos'
    });
    console.log(`Status: ${upRes.status}`);
    await sleep(200);
  }

  // 2. Exclui categorias em branco (folhas)
  console.log('\n--- ETAPA 2: EXCLUINDO CATEGORIAS EM BRANCO (FOLHAS) ---');
  let deletedCount = 0;
  for (let i = 0; i < leavesToDelete.length; i++) {
    const c = leavesToDelete[i];
    const delRes = await apiRequest('DELETE', `/v1/${STORE_ID}/categories/${c.id}`);
    if (delRes.status === 200 || delRes.status === 204) {
      deletedCount++;
    }
    if ((i + 1) % 50 === 0 || i === leavesToDelete.length - 1) {
      console.log(`Progresso de exclusão: ${i + 1}/${leavesToDelete.length} excluídas com sucesso.`);
    }
    await sleep(60);
  }

  // 3. Identifica e exclui categorias com caracteres corrompidos
  console.log('\n--- ETAPA 3: LIMPANDO CATEGORIAS COM NOMES CORROMPIDOS ---');
  const freshCats = await fetchAllCategories();
  const corrupted = freshCats.filter(c => c.name?.pt && (c.name.pt.includes('') || c.name.pt.includes('??')));
  console.log(`Categorias corrompidas encontradas: ${corrupted.length}`);

  let corruptedDeleted = 0;
  for (const c of corrupted) {
    if (!c.subcategories || c.subcategories.length === 0) {
      const del = await apiRequest('DELETE', `/v1/${STORE_ID}/categories/${c.id}`);
      if (del.status === 200 || del.status === 204) {
        corruptedDeleted++;
        console.log(`Excluída corrompida: ${c.id} (${c.name.pt})`);
      }
      await sleep(60);
    }
  }

  console.log('\n================================================================');
  console.log(`🎉 LIMPEZA CONCLUÍDA COM SUCESSO!`);
  console.log(`- Nomes de Pais restaurados: ${parentsToRestore.length}`);
  console.log(`- Linhas em branco excluídas: ${deletedCount}`);
  console.log(`- Nomes corrompidos excluídos: ${corruptedDeleted}`);
  const finalCats = await fetchAllCategories();
  console.log(`- Total final de categorias limpas na loja: ${finalCats.length}`);
  console.log('================================================================\n');
}

runCleanup().catch(console.error);
