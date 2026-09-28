const fs = require('fs');
const path = require('path');
const https = require('https');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

const CATALOG_FILE = path.join(__dirname, 'produtos_master_in_stock.json');
const CHECKPOINT_FILE = path.join(__dirname, 'nuvemshop_instock_sync_checkpoint.json');
const RULES_FILE = path.join(__dirname, 'nuvemshop_migration_rules_and_scripts.json');

const rules = JSON.parse(fs.readFileSync(RULES_FILE, 'utf8'));
const P_CF = rules.custom_fields.product_custom_fields.reduce((acc, f) => { acc[f.key] = f.id; return acc; }, {});
const V_CF = rules.custom_fields.variant_custom_fields.reduce((acc, f) => { acc[f.key] = f.id; return acc; }, {});

// Carrega checkpoint
let checkpoint = {};
if (fs.existsSync(CHECKPOINT_FILE)) {
  try {
    checkpoint = JSON.parse(fs.readFileSync(CHECKPOINT_FILE, 'utf8'));
  } catch(e) {
    checkpoint = {};
  }
}

function saveCheckpoint(sku, prodId) {
  checkpoint[sku] = prodId;
  fs.writeFileSync(CHECKPOINT_FILE, JSON.stringify(checkpoint, null, 2), 'utf8');
}

async function apiRequest(method, endpoint, body = null) {
  const dataStr = body ? JSON.stringify(body) : null;

  for (let attempt = 1; attempt <= 8; attempt++) {
    try {
      const res = await new Promise((resolve, reject) => {
        const req = https.request({
          hostname: 'api.nuvemshop.com.br',
          path: endpoint,
          method: method,
          headers: {
            'Authentication': 'bearer ' + ACCESS_TOKEN,
            'Content-Type': 'application/json',
            'Content-Length': dataStr ? Buffer.byteLength(dataStr) : 0,
            'User-Agent': 'FortbrasMigration/1.0'
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
        req.on('error', reject);
        if (dataStr) req.write(dataStr);
        req.end();
      });

      if (res.status === 429 || res.status >= 500) {
        const resetHeader = Number(res.headers['x-rate-limit-reset']) || 0;
        const wait = res.status === 429 ? Math.max(resetHeader * 1000, 2000 * attempt) : 1500 * attempt;
        process.stdout.write(` [RateLimit: aguardando ${(wait / 1000).toFixed(1)}s] `);
        await sleep(wait);
        continue;
      }

      return res;
    } catch (err) {
      if (attempt === 8) throw err;
      await sleep(1500 * attempt);
    }
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function runSync() {
  console.log('================================================================');
  console.log('🚀 SINCRONIZAÇÃO NUVEMSHOP - CATÁLOGO COM ESTOQUE (HIPERVAREJO)');
  console.log('================================================================\n');

  const products = JSON.parse(fs.readFileSync(CATALOG_FILE, 'utf8'));
  console.log(`Total de produtos no catálogo: ${products.length}`);
  console.log(`Já sincronizados no checkpoint: ${Object.keys(checkpoint).length}\n`);

  let count = 0;
  for (const item of products) {
    count++;
    if (checkpoint[item.sku]) {
      continue;
    }

    console.log(`[${count}/${products.length}] Enviando SKU: ${item.sku} - ${item.name.slice(0, 45)}...`);

    // REGRA DE OURO: Preço De (price) sempre >= Preço Por (promotional_price)
    const prNum = parseFloat(item.price) || 0;
    const promoNum = parseFloat(item.promotional_price) || 0;
    let finalPrice = item.price;
    let finalPromo = item.promotional_price;
    if (promoNum > 0 && promoNum > prNum) {
      finalPrice = promoNum.toFixed(2);
      finalPromo = prNum > 0 ? prNum.toFixed(2) : null;
    } else if (promoNum > 0 && promoNum === prNum) {
      finalPromo = null;
    }

    // Payload de criação do produto
    const payload = {
      name: { pt: item.name },
      description: { pt: item.description_html },
      brand: item.brand,
      tags: item.tags,
      images: item.images.slice(0, 8),
      variants: [
        {
          sku: item.sku,
          barcode: item.barcode,
          mpn: item.mpn,
          price: finalPrice,
          promotional_price: finalPromo,
          stock: item.stock,
          stock_management: true,
          weight: item.dimensions.weight,
          width: item.dimensions.width,
          height: item.dimensions.height,
          depth: item.dimensions.depth,
          visible: true
        }
      ]
    };

    try {
      const res = await apiRequest('POST', `/v1/${STORE_ID}/products`, payload);
      if (res.status === 201 && res.data?.id) {
        const prodId = res.data.id;
        const variantId = res.data.variants && res.data.variants[0] ? res.data.variants[0].id : null;
        console.log(`   -> Criado Produto ID: ${prodId} | Variante ID: ${variantId}`);

        // Custom Fields de Produto
        if (item.custom_fields) {
          const prodValues = [];
          if (item.custom_fields.montadora && P_CF['montadora']) prodValues.push({ id: P_CF['montadora'], value: item.custom_fields.montadora });
          if (item.custom_fields.modelo && P_CF['modelo']) prodValues.push({ id: P_CF['modelo'], value: item.custom_fields.modelo });
          if (item.custom_fields.ano && P_CF['ano']) prodValues.push({ id: P_CF['ano'], value: item.custom_fields.ano });
          if (item.custom_fields.versao && P_CF['verso']) prodValues.push({ id: P_CF['verso'], value: item.custom_fields.versao.slice(0, 255) });
          if (item.custom_fields.aplicacao && P_CF['aplicao']) prodValues.push({ id: P_CF['aplicao'], value: item.custom_fields.aplicacao.slice(0, 500) });

          if (prodValues.length > 0) {
            await apiRequest('PUT', `/unstable/${STORE_ID}/products/${prodId}/custom-fields/values`, { values: prodValues });
          }

          // Custom Fields de Variante
          if (variantId) {
            const varValues = [];
            if (item.custom_fields.montadora && V_CF['montadora']) varValues.push({ id: V_CF['montadora'], value: item.custom_fields.montadora });
            if (item.custom_fields.modelo && V_CF['modelo_do_veculo']) varValues.push({ id: V_CF['modelo_do_veculo'], value: item.custom_fields.modelo });
            if (item.custom_fields.ano && V_CF['ano']) varValues.push({ id: V_CF['ano'], value: item.custom_fields.ano });
            if (item.custom_fields.versao && V_CF['verso']) varValues.push({ id: V_CF['verso'], value: item.custom_fields.versao.slice(0, 255) });

            if (varValues.length > 0) {
              await apiRequest('PUT', `/unstable/${STORE_ID}/products/variants/${variantId}/custom-fields/values`, { values: varValues });
            }
          }
        }

        saveCheckpoint(item.sku, prodId);
      } else {
        console.error(`   ❌ Falha ao criar SKU ${item.sku}:`, res.status, res.data || res.raw);
      }
    } catch(err) {
      console.error(`   ❌ Erro de rede para SKU ${item.sku}:`, err.message);
    }

    await sleep(400); // Respeita limites de requisição da API
  }

  console.log('\n================================================================');
  console.log('🎉 MIGRAÇÃO CONCLUÍDA!');
  console.log('================================================================');
}

runSync().catch(console.error);
