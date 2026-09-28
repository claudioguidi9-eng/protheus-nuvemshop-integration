# MANUAL DE OPERAÇÃO: CARGA E SINCRONIZAÇÃO DE PRODUTOS
## Integração TOTVS Protheus x Nuvemshop (Fortbras / Hipervarejo)
**Versão:** 2.0  
**Data da Documentação:** 28/09/2026  
**Ambiente Nuvemshop:** Loja `8117213` (demofortbras)  
**Ambiente ERP:** TOTVS Protheus 12 (Filial E-commerce: `03150001` - Vitória/ES)

---

## 1. Visão Geral da Arquitetura

O ecossistema de produtos da Nuvemshop está 100% alinhado com as regras de negócio automotivas da Fortbras. Quando novos produtos forem adicionados ao portfólio ou precisarem subir para a loja, eles devem respeitar os seguintes padrões consolidados:

| Campo / Dimensão | Regra de Negócio | Origem dos Dados |
| :--- | :--- | :--- |
| **Código SKU** | Código do SKU Protheus / Fabricante | Protheus (`SB1->B1_COD`) ou VTEX SKU ID |
| **Código de Barras (EAN)** | 13 dígitos numéricos válidos | Protheus (`SB1->B1_CODBAR` / `B1_EAN13`) ou VTEX EAN |
| **Preço De / Por** | Preço cheio (`price`) SEMPRE maior que promocional (`promotional_price`). Nunca invertido. | Protheus (`DA1` / Tabela B2C) ou VTEX ListPrice |
| **Estoque Físico** | Saldo disponível da filial de e-commerce (`03150001`), subtraindo empenhos. | Protheus (`SB2` / `SBZ` com `BZ_YB2C = 'S'`) |
| **Categorias** | Árvore de 3 níveis (`Departamento > Categoria > Subcategoria`) vinculando a categoria folha. Zero linhas em branco. | Catálogo VTEX / Nuvemshop Category Tree |
| **Dados Veiculares (Custom Fields)** | Gravados nos campos personalizados da Nuvemshop: `Montadora`, `Modelo`, `Ano`, `Versão`, `Aplicação`. | Ficha Técnica VTEX / Protheus `ECOMMERCE_PRODWEB` |
| **SEO e Busca (Tags)** | Palavras-chave de busca na loja, correspondendo exatamente às **Palavras Similares** da VTEX. | Planilha VTEX (Coluna 20: `Palavras similares`) |
| **Dimensões & Peso** | Peso em kg, Comprimento, Altura e Largura em cm para cálculo de frete nos Correios/Transportadoras. | VTEX Package Dimensions / Protheus `SB5` |

---

## 2. IDs Oficiais dos Custom Fields Veiculares na Nuvemshop

Ao enviar campos veiculares para a Nuvemshop, os seguintes IDs de Custom Fields foram homologados e estão cadastrados:

### No Nível do Produto (`/v1/{store_id}/products/{product_id}/custom-fields`):
* **Montadora:** `0cf47ff8c930edf7818fd7e8cb243b37`
* **Modelo:** `015f3cfd10e8fe9250c21dd53d1b7e31`
* **Ano:** `63fb3d90a11faafad54ae1cd6bd4dfb1`
* **Versão:** `7f6129319b3dd92a3e7676dc4f4f4805`
* **Aplicação:** `8fb1e6f66842b63c06e6ea2bbe5bd9d8`

### No Nível da Variante (`/v1/{store_id}/products/{product_id}/variants/{variant_id}/custom-fields`):
* **Montadora:** `96bec8aa19cc3cf9a8b318aa6f2f48ac`
* **Modelo:** `1dfaab7776dcfc6e55f1f53963fbf176`
* **Ano:** `e52db4cb7cdb08e3c311efa3015cfc46`
* **Versão:** `4c297fee07521500b01b6c1a819b9bb0`

---

## 3. Roteiro Prático: Como Subir Novos Produtos

Existem duas formas seguras e independentes de subir novos produtos para a Nuvemshop:

---

### MÉTODO A: Diretamente pelo Protheus (Nativo AdvPL)

Utilize este método para produtos normais do dia a dia cadastrados no ERP.

1. **Acessar a Rotina de Catálogo:**
   No Protheus SmartClient, digite na linha de comando:
   ```
   U_NuvTestCatalog
   ```

2. **Opções Disponíveis no Menu:**
   * **Opção 1 - Consultar SKU:** Permite verificar se o SKU já existe na Nuvemshop e conferir seu ID, preço e saldo.
   * **Opção 3 - Exportar Produto Completo (Piloto):** Envia o produto completo (criação do zero), incluindo nome, descrição, fotos, categorias, preço, estoque e peso.
   * **Opção 7 - Carga Total de Produtos B2C:** Varre todos os produtos da filial `03150001` onde `SBZ->BZ_YB2C = 'S'` e envia para a Nuvemshop.
   * **Opção 8 - Sincronizar Estoque/Preço por SKU (Match VTEX):** Localiza o produto na Nuvemshop e atualiza apenas o estoque e preço da filial com rapidez.
   * **Opção 9 - Sincronização em Lote Estoque/Preço B2C:** Roda a atualização de estoque e preço para toda a lista B2C da filial.

