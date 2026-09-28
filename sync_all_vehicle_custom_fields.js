const https = require('https');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

const HARVEST_FILE = path.join(__dirname, 'vtex_data', 'vtex_products_harvest.ndjson');
const MASTER_IN_STOCK_FILE = path.join(__dirname, 'produtos_master_in_stock.json');
const CHECKPOINT_FILE = path.join(__dirname, 'custom_fields_sync_checkpoint.json');

// IDs Oficiais dos Custom Fields na Nuvemshop
const P_CF_MONTADORA = '0cf47ff8c930edf7818fd7e8cb243b37';
const P_CF_MODELO = '015f3cfd10e8fe9250c21dd53d1b7e31';
const P_CF_ANO = '63fb3d90a11faafad54ae1cd6bd4dfb1';
const P_CF_VERSAO = '7f6129319b3dd92a3e7676dc4f4f4805';
const P_CF_APLICACAO = '8fb1e6f66842b63c06e6ea2bbe5bd9d8';

const V_CF_MONTADORA = '96bec8aa19cc3cf9a8b318aa6f2f48ac';
const V_CF_MODELO = '1dfaab7776dcfc6e55f1f53963fbf176';
const V_CF_ANO = 'e52db4cb7cdb08e3c311efa3015cfc46';
const V_CF_VERSAO = '4c297fee07521500b01b6c1a819b9bb0';

const KNOWN_MONTADORAS = [
  'VOLKSWAGEN', 'VW', 'CHEVROLET', 'GM', 'FIAT', 'FORD', 'TOYOTA', 'HONDA', 
  'HYUNDAI', 'RENAULT', 'NISSAN', 'PEUGEOT', 'CITROEN', 'JEEP', 'MITSUBISHI', 
  'MERCEDES-BENZ', 'MERCEDES', 'BMW', 'AUDI', 'VOLVO', 'KIA', 'CHERY', 'CAOA CHERY',
  'SUBARU', 'SUZUKI', 'LAND ROVER', 'TROLLER', 'DODGE', 'RAM', 'CHRYSLER', 'IVECO'
];

function cleanMontadora(raw) {
  if (!raw) return '';
  let str = String(raw).toUpperCase().replace(/\s+/g, ' ').trim();
  if (str.includes('VOLKSWAGEN') || str.includes('VW')) return 'VOLKSWAGEN';
  if (str.includes('CHEVROLET') || str.includes('GM')) return 'CHEVROLET';
  if (str.includes('MERCEDES')) return 'MERCEDES-BENZ';
  if (str.includes('LAND') && str.includes('ROVER')) return 'LAND ROVER';
  for (const m of KNOWN_MONTADORAS) {
    if (str.includes(m)) return m;
  }
  return str.split(',')[0].trim();
}

function expandYearRange(str) {
  if (!str) return [];
  const years = new Set();
  const regex4 = /\b(19\d{2}|20\d{2})\s*(?:a|até|-|\/)\s*(19\d{2}|20\d{2})\b/gi;
  let match;
  while ((match = regex4.exec(str)) !== null) {
    const y1 = parseInt(match[1]);
    const y2 = parseInt(match[2]);
    if (y1 <= y2 && (y2 - y1) <= 35) {
      for (let y = y1; y <= y2; y++) years.add(String(y));
    }
  }
  const regex2 = /\b(\d{2})\s*(?:a|até|-)\s*(\d{2})\b/gi;
  while ((match = regex2.exec(str)) !== null) {
    let y1 = parseInt(match[1]);
    let y2 = parseInt(match[2]);
    y1 = y1 > 50 ? 1900 + y1 : 2000 + y1;
    y2 = y2 > 50 ? 1900 + y2 : 2000 + y2;
    if (y1 <= y2 && (y2 - y1) <= 35) {
      for (let y = y1; y <= y2; y++) years.add(String(y));
    }
  }
  const regexSingle = /\b(19[7-9]\d|20[0-3]\d)\b/g;
  while ((match = regexSingle.exec(str)) !== null) {
    years.add(match[1]);
  }
  return Array.from(years).sort();
}

