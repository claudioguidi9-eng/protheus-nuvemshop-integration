const https = require('https');

const options = {
  hostname: 'api.nuvemshop.com.br',
  path: '/v1/8117213/orders?status=any&per_page=10',
  method: 'GET',
  headers: {
    'Authentication': 'bearer 1637dd9821cec89241d671a7307f6001c5450eb5',
    'User-Agent': 'VMS Services (dev@vmstech.co)'
  }
};

const req = https.request(options, res => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('STATUS:', res.statusCode);
    try {
      const parsed = JSON.parse(data);
      console.log('TOTAL ORDERS FOUND:', parsed.length);
      parsed.forEach(o => {
        console.log('-----------------------------------------');
        console.log('ID:', o.id);
        console.log('Order Number:', o.number);
        console.log('Status:', o.status);
        console.log('Payment Status:', o.payment_status);
        console.log('Created At:', o.created_at);
        console.log('Updated At:', o.updated_at);
        console.log('Total:', o.total);
        console.log('Customer:', o.customer ? (o.customer.name + ' | ' + o.customer.email + ' | ' + o.customer.identification) : 'N/A');
        console.log('Products:', (o.products || []).map(p => `${p.name} (SKU: ${p.sku}, Qtd: ${p.quantity}, Price: ${p.price})`).join('; '));
      });
      if (parsed.length > 0) {
        require('fs').writeFileSync('pedido_teste_completo.json', JSON.stringify(parsed[0], null, 2));
        console.log('\nSalvo payload completo em pedido_teste_completo.json');
      }
    } catch(e) {
      console.log('RAW BODY:', data);
    }
  });
});

req.on('error', err => console.error(err));
req.end();
