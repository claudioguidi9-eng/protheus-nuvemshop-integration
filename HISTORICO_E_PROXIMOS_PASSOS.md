# HISTÓRICO DO PROJETO E ROTEIRO DE CONTINUIDADE
## Integração TOTVS Protheus x Nuvemshop (Fortbras)
**Data de Fechamento da Etapa:** 17/09/2026 - 13:00  
**Status Atual:** Piloto Ponta a Ponta Concluído com Sucesso Total (Itens 104319 e 1086666).  
Loja Nuvemshop Conectada (`demofortbras` / Store ID `8117213`).  
Pronto para execução do planejamento da migração em massa.

---

## 0. Resumo dos Testes Piloto Executados (17/09/2026)
1. **Loja Nuvemshop Oficial:** Store ID `8117213`, Token `44ffe7a14117c3bdde82906080a810f477c6368d`, User-Agent `VMS Services (dev@vmstech.co)`.
2. **Item Piloto 1 (104319 - Caixa Direção Hidráulica Palio Ampri):**
   - Extraído da VTEX e subido para a Nuvemshop (ID `367998241`).
   - Sincronização via Protheus (Opção 8) executada com sucesso, gravando de-para `VT9`/`VTD`.
3. **Item Piloto 2 (1086666 - Lâmpada Philips 24V H4 70W):**
   - Extraído da VTEX (Produto VTEX `312359`, 5 fotos HD, especificações completas) e publicado na Nuvemshop (ID `368046489`, Variante `1599018162`).
   - Sincronizado via Protheus (Opção 8): **Preço atualizado para R$ 21,60** e **Estoque atualizado para 9.128 un**!
4. **Correção de Código de Barras (EAN) e Categorias (17/09/2026 - Tarde):**
   - **Diagnóstico do Código de Barras:** O script de migração dependia unicamente da especificação `"Código de barras (EAN)"` na SKU. No Protheus, o EAN reside em `SB1->B1_CODBAR` ou `SB1->B1_EAN13`, que não estavam mapeados em `GetDadosProd` nem propagados na montagem do JSON da variante.
   - **Diagnóstico das Categorias:** Para itens como o `1086666`, o campo `sku.CategoriesFullPath` vinha indefinido na VTEX, fazendo com que o gerador de árvore retornasse vazio sem avaliar os caminhos alternativos (`product.categories` e `sku.ProductCategoryIds`). Além disso, a API da Nuvemshop vincula a árvore inteira automaticamente quando recebe o ID da **categoria folha** (mais profunda).
   - **Atualização em Produção Nuvemshop:**
     - **Item 1086666 (ID 368046489):** Código de barras **`8719018002884`** gravado na variante `1599018162`. Árvore de categorias criada e vinculada: `Farol e Iluminação` > `Lâmpadas` > `Lâmpada Originais` (ID `41049317`).
     - **Item 104319 (ID 367998241):** Código de barras **`7898906453425`** gravado na variante `1598868932`. Categorias vinculadas: `Autopeças` > `Direção` > `Caixa de Direção` (ID `41034735`).
   - **Fontes Atualizados de Forma Definitiva:**
     - `migracao_scripts/Product/script.js`: Implementado fallback multicamada para EAN e categorias, além de auto-update retroativo para produtos existentes na loja.
     - `NuvemProduto.prw`: Adicionada leitura de `B1_CODBAR` / `B1_EAN13` no Protheus e envio obrigatório de `barcode` tanto em `ExportProduct` quanto em `SyncStockPrice`. Sincronizado também em `Fontes/NuvemProduto.prw`.
5. **Estratégia de Migração em Massa Definida para Decisão:**
   - **Regra de Ouro Antirruptura:** Catálogo VTEX sobe com estoque zero / oculto por padrão (apenas enriquecimento estético de fotos e fichas técnicas).
   - **Canetada Comercial do Protheus:** Protheus roda `SyncAllStockPriceB2C` e só ativa e disponibiliza para venda os itens com saldo e preço reais no ERP.

---

## 1. O que foi Concluído até o Momento

### 1.1 Análise e Validação dos Dados
- Analisados os **10 produtos piloto** extraídos da VTEX Fortbras (`C:\D\@Fortbras\API PRODUTO\catalog\catalog`):
  - SKUs/Produtos: `340684`, `104319`, `194862`, `211603`, `221804`, `250684`, `328788`, `357115`, `9529680`, `9536725`.