function cleanHtmlText(text) {
  if (!text) return '';
  return String(text)
    .replace(/<br\s*[\/]?>/gi, ' / ')
    .replace(/<\/p>/gi, ' / ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&eacute;/g, 'é')
    .replace(/&atilde;/g, 'ã')
    .replace(/&oacute;/g, 'ó')
    .replace(/&iacute;/g, 'í')
    .replace(/&uacute;/g, 'ú')
    .replace(/&ccedil;/g, 'ç')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/\s*\/\s*\/\s*/g, ' / ')
    .trim();
}

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
            'User-Agent': 'FortbrasCustomFieldsSync/2.0'
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

async function loadVtexSpecsIndex() {
  console.log('⚡ Carregando bases VTEX e indexando especificações veiculares (Montadora, Modelo, Ano, Versão, Aplicação)...');
  const t0 = Date.now();
  const map = new Map();

  // 1. Carrega produtos_master_in_stock.json se disponível
  if (fs.existsSync(MASTER_IN_STOCK_FILE)) {
    try {
      const pList = JSON.parse(fs.readFileSync(MASTER_IN_STOCK_FILE, 'utf8'));
      let mCount = 0;
      for (const p of pList) {
        const cf = p.custom_fields || {};
        const montadora = cleanMontadora(cf.montadora);
        const modelo = (cf.modelo || '').trim();
        const ano = (cf.ano || '').trim();
        const versao = (cf.versao || '').trim();
        const aplicacao = cleanHtmlText(cf.aplicacao).slice(0, 500);
        if (montadora || modelo || ano || versao || aplicacao) {
          const specData = { montadora, modelo, ano, versao, aplicacao };
          if (p.sku) map.set(p.sku.toUpperCase().trim(), specData);
          if (p.barcode) map.set(String(p.barcode).trim(), specData);
          if (p.vtex_product_id) map.set(String(p.vtex_product_id), specData);
          if (p.name) {
            const nameKey = p.name.trim().toLowerCase().slice(0, 45);
            if (!map.has(nameKey)) map.set(nameKey, specData);
          }
          mCount++;
        }
      }
      console.log(`📦 Carregados ${mCount} produtos enriquecidos de produtos_master_in_stock.json`);
    } catch(e) {
      console.warn('Aviso ao carregar produtos_master_in_stock.json:', e.message);
    }
  }

  // 2. Carrega vtex_products_harvest.ndjson
  if (fs.existsSync(HARVEST_FILE)) {
    const rl = readline.createInterface({ input: fs.createReadStream(HARVEST_FILE) });
    let count = 0;

    for await (const line of rl) {
      if (!line.trim()) continue;
      count++;
      const p = JSON.parse(line);

      const montadoraRaw = p['Montadora'] ? p['Montadora'].join(', ') : '';
      const montadora = cleanMontadora(montadoraRaw);
      
      let modelo = p['Modelo'] ? p['Modelo'].join(', ').trim() : '';
      if (!modelo && p['Modelo Any']) {
        modelo = p['Modelo Any'].join(', ').trim();
      }
      
      // Anos
      let anoStr = '';
      if (p['Ano'] && Array.isArray(p['Ano']) && p['Ano'].length > 0) {
        anoStr = p['Ano'].join(', ');
      } else if (p['Ano Inicial'] && p['Ano Final']) {
        const y1 = parseInt(Array.isArray(p['Ano Inicial']) ? p['Ano Inicial'][0] : p['Ano Inicial']);
        const y2 = parseInt(Array.isArray(p['Ano Final']) ? p['Ano Final'][0] : p['Ano Final']);
        if (y1 <= y2 && (y2 - y1) <= 35) {
          const arr = [];
          for (let y = y1; y <= y2; y++) arr.push(String(y));
          anoStr = arr.join(', ');
        }
      } else if (p.productName) {
        const exp = expandYearRange(p.productName);
        if (exp.length) anoStr = exp.join(', ');
      }

      // Versão / Motor
      let versao = '';
      if (p['Versão'] && Array.isArray(p['Versão']) && p['Versão'].length > 0) {
        versao = p['Versão'].slice(0, 4).join(', ');
      } else if (p['Motor'] && Array.isArray(p['Motor']) && p['Motor'].length > 0) {
        versao = p['Motor'].slice(0, 4).join(', ');
      }

      // Aplicação
      let aplicacao = '';
      if (p['Aplicação']) {
        const appRaw = Array.isArray(p['Aplicação']) ? p['Aplicação'].join(' ') : String(p['Aplicação']);
        aplicacao = cleanHtmlText(appRaw).slice(0, 500);
      } else if (p['Tipo de Aplicação']) {
        aplicacao = cleanHtmlText(String(p['Tipo de Aplicação'])).slice(0, 500);
      }

      const specData = { montadora, modelo, ano: anoStr, versao, aplicacao };

      for (const it of (p.items || [])) {
        if (it.itemId) map.set(String(it.itemId).toUpperCase().trim(), specData);
        if (it.ean) map.set(String(it.ean).trim(), specData);
        if (it.referenceId) {
          for (const r of it.referenceId) {
            if (r.Value) map.set(String(r.Value).toUpperCase().trim(), specData);
          }
        }
      }
      if (p.productId) map.set(String(p.productId), specData);
      if (p.productReference) map.set(String(p.productReference).toUpperCase().trim(), specData);
      if (p.productReferenceCode) map.set(String(p.productReferenceCode).toUpperCase().trim(), specData);
      if (p.productName) {
        const nameKey = p.productName.trim().toLowerCase().slice(0, 45);
        if (!map.has(nameKey)) map.set(nameKey, specData);
      }
    }
    console.log(`✅ Base VTEX indexada com sucesso: ${count} itens em ${((Date.now() - t0)/1000).toFixed(1)}s (Total chaves: ${map.size})\n`);
  } else {
    console.warn(`Arquivo ${HARVEST_FILE} não encontrado.`);
  }

  return map;
}

