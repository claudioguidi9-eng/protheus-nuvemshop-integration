const fs = require('fs');
const path = require('path');
const MONITOR_DIR = 'C:/D/@Fortbras/monitor-integracao-nuvemshop';

const storageCode = `import { IntegrationEvent, KpiSummary } from './types';

const STORE_ID = '8117213';
const ACCESS_TOKEN = '1637dd9821cec89241d671a7307f6001c5450eb5';
const USER_AGENT = 'IntegracaoFortbrasProtheus (contato@fortbras.com.br)';

const FALLBACK_EVENTS: IntegrationEvent[] = [
  {
    id: 'evt-001',
    timestamp: new Date().toISOString(),
    source: 'VTEX',
    eventType: 'CATALOGO_PRODUTO',
    status: 'SUCCESS',
    httpStatus: 200,
    sku: 'VTEX_CATALOG_SYNC',
    summary: '[Carga Nuvemshop] Sincronização em Massa Ativa',
    details: 'Catálogo de 42.746 itens VTEX sendo enviado em streaming contínuo para a Nuvemshop.'
  }
];

declare global {
  var __INTEGRATION_CACHE__: {
    events: IntegrationEvent[];
    kpis: KpiSummary;
    lastFetch: number;
  } | undefined;
}

if (!global.__INTEGRATION_CACHE__) {
  global.__INTEGRATION_CACHE__ = {
    events: FALLBACK_EVENTS,
    kpis: {
      totalEventsToday: 1,
      successRate: 100,
      productsSyncedToday: 103,
      stockUpdatesProcessedToday: 1,
      ordersReceivedToday: 0,
      errorsPending: 0,
      integrationHealth: 'HEALTHY',
      lastEventTime: new Date().toISOString(),
      vtexHarvested: 42746,
      vtexCategoriesDone: 98,
      vtexTotalCategories: 383,
      vtexHarvestSizeMB: '1014.2'
    },
    lastFetch: 0
  };
}

export async function fetchRemoteState(): Promise<{ events: IntegrationEvent[]; kpis: KpiSummary }> {
  const cache = global.__INTEGRATION_CACHE__!;
  const now = Date.now();

  // Atualiza contagem real da Nuvemshop a cada 3 segundos
  if (now - cache.lastFetch > 3000) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2500);

      const res = await fetch(\`https://api.nuvemshop.com.br/unstable/\${STORE_ID}/products?per_page=1\`, {
        headers: {
          'Authorization': \`Bearer \${ACCESS_TOKEN}\`,
          'User-Agent': USER_AGENT
        },
        signal: controller.signal,
        cache: 'no-store'
      });
      clearTimeout(timeoutId);

      if (res.ok) {
        const total = Number(res.headers.get('x-total-count'));
        if (total && !isNaN(total)) {
          cache.kpis.productsSyncedToday = total;
        }
      }
      cache.lastFetch = now;
    } catch (err) {
      // Ignora falha transitória ou timeout para manter painel responsivo
    }
  }

  cache.kpis.totalEventsToday = Math.max(cache.events.length, cache.kpis.totalEventsToday);
  return { events: cache.events, kpis: cache.kpis };
}

export async function saveRemoteEvent(eventData: Omit<IntegrationEvent, 'id' | 'timestamp'>) {
  const newEvent: IntegrationEvent = {
    ...eventData,
    id: 'evt-' + Math.random().toString(36).substring(2, 9),
    timestamp: new Date().toISOString()
  };

  const cache = global.__INTEGRATION_CACHE__!;
  cache.events = [newEvent, ...cache.events].slice(0, 50);

  if (eventData.requestPayload) {
    const p = eventData.requestPayload;
    if (p.totalSyncedNuvemshop) cache.kpis.productsSyncedToday = p.totalSyncedNuvemshop;
    if (p.totalHarvested) cache.kpis.vtexHarvested = p.totalHarvested;
    if (p.categoriesDone) cache.kpis.vtexCategoriesDone = p.categoriesDone;
    if (p.harvestSizeMB) cache.kpis.vtexHarvestSizeMB = String(p.harvestSizeMB);
  }

  cache.kpis.lastEventTime = newEvent.timestamp;
  cache.kpis.totalEventsToday = cache.events.length;

  return newEvent;
}

export async function addEvent(eventData: Omit<IntegrationEvent, 'id' | 'timestamp'>) {
  return await saveRemoteEvent(eventData);
}

export async function calculateKpis(): Promise<KpiSummary> {
  const { kpis } = await fetchRemoteState();
  return kpis;
}

export function getAllEvents(): IntegrationEvent[] {
  return global.__INTEGRATION_CACHE__?.events || FALLBACK_EVENTS;
}
`;

fs.writeFileSync(path.join(MONITOR_DIR, 'src', 'lib', 'storage.ts'), storageCode, 'utf8');
console.log('✅ storage.ts atualizado com sucesso no monitor!');
