/**
 * sync_all_vtex_tags.js
 * 
 * Sincroniza em lote o campo "Tags" (Palavras-chave SEO) de TODOS os produtos da Nuvemshop
 * com o campo oficial "Palavras similares" exportado do catálogo da VTEX.
 * 
 * Regra estrita: Altera EXCLUSIVAMENTE o campo `tags`. Não altera preço, estoque, categorias,
 * imagens, descrições ou custom_fields.
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

const NDJSON_FILE = path.join(__dirname, 'vtex_tags_index.ndjson');
const CHECKPOINT_FILE = path.join(__dirname, 'tags_sync_checkpoint.json');

const CONCURRENCY = 4;

function apiRequest(method, endpoint, body = null, retries = 5) {
  return new Promise(async (resolve) => {
    for (let attempt = 1; attempt <= retries; attempt++) {
      const dataStr = body ? JSON.stringify(body) : null;
      const res = await new Promise((resResolve) => {
        const req = https.request({
          hostname: 'api.nuvemshop.com.br',
          path: endpoint,
          method: method,
          headers: {
            'Authentication': 'bearer ' + ACCESS_TOKEN,
            'Content-Type': 'application/json',
            'Content-Length': dataStr ? Buffer.byteLength(dataStr) : 0,
            'User-Agent': 'FortbrasVtexTagsSync/1.0'
          }
        }, r => {
          let b = '';
          r.on('data', d => b += d);
          r.on('end', () => {
            try {
              resResolve({ status: r.statusCode, headers: r.headers, data: JSON.parse(b) });
            } catch(e) {
              resResolve({ status: r.statusCode, headers: r.headers, raw: b });
            }
          });
        });
        req.on('error', err => resResolve({ status: 500, error: err }));
        if (dataStr) req.write(dataStr);
        req.end();
      });

      if (res.status === 429) {
        const wait = (parseInt(res.headers['retry-after'] || '2') + 1) * 1000;
        await sleep(wait);
        continue;
      }
      if (res.status >= 500 && attempt < retries) {
        await sleep(attempt * 1000);
        continue;
      }
      return resolve(res);
    }
    resolve({ status: 500, error: 'Exceeded max retries' });
  });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function loadVtexTagsIndex() {
  console.log('⚡ Carregando base indexada de "Palavras Similares" da VTEX...');
  const t0 = Date.now();
  const skuMap = new Map();
  const eanMap = new Map();
  const refMap = new Map();
  const nameMap = new Map();

  if (!fs.existsSync(NDJSON_FILE)) {
    throw new Error(`Arquivo ${NDJSON_FILE} não encontrado! Execute build_vtex_tags_ndjson.js primeiro.`);
  }

  const rl = readline.createInterface({ input: fs.createReadStream(NDJSON_FILE), crlfDelay: Infinity });
  let count = 0;
  for await (const line of rl) {
    if (!line.trim()) continue;
    const r = JSON.parse(line);
    count++;
    if (r.skuId) skuMap.set(r.skuId, r.palavras);
    if (r.ean && r.ean !== '000000' && r.ean !== '0') eanMap.set(r.ean, r.palavras);
    if (r.skuRef) refMap.set(r.skuRef.toUpperCase().trim(), r.palavras);
    if (r.prodRef) refMap.set(r.prodRef.toUpperCase().trim(), r.palavras);
    if (r.name) {
      const k = r.name.toLowerCase().replace(/\s+/g, ' ').slice(0, 45).trim();
      if (!nameMap.has(k)) nameMap.set(k, r.palavras);
    }
  }

  const dur = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`✅ Base VTEX carregada em ${dur}s: ${count} registros indexados.`);
  console.log(`   - SKUs: ${skuMap.size} | EANs: ${eanMap.size} | Referências: ${refMap.size} | Nomes: ${nameMap.size}\n`);

  return { skuMap, eanMap, refMap, nameMap };
}

function normalizeTagsForComparison(str) {
  if (!str) return '';
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .sort()
    .join(',');
}

async function runSync() {
  console.log('================================================================');
  console.log('🚀 SINCRONIZAÇÃO EM MASSA: VTEX PALAVRAS SIMILARES -> NUVEMSHOP TAGS');
  console.log('Loja Nuvemshop:', STORE_ID);
  console.log('Concorrência:', CONCURRENCY);
  console.log('================================================================\n');

  const { skuMap, eanMap, refMap, nameMap } = await loadVtexTagsIndex();

  let startPage = 1;
  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalAlreadyUpToDate = 0;
  let totalNoMatch = 0;

  if (fs.existsSync(CHECKPOINT_FILE)) {
    try {
      const cp = JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
      if (cp.lastPage) {
        startPage = cp.lastPage + 1;
        totalProcessed = cp.totalProcessed || 0;
        totalUpdated = cp.totalUpdated || 0;
        totalAlreadyUpToDate = cp.totalAlreadyUpToDate || 0;
        totalNoMatch = cp.totalNoMatch || 0;
        console.log(`🔄 Retomando do Checkpoint na Página ${startPage} (Já processados: ${totalProcessed} | Atualizados: ${totalUpdated})\n`);
      }
    } catch(e) {
      console.warn('Aviso: Falha ao ler checkpoint, iniciando da página 1:', e.message);
    }
  }

  const tStart = Date.now();
  let currentPage = startPage;

  while (true) {
    const listRes = await apiRequest('GET', `/v1/${STORE_ID}/products?page=${currentPage}&per_page=100`);

    if (listRes.status !== 200 || !Array.isArray(listRes.data)) {
      console.error(`❌ Erro ao listar página ${currentPage}:`, listRes.status, listRes.data);
      break;
    }

    const products = listRes.data;
    if (products.length === 0) {
      console.log(`\nFim dos produtos na página ${currentPage}.`);
      break;
    }

    let pageUpdated = 0;
    let pageAlreadyUpToDate = 0;
    let pageNoMatch = 0;

    // Worker pool para atualizar produtos em paralelo
    const updateQueue = [];

    for (const p of products) {
      let vtexTags = null;
      let matchedBy = null;

      for (const v of (p.variants || [])) {
        if (v.sku && skuMap.has(v.sku)) {
          vtexTags = skuMap.get(v.sku);
          matchedBy = 'SKU:' + v.sku;
          break;
        }
        if (v.barcode && eanMap.has(v.barcode)) {
          vtexTags = eanMap.get(v.barcode);
          matchedBy = 'EAN:' + v.barcode;
          break;
        }
      }

      if (!vtexTags && p.name && p.name.pt) {
        const k = p.name.pt.toLowerCase().replace(/\s+/g, ' ').slice(0, 45).trim();
        if (nameMap.has(k)) {
          vtexTags = nameMap.get(k);
          matchedBy = 'Name';
        }
      }

      if (!vtexTags) {
        pageNoMatch++;
        totalNoMatch++;
        continue;
      }

      // Compara tags normalizadas para evitar chamadas desnecessárias
      const currentTagsNorm = normalizeTagsForComparison(p.tags || '');
      const vtexTagsNorm = normalizeTagsForComparison(vtexTags);

      if (currentTagsNorm === vtexTagsNorm) {
        pageAlreadyUpToDate++;
        totalAlreadyUpToDate++;
        continue;
      }

      updateQueue.push({
        product: p,
        vtexTags,
        matchedBy
      });
    }

    // Executa atualizações com concorrência limitada
    for (let i = 0; i < updateQueue.length; i += CONCURRENCY) {
      const chunk = updateQueue.slice(i, i + CONCURRENCY);
      await Promise.all(chunk.map(async ({ product, vtexTags, matchedBy }) => {
        const updateRes = await apiRequest('PUT', `/v1/${STORE_ID}/products/${product.id}`, {
          tags: vtexTags
        });

        if (updateRes.status === 200) {
          pageUpdated++;
          totalUpdated++;
          if (totalUpdated % 20 === 0) {
            const pName = product.name?.pt || 'Sem nome';
            console.log(`✅ [Tags #${totalUpdated}] Prod ${product.id} (${matchedBy}): ${vtexTags.slice(0, 75)}...`);
          }
        } else {
          console.error(`❌ Falha ao atualizar Tags no Prod ${product.id}:`, updateRes.status, updateRes.data);
        }
      }));
    }

    totalProcessed += products.length;
    console.log(`[Página ${currentPage}] Produtos: ${products.length} | Atualizados: ${pageUpdated} | Já atualizados: ${pageAlreadyUpToDate} | Sem match: ${pageNoMatch} | Total acumulado: ${totalUpdated}`);

    // Salva Checkpoint a cada página
    fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify({
      lastPage: currentPage,
      totalProcessed,
      totalUpdated,
      totalAlreadyUpToDate,
      totalNoMatch,
      updatedAt: new Date().toISOString()
    }, null, 2));

    currentPage++;
    await sleep(250);
  }

  const elapsedMin = ((Date.now() - tStart) / 60000).toFixed(1);
  console.log('\n================================================================');
  console.log('🎉 SINCRONIZAÇÃO DE PALAVRAS SIMILARES (TAGS) CONCLUÍDA!');
  console.log(`📦 Total de produtos processados: ${totalProcessed}`);
  console.log(`🏷️ Total de produtos atualizados com Tags VTEX: ${totalUpdated}`);
  console.log(`✨ Total de produtos que já estavam atualizados: ${totalAlreadyUpToDate}`);
  console.log(`❓ Total de produtos sem match na VTEX: ${totalNoMatch}`);
  console.log(`⏱️ Tempo total: ${elapsedMin} minutos`);
  console.log('================================================================\n');
}

runSync().catch(console.error);