// Extrai montadora heurística a partir do nome se não encontrada na VTEX
function detectMontadoraFromName(name) {
  if (!name) return '';
  const up = name.toUpperCase();
  for (const m of KNOWN_MONTADORAS) {
    if (new RegExp(`\\b${m}\\b`, 'i').test(up)) {
      return m === 'VW' ? 'VOLKSWAGEN' : (m === 'GM' ? 'CHEVROLET' : m);
    }
  }
  return '';
}

async function runWorkerPool(items, concurrency, fn) {
  let index = 0;
  async function worker() {
    while (index < items.length) {
      const item = items[index++];
      try {
        await fn(item);
      } catch(e) {
        console.error('Worker error:', e.message);
      }
    }
  }
  const workers = [];
  for (let i = 0; i < concurrency; i++) workers.push(worker());
  await Promise.all(workers);
}

async function syncAllVehicleCustomFields() {
  console.log('================================================================');
  console.log('🚗 SINCRONIZAÇÃO EM MASSA DOS DADOS VEICULARES NA NUVEMSHOP');
  console.log('Campos: Montadora | Modelo | Ano | Versão | Aplicação');
  console.log('Regra: Atualizar EXCLUSIVAMENTE os Custom Fields (sem tocar em preço/estoque/tags)');
  console.log('================================================================\n');

  const vtexMap = await loadVtexSpecsIndex();

  let state = { lastPage: 1, totalProcessed: 0, totalUpdated: 0 };
  if (fs.existsSync(CHECKPOINT_FILE)) {
    try {
      state = JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
      console.log(`🔄 Retomando do checkpoint: Página ${state.lastPage} (Já atualizados: ${state.totalUpdated})...\n`);
    } catch(e) {}
  }

  let page = state.lastPage;
  const startTime = Date.now();

  while (true) {
    const res = await apiRequest('GET', `/v1/${STORE_ID}/products?per_page=100&page=${page}`);
    if (res.status !== 200 || !Array.isArray(res.data) || res.data.length === 0) {
      console.log(`Fim dos produtos na página ${page}.`);
      break;
    }

    const prods = res.data;
    state.totalProcessed += prods.length;
    const itemsToUpdate = [];

    for (const p of prods) {
      const v = (p.variants && p.variants[0]) || {};
      const sku = (v.sku || '').toUpperCase().trim();
      const barcode = (v.barcode || '').trim();
      const prodName = (p.name?.pt || '').trim();
      const normName = prodName.toLowerCase().slice(0, 45);

      // Localiza especificações no mapa VTEX (prioridade: código de barras/EAN -> SKU -> ID Nuvemshop -> Nome)
      let spec = (barcode ? vtexMap.get(barcode) : null) ||
                 (sku ? vtexMap.get(sku) : null) ||
                 vtexMap.get(String(p.id)) ||
                 vtexMap.get(normName) || null;

      // Heurística de complementação se não achou ou faltou campo
      let montadora = spec?.montadora || detectMontadoraFromName(prodName);
      let modelo = spec?.modelo || '';
      let ano = spec?.ano || '';
      let versao = spec?.versao || '';
      let aplicacao = spec?.aplicacao || '';

      if (!ano && prodName) {
        const exp = expandYearRange(prodName);
        if (exp.length) ano = exp.join(', ');
      }

      if (!aplicacao && (montadora || modelo)) {
        aplicacao = `${montadora} ${modelo} ${ano} ${versao}`.replace(/\s+/g, ' ').trim();
      }

      // Se temos pelo menos um dado relevante de veículo
      if (montadora || modelo || ano || versao || aplicacao) {
        itemsToUpdate.push({
          productId: p.id,
          variantId: v.id,
          sku: v.sku || '',
          name: prodName,
          montadora,
          modelo,
          ano,
          versao,
          aplicacao
        });
      }
    }

    let pageUpdated = 0;
    if (itemsToUpdate.length > 0) {
      await runWorkerPool(itemsToUpdate, 4, async (item) => {
        const prodValues = [];
        if (item.montadora) prodValues.push({ id: P_CF_MONTADORA, value: item.montadora });
        if (item.modelo) prodValues.push({ id: P_CF_MODELO, value: item.modelo });
        if (item.ano) prodValues.push({ id: P_CF_ANO, value: item.ano });
        if (item.versao) prodValues.push({ id: P_CF_VERSAO, value: item.versao.slice(0, 255) });
        if (item.aplicacao) prodValues.push({ id: P_CF_APLICACAO, value: item.aplicacao.slice(0, 500) });

        if (prodValues.length > 0) {
          await apiRequest('PUT', `/unstable/${STORE_ID}/products/${item.productId}/custom-fields/values`, {
            values: prodValues
          });
        }

        if (item.variantId) {
          const varValues = [];
          if (item.montadora) varValues.push({ id: V_CF_MONTADORA, value: item.montadora });
          if (item.modelo) varValues.push({ id: V_CF_MODELO, value: item.modelo });
          if (item.ano) varValues.push({ id: V_CF_ANO, value: item.ano });
          if (item.versao) varValues.push({ id: V_CF_VERSAO, value: item.versao.slice(0, 255) });

          if (varValues.length > 0) {
            await apiRequest('PUT', `/unstable/${STORE_ID}/products/variants/${item.variantId}/custom-fields/values`, {
              values: varValues
            });
          }
        }

        pageUpdated++;
        state.totalUpdated++;
        if (state.totalUpdated % 20 === 0) {
          console.log(`✅ [CF #${state.totalUpdated}] Prod ${item.productId} (${item.sku}): ${item.montadora} | ${item.modelo} | ${item.versao.slice(0, 25)}`);
        }
        await sleep(120);
      });

      console.log(`[Página ${page}] Produtos: ${prods.length} | Custom Fields atualizados nesta página: ${pageUpdated} | Total acumulado: ${state.totalUpdated}`);
    } else {
      console.log(`[Página ${page}] Produtos: ${prods.length} | Nenhum veículo correspondente.`);
    }

    state.lastPage = page + 1;
    fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(state, null, 2), 'utf8');

    page++;
    await sleep(200);
  }

  const durationMin = ((Date.now() - startTime) / 60000).toFixed(1);
  console.log('\n================================================================');
  console.log(`🎉 SINCRONIZAÇÃO DE DADOS VEICULARES FINALIZADA COM SUCESSO!`);
  console.log(`📦 Total de produtos processados: ${state.totalProcessed}`);
  console.log(`🚗 Total de produtos com Custom Fields enriquecidos: ${state.totalUpdated}`);
  console.log(`⏱️ Tempo total: ${durationMin} minutos`);
  console.log('================================================================\n');

  if (fs.existsSync(CHECKPOINT_FILE)) {
    fs.unlinkSync(CHECKPOINT_FILE);
  }
}

syncAllVehicleCustomFields().catch(console.error);
