const https = require('https');
const fs = require('fs');
const path = require('path');

const STORE_ID = '8117213';
const TOKEN_FILE = path.join(__dirname, 'migracao_scripts', 'Product', 'Nuvemshop', 'Token,json');
const tokenData = JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8'));
const ACCESS_TOKEN = tokenData.access_token;

function apiRequest(method, endpoint, body = null, retries = 3) {
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
        'User-Agent': 'FortbrasPriceAudit/1.0'
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
    req.on('error', () => resolve({ status: 500 }));
    if (dataStr) req.write(dataStr);
    req.end();
  });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function runPriceAudit() {
  console.log('================================================================');
  console.log('🔍 AUDITORIA E CORREÇÃO DE PREÇOS INVERTIDOS EM TODA A NUVEMSHOP');
  console.log('Regra: Preço Normal (De:) = Maior valor | Preço Promocional (Por:) = Menor valor');
  console.log('================================================================\n');

  // Descobre total de páginas
  const firstRes = await apiRequest('GET', `/v1/${STORE_ID}/products?per_page=100&page=1`);
  const link = firstRes.headers['link'] || '';
  const lastMatch = link.match(/page=(\d+)>;\s*rel="last"/);
  const totalPages = lastMatch ? parseInt(lastMatch[1]) : 222;

  console.log(`Total de páginas a auditar: ${totalPages} páginas.`);

  let totalAudited = 0;
  let totalFixed = 0;

  for (let page = 1; page <= totalPages; page++) {
    const res = await apiRequest('GET', `/v1/${STORE_ID}/products?per_page=100&page=${page}`);
    if (res.status !== 200 || !Array.isArray(res.data) || res.data.length === 0) {
      continue;
    }

    const prods = res.data;
    totalAudited += prods.length;
    let pageFixed = 0;

    for (const p of prods) {
      if (!p.variants || p.variants.length === 0) continue;
      for (const v of p.variants) {
        const pr = parseFloat(v.price) || 0;
        const promo = parseFloat(v.promotional_price) || 0;

        // Se preço promocional for maior que preço normal (INVERSÃO GRAVE)
        if (promo > 0 && promo > pr) {
          const correctPrice = promo.toFixed(2);
          const correctPromo = pr > 0 ? pr.toFixed(2) : null;

          const upRes = await apiRequest('PUT', `/v1/${STORE_ID}/products/${p.id}/variants/${v.id}`, {
            price: correctPrice,
            compare_at_price: correctPrice,
            promotional_price: correctPromo
          });

          if (upRes.status === 200) {
            totalFixed++;
            pageFixed++;
            console.log(`✅ [Corrigido Inversão] Produto ${p.id} (${v.sku || p.name?.pt?.slice(0, 30)}): De R$ ${correctPrice} por R$ ${correctPromo}`);
          }
          await sleep(150);
        } else if (promo > 0 && promo === pr) {
          // Se promo for idêntico ao normal, remove o promo desnecessário
          const upRes = await apiRequest('PUT', `/v1/${STORE_ID}/products/${p.id}/variants/${v.id}`, {
            promotional_price: null
          });
          if (upRes.status === 200) {
            totalFixed++;
            pageFixed++;
            console.log(`✅ [Ajustado Duplicado] Produto ${p.id}: Removido desconto igual ao preço normal (R$ ${pr})`);
          }
          await sleep(150);
        }
      }
    }

    if (pageFixed > 0 || page % 20 === 0 || page === totalPages) {
      console.log(`[Página ${page}/${totalPages}] Auditados: ${totalAudited} | Corrigidos nesta página: ${pageFixed} | Total corrigidos: ${totalFixed}`);
    }

    await sleep(80);
  }

  console.log('\n================================================================');
  console.log(`🎉 AUDITORIA E CORREÇÃO DE PREÇOS CONCLUÍDA COM SUCESSO!`);
  console.log(`📦 Total de produtos auditados: ${totalAudited}`);
  console.log(`💰 Total de preços invertidos corrigidos: ${totalFixed}`);
  console.log('================================================================\n');
}

runPriceAudit().catch(console.error);
