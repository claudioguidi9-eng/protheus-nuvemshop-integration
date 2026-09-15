# HISTÓRICO DO PROJETO E ROTEIRO DE CONTINUIDADE
## Integração TOTVS Protheus x Nuvemshop (Fortbras)
**Data de Fechamento da Etapa:** 10/09/2026 - 17:30  
**Status Atual:** Fase de Desenvolvimento e Arquitetura 100% Concluída. Pronto para Execução e Testes com Token.

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