- Mapeadas as regras da documentação técnica e requisitos da API Nuvemshop:
  - **API:** Versão `unstable` (`https://api.nuvemshop.com.br/unstable/8117213`)
  - **Header Obrigatório:** `User-Agent: VMS Services (dev@vmstech.co)` (previne HTTP 400).
  - **Autenticação:** Bearer Token permanente via parâmetro `MV_NUVTOK`.
  - **Rate Limit:** Algoritmo Leaky Bucket com captura de `x-rate-limit-reset` e retry automático com pausa (`Sleep`).
  - **Busca por Placa:** Custom Fields gravados na **Variante** (`/variants/{id}/custom-fields`) sob o namespace `demofortbras` (`montadora`, `modelo`, `ano`, `versao`, `aplicacao`, `part_number`).
  - **Carga de Estoque e Preço em Lote:** `PATCH /products/stock-price` (blocos de até 50 itens).
  - **Idempotência por SKU:** `GET /products/sku/{sku}` antes da criação.
  - **De-Para no ERP:** Persistência em tabelas padrão `VT9` (Produto) e `VTD` (Variante).

---

## 2. Mapa dos Fontes Desenvolvidos e Prontos

Todos os fontes estão sincronizados nas pastas:
- **Pasta de Compilação do Protheus:** `c:\D\@Fortbras\Fontes\`
- **Pasta do Projeto:** `C:\D\@Fortbras\projeto nuvemshop\IntegracaoNuvemShop\`

| Arquivo | Descrição / Função Principal |
| :--- | :--- |
| **`NuvemAcesso.prw`** | Cliente HTTP REST, cabeçalhos obrigatórios, Bearer token e controle de Rate Limit. |
| **`NuvemProduto.prw`** | Motor de catálogo: leitura de `SB1`/`SB5`/`SZ1`/`Z08`/`Z09`/`ECOMMERCE_PRODWEB`, criação, fotos, custom fields e envio em lote. |
| **`NuvTestCatalog.prw`** | Rotina interativa SmartClient (`U_NuvTestCatalog`) com 4 opções de teste, consulta de SKU e exportação piloto. |
| **`U_TestNuvCon.prw`** | Rotina de teste rápido de conectividade e validação do token (`U_TestNuvCon`). |
| **`ECJOBNUV.prw`** | Job agendado (Schedule) para processar fila de produtos (`VTF`) e pedidos em segundo plano. |
| **`NuvemPedido.prw`** | Rotina de sincronização e importação de pedidos de venda da Nuvemshop para o ERP (`SC5`/`SC6`). |

---

## 3. Documentações Geradas no Projeto

1. **PDF Oficial Completo (315 KB):**
   - `C:\D\@Fortbras\Documentacao_Integracao_Protheus_Nuvemshop_Fortbras.pdf`
   - `C:\D\@Fortbras\projeto nuvemshop\IntegracaoNuvemShop\Documentacao_Integracao_Protheus_Nuvemshop_Fortbras.pdf`
2. **Guia de Implementação e Contratos da API:**
   - `C:\D\@Fortbras\projeto nuvemshop\IntegracaoNuvemShop\Guia_Implementacao_Nuvemshop_Fortbras.md`
3. **Mapeamento de Pontos de Plugagem com o Legado:**
   - `C:\D\@Fortbras\projeto nuvemshop\IntegracaoNuvemShop\Pontos_De_Plugagem_Fontes_Existentes.md`

---

## 4. Roteiro para Começar Hoje à Noite (Passo a Passo)

Assim que retomar o trabalho hoje à noite, siga estes 4 passos:

### Passo 1: Informar o Token do Cliente
Cadastre o token permanente no parâmetro do Protheus:
- No **SIGACFG**: Parâmetro `MV_NUVTOK` (Tipo: Caractere, Tamanho: 250).
- Ou me passe o token aqui no chat que eu preparo a inclusão direta.

### Passo 2: Compilar os Fontes
Compile os 6 arquivos de `c:\D\@Fortbras\Fontes\` no TDS / VS Code.

### Passo 3: Testar Conexão Imediata
No SmartClient, execute:
```
U_TestNuvCon
```
> Deverá retornar **`HTTP 200 OK`**.

### Passo 4: Rodar o Teste de Homologação
No SmartClient, execute:
```
U_NuvTestCatalog
```
- **Opção 1:** Digite o SKU piloto `340684` para ver os dados retornando da Nuvemshop.
- **Opção 2:** Digite o produto `104319` para ver os dados automotivos locais do Protheus (`Z08`/`Z09`).
- **Opção 3:** Exporte um produto teste piloto da Fortbras para a Nuvemshop (com validação de `SBZ->BZ_YB2C`).
- **Opção 4:** Processe a fila `VTF`.
- **Opção 5:** Enfileire produto na VTF para simular alteração de estoque/preço.
- **Opção 6:** Dispare um evento de teste direto para a Torre de Controle (Monitor Web).
- **Opção 7:** **Carga Total de Produtos B2C (`SBZ->BZ_YB2C = 'S'`):** Consulta em lote os produtos aprovados na filial configurada em `MV_NUVFIL` e envia o catálogo completo para a Nuvemshop com régua de progresso e relatório final.

---

### 1.2 Regra de Negócio de Seleção B2C (SBZ)
- **Tabela de Controle:** `SBZ010` (Indicadores de Produtos por Filial).
- **Campo de Elegibilidade:** `BZ_YB2C` (`S` = Sim, exporta para Nuvemshop; `N` = Não, desconsidera).
- **Filial de Consulta:** Parâmetro `MV_NUVFIL` (ex: `03150001` / `0315`).
- **Bloqueio:** Desconsidera produtos com `SB1->B1_MSBLQL == '1'`.
- **Rotinas Atualizadas:**
  - `NuvemProduto.prw`: método `ExportAllB2C(cFilialP, bProgress)`, validação em `ExportProduct()` e cadastro automático na fila `VTF` em `UpdtAtuWeb()`.
  - `NuvTestCatalog.prw`: Opção 7 para execução assistida e visualização do status B2C nas opções 2 e 3.
  - `ECJOBNUV.prw`: Suporte a sincronização agendada contínua via `JOB_NUVCAT`.

## 5. Torre de Controle / Painel Web em Tempo Real

Foi desenvolvido um **Monitor Operacional Executivo** moderno (Next.js 16 + React 19 + Tailwind CSS) para acompanhamento em tempo real de todas as transações, estoques, pedidos e alertas da integração:

- **Local do Projeto:** `C:\D\@Fortbras\monitor-integracao-nuvemshop`
- **Atalho de 1-Clique para Iniciar:** [`Iniciar_Painel_Monitor.bat`](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/Iniciar_Painel_Monitor.bat)
  - Abre o servidor e carrega o painel no seu navegador (`http://localhost:3000`).