3. **Automação Contínua (Schedule Protheus):**
   O job `ECJOBNUV` processa automaticamente as alterações gravadas na tabela de fila `VTF` (onde `VTF_ATUWEB = 'S'` e `VTF_API = 'NUVEMSHOP'`).

---

### MÉTODO B: Carga e Enriquecimento em Massa via Scripts Node.js

Utilize este método se você exportar uma nova planilha de produtos da VTEX ou gerar um novo lote JSON de produtos para carregar em massa na Nuvemshop.

Os scripts ficam localizados na pasta:
`C:\D\@Fortbras\projeto nuvemshop\IntegracaoNuvemShop\`

#### Passo 1: Subir ou Atualizar Produtos Base (Imagens, Preços, Estoque)
Se tiver uma lista JSON de novos produtos (ex: `produtos_master_in_stock.json`):
```bash
node sync_in_stock_to_nuvemshop.js
```
*O script faz a carga com idempotência por SKU, criando novos produtos e atualizando existentes.*

#### Passo 2: Garantir Categorias Limpas (Sem Linhas em Branco)
```bash
node step1_sync_categories.js
```
*Cria a hierarquia correta (`Departamento > Categoria > Subcategoria`) e remove categorias vazias ou corrompidas.*

#### Passo 3: Enriquecer Dados Veiculares (Montadora, Modelo, Ano, Versão, Aplicação)
```bash
node sync_all_vehicle_custom_fields.js
```
*Lê os dados técnicos veiculares e injeta os Custom Fields oficiais na Nuvemshop.*

#### Passo 4: Atualizar Tags de Busca com as "Palavras Similares" da VTEX
```bash
# Caso tenha uma nova planilha VTEX, gere o índice primeiro:
node build_vtex_tags_ndjson.js

# Em seguida, aplique as Tags na Nuvemshop:
node sync_all_vtex_tags.js
```
*Atualiza apenas o campo `tags` com as palavras-chave reais da VTEX (100% de precisão por SKU/EAN).*

#### Passo 5: Validar e Corrigir Preços Invertidos
```bash
node fix_all_inverted_prices_on_store.js
```
*Varre a loja e corrige qualquer inversão entre `price` e `promotional_price`.*

---

## 4. Arquivos e Scripts Chave Guardados no Projeto

| Arquivo / Script | Função e Responsabilidade |
| :--- | :--- |
| [sync_all_vtex_tags.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/sync_all_vtex_tags.js) | Sincroniza em massa as Palavras Similares da VTEX para as Tags Nuvemshop. |
| [build_vtex_tags_ndjson.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/build_vtex_tags_ndjson.js) | Extrai a Coluna 20 da planilha VTEX em stream (185k linhas em 10 segundos). |
| [vtex_tags_index.ndjson](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/vtex_tags_index.ndjson) | Base indexada pré-compilada com 149.525 produtos e suas palavras similares. |
| [sync_all_vehicle_custom_fields.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/sync_all_vehicle_custom_fields.js) | Enriquecimento em massa de Montadora, Modelo, Ano, Versão e Aplicação. |
| [step1_sync_categories.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/step1_sync_categories.js) | Criação da hierarquia de categorias e higienização de brancos. |
| [fix_all_inverted_prices_on_store.js](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/fix_all_inverted_prices_on_store.js) | Auditoria e correção de preços promocionais maiores que preço cheio. |
| [NuvTestCatalog.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvTestCatalog.prw) | Painel SmartClient AdvPL para operações manuais e testes de catálogo. |
| [NuvemProduto.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvemProduto.prw) | Classe de integração de produtos Protheus x Nuvemshop. |
| [NuvemAcesso.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvemAcesso.prw) | Camada REST Protheus com Bearer Token e controle de Rate Limit. |
| [NuvemPedido.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/NuvemPedido.prw) | Importação e sincronização de pedidos de venda da Nuvemshop para o ERP. |
| [ECJOBNUV.prw](file:///c:/D/@Fortbras/projeto%20nuvemshop/IntegracaoNuvemShop/ECJOBNUV.prw) | Agendador Protheus (Schedule) em background. |

---

## 5. Dúvidas Frequentes e Boas Práticas

1. **Se eu subir um novo produto, ele vai apagar dados de produtos antigos?**  
   Não. Todos os scripts utilizam busca por SKU/ID e rotas pontuais `PUT /v1/{store_id}/products/{id}`. Nenhum produto existente é excluído ou sobrescrito indevidamente.
2. **Como pausar ou retomar uma sincronização longa?**  
   Os scripts geram checkpoints automáticos (`custom_fields_sync_checkpoint.json` e `tags_sync_checkpoint.json`). Se o processo for interrompido, basta executá-lo novamente que ele retoma da última página concluída.
3. **Onde ficam as credenciais da loja?**  
   - No Protheus: Parâmetro `MV_NUVTOK` (Bearer Token) e `MV_NUVLOJA` (Store ID `8117213`).
   - Nos scripts Node: `migracao_scripts/Product/Nuvemshop/Token,json`.
