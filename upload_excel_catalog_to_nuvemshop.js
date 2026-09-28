const fs = require('fs');
const path = require('path');
const readline = require('readline');

const ROOT = __dirname;
const TOKEN_FILE = path.join(ROOT, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const MASTER_NDJSON = 'C:\\D\\@Fortbras\\projeto nuvemshop\\catalog\\vtex_products_master.ndjson';
const CHECKPOINT_FILE = path.join(ROOT, 'sync_checkpoint_excel.json');
const CAT_CACHE_FILE = path.join(ROOT, 'nuvemshop_category_cache.json');

if (!fs.existsSync(TOKEN_FILE)) {
  console.error('Arquivo de token não encontrado:', TOKEN_FILE);
  process.exit(1);
}

const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const STORE_ID = tokenData.user_id;
const ACCESS_TOKEN = tokenData.access_token;
const USER_AGENT = 'IntegracaoFortbrasProtheus (contato@fortbras.com.br)';
const API_HOST = 'https://api.nuvemshop.com.br/unstable';
const VERCEL_API = 'https://toat-fortbras.vercel.app/api/events';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function reportTelemetry(msg, count, total) {
  try {
    await fetch(VERCEL_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        event: 'SYNC_EXCEL_PROGRESS',
        message: msg,
        count: count,
        total: total,
        timestamp: new Date().toISOString()
      }),
      signal: AbortSignal.timeout(3000)
    });
  } catch (e) { }
}

class NuvemshopClient {
  constructor() {
    this.minIntervalMs = 600; // ~1.6 req/s
    this.lastCall = 0;
  }

  async throttle() {
    const elapsed = Date.now() - this.lastCall;
    const wait = this.minIntervalMs - elapsed;
    if (wait > 0) await sleep(wait);
    this.lastCall = Date.now();
  }

  async request(method, pathname, body) {
    const url = `${API_HOST}/${STORE_ID}${pathname}`;
    const headers = {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'User-Agent': USER_AGENT,
      'Accept': 'application/json'
    };
    if (body !== undefined) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }

    for (let attempt = 1; attempt <= 6; attempt++) {
      await this.throttle();
      try {
        const res = await fetch(url, {
          method,
          headers,
          body: body !== undefined ? JSON.stringify(body) : undefined
        });

        const text = await res.text();
        let data = null;
        try { data = text ? JSON.parse(text) : null; } catch { data = text; }

        if (res.status === 429 || res.status >= 500) {
          const resetHeader = Number(res.headers.get('x-rate-limit-reset')) || 0;
          const waitTime = res.status === 429 ? Math.max(resetHeader * 1000, 2000 * attempt) : 1500 * attempt;
          process.stdout.write(` [429: aguardando ${(waitTime / 1000).toFixed(1)}s] `);
          await sleep(waitTime);
          continue;
        }

        if (res.status === 404) return null;
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}: ${JSON.stringify(data)}`);
        }

        return data;
      } catch (err) {
        if (attempt === 6) throw err;
        await sleep(1000 * attempt);
      }
    }
  }

  get(p) { return this.request('GET', p); }
  post(p, b) { return this.request('POST', p, b); }
}

async function loadCategoryIndex(api) {
  console.log('Indexando categorias da Nuvemshop...');
  const catIndex = new Map();

  if (fs.existsSync(CAT_CACHE_FILE)) {
    try {
      const cached = JSON.parse(fs.readFileSync(CAT_CACHE_FILE, 'utf8'));
      for (const [k, v] of Object.entries(cached)) catIndex.set(k, v);
      console.log(`Cache local de categorias carregado: ${catIndex.size} categorias.`);
      return catIndex;
    } catch { }
  }

  for (let page = 1; ; page++) {
    const batch = await api.get(`/categories?per_page=200&page=${page}`);
    if (!Array.isArray(batch) || batch.length === 0) break;
    for (const c of batch) {
      const nameStr = c.name?.pt || Object.values(c.name || {})[0] || '';
      if (nameStr) {
        const key = `${c.parent ?? 'root'}::${nameStr.toLowerCase().trim()}`;
        catIndex.set(key, c.id);
      }
    }
    if (batch.length < 200) break;
  }

  saveCategoryCache(catIndex);
  console.log(`Total categorias indexadas na loja: ${catIndex.size}`);
  return catIndex;
}

function saveCategoryCache(catIndex) {
  const obj = Object.fromEntries(catIndex);
  fs.writeFileSync(CAT_CACHE_FILE, JSON.stringify(obj, null, 2), 'utf8');
}

async function ensureCategoryTree(api, catIndex, tree) {
  if (!tree || !tree.length) return { leafId: null };
  let parentId = null;

  for (const rawName of tree) {
    const name = rawName.trim();
    if (!name) continue;
    const key = `${parentId ?? 'root'}::${name.toLowerCase()}`;
    let catId = catIndex.get(key);

    if (!catId) {
      const body = { name: { pt: name } };
      if (parentId) body.parent = parentId;
      try {
        const created = await api.post('/categories', body);
        catId = created.id;
        catIndex.set(key, catId);
        saveCategoryCache(catIndex);
        console.log(`  📁 Categoria criada: "${name}" (ID: ${catId})`);
      } catch (err) {
        console.warn(`Aviso ao criar categoria "${name}":`, err.message);
        break;
      }
    }

    parentId = catId;
  }
  return { leafId: parentId };
}

function loadCheckpoint() {
  if (fs.existsSync(CHECKPOINT_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
    } catch { }
  }
  return {
    lastProcessedLine: 0,
    totalUploaded: 0,
    totalErrors: 0,
    syncedIds: {}
  };
}

function saveCheckpoint(cp) {
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(cp, null, 2), 'utf8');
}

async function uploadCatalog() {
  console.log('================================================================');
  console.log('🚀 INICIANDO CARGA EM MASSA NUVEMSHOP BASEADA NO CATÁLOGO EXCEL');
  console.log('================================================================\n');

  if (!fs.existsSync(MASTER_NDJSON)) {
    console.error(`Arquivo master não encontrado: ${MASTER_NDJSON}`);
    process.exit(1);
  }

  const api = new NuvemshopClient();
  const catIndex = await loadCategoryIndex(api);
  const checkpoint = loadCheckpoint();

  console.log(`📦 Status do Checkpoint: Linha ${checkpoint.lastProcessedLine} | Uploads: ${checkpoint.totalUploaded} | Erros: ${checkpoint.totalErrors}`);

  const fileStream = fs.createReadStream(MASTER_NDJSON, { encoding: 'utf8' });
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

  let lineIndex = 0;
  const t0 = Date.now();
  let uploadedInThisRun = 0;

  for await (const line of rl) {
    lineIndex++;

    if (lineIndex <= checkpoint.lastProcessedLine) {
      continue;
    }

    if (!line || !line.trim()) continue;

    let prod = null;
    try {
      prod = JSON.parse(line);
    } catch {
      continue;
    }

    if (checkpoint.syncedIds[prod.vtex_product_id]) {
      checkpoint.lastProcessedLine = lineIndex;
      continue;
    }

    // 1. Garante Categoria
    const { leafId } = await ensureCategoryTree(api, catIndex, prod.categoryPath);

    // 2. Monta Payload Oficial da Nuvemshop
    const payload = {
      name: { pt: prod.name },
      description: { pt: prod.description_html },
      seo_title: { pt: prod.seo_title },
      seo_description: { pt: prod.seo_description },
      brand: prod.brand,
      tags: prod.tags,
      categories: leafId ? [leafId] : [],
      visibility: 'visible',
      free_shipping: false,
      requires_shipping: true,
      variants: [
        {
          sku: String(prod.sku),
          mpn: prod.variant.mpn,
          barcode: prod.variant.barcode,
          price: prod.variant.price || '1.00',
          promotional_price: null,
          stock: 0,
          stock_management: true,
          weight: prod.variant.weight,
          width: prod.variant.width,
          height: prod.variant.height,
          depth: prod.variant.depth,
          visible: true
        }
      ],
      images: prod.images ? prod.images.slice(0, 8) : []
    };

    if (prod.handle) {
      payload.handle = { pt: prod.handle };
    }

    process.stdout.write(`[${lineIndex}] Enviando SKU ${prod.sku} (${prod.name.slice(0, 32)})... `);

    try {
      const res = await api.post('/products', payload);
      checkpoint.syncedIds[prod.vtex_product_id] = res.id;
      checkpoint.totalUploaded++;
      uploadedInThisRun++;
      checkpoint.lastProcessedLine = lineIndex;

      console.log(`OK (ID Nuvem: ${res.id} | Fotos: ${payload.images.length})`);

      if (uploadedInThisRun % 10 === 0) {
        saveCheckpoint(checkpoint);
        const elapsedMin = ((Date.now() - t0) / 60000).toFixed(1);
        const rate = (uploadedInThisRun / Math.max(1, (Date.now() - t0) / 1000)).toFixed(1);
        console.log(`\n📊 Progresso: ${checkpoint.totalUploaded} subidos | Vel: ${rate} prod/s | Tempo: ${elapsedMin} min`);
        await reportTelemetry(`Subidos ${checkpoint.totalUploaded} produtos`, checkpoint.totalUploaded, 173173);
      }
    } catch (err) {
      checkpoint.totalErrors++;
      checkpoint.lastProcessedLine = lineIndex;
      console.error(`ERRO: ${err.message}`);
      saveCheckpoint(checkpoint);
    }
  }

  saveCheckpoint(checkpoint);
  console.log('\n================================================================');
  console.log(`🎉 PROCESSO CONCLUÍDO!`);
  console.log(`Total subido: ${checkpoint.totalUploaded} | Erros: ${checkpoint.totalErrors}`);
  console.log('================================================================\n');
}

uploadCatalog().catch(console.error);