- **Deploy Oficial em Produção (Vercel):**
  - **Painel no Navegador:** [https://toat-fortbras.vercel.app](https://toat-fortbras.vercel.app)
  - **Endpoint da API para o ERP:** `https://toat-fortbras.vercel.app/api/events`
- **Atalho Local (Opcional):** [`Iniciar_Painel_Monitor.bat`](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/Iniciar_Painel_Monitor.bat) (`http://localhost:3000`).
- **Cadastro do Parâmetro no Protheus (SIGACFG):**
  - **Parâmetro:** `MV_XURLMON`
  - **Tipo:** `Caractere` (Tamanho: `250`)
  - **Conteúdo:** `https://toat-fortbras.vercel.app/api/events`
  - O método `SendMonitor` no `NuvemAcesso.prw` transmite os logs e latências automaticamente de forma não bloqueante.

---

## 6. Mapeamento de Filiais do Espírito Santo & Padronização de SKUs

### 6.1 Filiais do Espírito Santo (ES)
- **`04160001` (Bandeira 0416):** CD Central de Cariacica/ES e Filial Mãe de Cadastro de Produtos (conforme rotinas legadas `VIXA408.tlpp` e `VIXA039.prw`). Onde reside o estoque físico principal.
- **`03150001` (Bandeira 0315):** Filial Jurídica de Faturamento B2C / HiperVarejo (conforme `VIXA356.prw`, `vixa405.tlpp` e `PaymentsTrackCash.prw`).
- **Suporte Multi-Filial Implementado:** Todas as consultas de estoque (`ECOMMERCE_PRODWEB` e `SB2`), preço (`DA1`), indicadores B2C (`SBZ`) e esteira de pedidos (`VT1`) agora filtram de forma unificada e transparente ambas as filiais (`03150001` e `04160001`).

### 6.2 Padronização de SKUs vs IDs Legados VTEX
- **Problema Identificado:** Produtos migrados de kits ou cadastrados na VTEX anteriormente possuíam o ID interno numérico da VTEX (`product.Id`, ex: `9536725` e `9529680`) gravados como SKU da variante na Nuvemshop, enquanto o código real do Protheus estava no MPN / Fabricante (`1611906` e `1627278`).
- **Ações Realizadas:**
  1. **API Nuvemshop:** Os 10 produtos piloto na loja `8117213` foram saneados via API, garantindo que o `variant.sku` seja rigorosamente o `B1_COD` Protheus.
  2. **Script de Migração ([script.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/migracao_scripts/Product/script.js)):** Lógica ajustada para priorizar `RefId`, `ManufacturerCode` e especificações técnicas de código de fabricante antes de recorrer a IDs de plataforma.
  3. **Rotinas AdvPL ([NuvemProduto.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvemProduto.prw), [NuvTestCatalog.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvTestCatalog.prw), [NuvemPedido.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvemPedido.prw)):** Sincronizadas entre o repositório de integração e a pasta central de Fontes da Fortbras.

---

## 7. Carga em Massa - Filial 0315 / HiperVarejo com Dados Ricos VTEX (22/09/2026)

### 7.1 Limpeza Prévia (Reset Total da Loja de Teste)
- Executado reset completo da loja Nuvemshop (`demofortbras` / Store ID `8117213`):
  - 10 produtos piloto anteriores apagados.
  - 118 valores de campos customizados removidos.
  - 43 definições de campos customizados limpos.
  - 235 custom objects excluídos.
  - 0 erros durante a higienização.

### 7.2 Cruzamento CSV SB2 (Filial 0315) x Catálogo VTEX
- **Origem dos Dados:** Extração real da tabela de saldos em estoque `SB2` da filial `03150001` (201 registros, 193 produtos únicos).
- **Varredura no Catálogo VTEX:**
  - Consulta automática à API pública de catálogo VTEX (`/api/catalog_system/pub/products/search`) usando o `Cd Comercial` (Código de Fabricante) e descrição.
  - **178 de 193 produtos (92.2%)** localizados com fotos de estúdio em alta resolução, ficha técnica, marcas e especificações.

### 7.3 Mapeamento Estratégico de Campos
| Campo Nuvemshop | Origem | Exemplo Real | Função Estratégica |
| :--- | :--- | :--- | :--- |
| **`variant.sku`** | `csv.produto` (`B1_COD` Protheus) | `0639730` | **Chave Primária de Integração com o ERP.** Utilizada pelo Protheus para atualizar estoque e preço em lote via `U_NuvTestCatalog` / `NuvemProduto.prw`. |
| **`variant.mpn`** | `csv.cd_comercial` (`Cd Comercial`) | `F000KE0P07` | **Part Number / Fabricante.** Permite que clientes e mecânicos busquem a peça no e-commerce pelo código de fábrica. |
| **`variant.stock`** | `csv.saldo_atual` (`SB2` somado) | `4` | Saldo inicial real em estoque na filial 0315. |
| **`name` / `images` / `brand`** | Catálogo VTEX | Pneus Continental, Velas Bosch, etc. | Apelo visual rico, fotos HD e ficha técnica completa. |

### 7.4 Resultados da Carga
- **Total de Produtos Criados:** 178 produtos (100% de sucesso, 0 erros).
- **Histórico e Ledger de IDs:** Salvos em [`scratch_import_results.json`](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/scratch_import_results.json).

---

## 8. Atualização e Conclusão das Correções em Massa (28/09/2026)

### 8.1 Resultados Operacionais da Loja (22.133 Produtos Auditados)
1. **Preços Invertidos:**
   - 4.781 produtos com preço promocional maior que o preço cheio foram corrigidos via script `fix_all_inverted_prices_on_store.js`.
2. **Categorias Limpas:**
   - Eliminadas todas as categorias em branco/vazias.
   - Estrutura consolidada em 3 níveis hierárquicos vinculando sempre a categoria folha (`step1_sync_categories.js`).
3. **Estoque e SKU:**
   - Variantes duplicadas corrigidas e quantidades alinhadas com o saldo físico da filial `03150001` (ex: Bronzina Casquilho Biela Fox 1.0 STD ajustada com 47 unidades no SKU `317555`).
4. **Campos Veiculares Oficiais (Custom Fields Nuvemshop):**
   - 21.913 produtos enriquecidos com `Montadora`, `Modelo`, `Ano`, `Versão` e `Aplicação` nos Custom Fields oficiais da Nuvemshop (`sync_all_vehicle_custom_fields.js`).
5. **Palavras-chave SEO / Tags (Palavras Similares VTEX):**
   - Localizada a Coluna 20 (`Palavras similares`) da planilha oficial de catálogo da VTEX.
   - Indexados 149.525 produtos no arquivo `vtex_tags_index.ndjson` (`build_vtex_tags_ndjson.js`).
   - Sincronização em massa das Tags da Nuvemshop realizada via `sync_all_vtex_tags.js`.
6. **Central de Carga e Manual de Operação:**
   - Documento completo gravado em [`MANUAL_CARGA_E_SINCRONIZACAO_PRODUTOS.md`](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/MANUAL_CARGA_E_SINCRONIZACAO_PRODUTOS.md).
   - Menu batch interativo disponível em [`Executar_Carga_Novos_Produtos.bat`](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/Executar_Carga_Novos_Produtos.bat).


