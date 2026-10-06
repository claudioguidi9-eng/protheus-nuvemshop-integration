# Manual Operacional: Painel de Pedidos, Retorno de Faturamento e Reprocessamento
## Integração TOTVS Protheus 12 ➔ Nuvemshop • Fortbras

**Data:** Outubro/2026 • Versão 2.3  
**Público-Alvo:** Operação de E-Commerce, Faturamento e Engenharia de TI  

---

### 1. Painel Visual de Pedidos (`U_NUVPAINELPEDIDOS`)

A rotina [`NuvPainelPedidos.prw`](file:///c:/D/@Fortbras/Fontes/02_Integracao_Nuvemshop/NuvPainelPedidos.prw) foi desenvolvida para oferecer à equipe da Fortbras total visibilidade operacional sobre o tráfego de pedidos da Nuvemshop no ERP Protheus.

#### Como Acessar no Protheus:
* Pode ser chamada diretamente pelo atalho do SmartClient: **`U_NUVPAINELPEDIDOS`**
* Ou adicionada aos menus dos módulos:
  * **SIGAFAT (Faturamento):** *Atualizações ➔ E-Commerce ➔ Painel Nuvemshop*
  * **SIGAEST (Estoque):** *Consultas ➔ E-Commerce Nuvemshop*

#### Legenda de Cores do Painel:
* 🟡 **Amarelo (Pendente):** Pedido recém-chegado da Nuvemshop, aguardando execução do Job para gravação do Pedido de Venda (`SC5`).
* 🟢 **Verde (Processado):** Pedido de Venda oficial gravado com sucesso no ERP (`SC5` e `SC6` gerados).
* 🔵 **Azul (Faturado):** Nota Fiscal emitida no Protheus e Chave de Acesso da NF-e transmitida com sucesso para a Nuvemshop.
* 🔴 **Vermelho (Erro / Rejeitado):** Pedido retido por inconsistência (ex: SKU inexistente, cliente com documento divergente). Exibe a causa na coluna de histórico.
* ⚪ **Cinza (Cancelado):** Pedido cancelado na plataforma ou no ERP.

#### Ações Disponíveis no Menu do Painel:
1. **Visualizar Detalhes:** Exibe dados completos do cliente, CPF/CNPJ, endereço, valores de produto e frete.
2. **Reprocessar Pedido:** Com **1 clique**, reseta o status do pedido com erro, limpa o log de rejeição e reexecuta a esteira no Protheus, exibindo na hora se o pedido gerou o `SC5` ou o motivo de ainda estar pendente.
3. **Consultar Nuvemshop Online:** Faz uma chamada REST direta à Nuvemshop e mostra os dados em tempo real (status de pagamento, data, cliente).
4. **Reenviar NF-e:** Localiza a NF-e em `SF2` vinculada ao pedido e força o reenvio da Chave de Acesso para a Nuvemshop.
5. **Informar Rastreio:** Abre janela modal para digitar Transportadora, Código de Rastreamento e Link de Tracking, notificando o despacho imediatamente na loja.
6. **Ver JSON / Log:** Exibe o payload original completo recebido da Nuvemshop para auditoria técnica.

---

### 2. Retorno de Faturamento em Tempo Real (`NuvFatRet.prw` & `M460FIM.prw`)

Quando uma Nota Fiscal de Saída é faturada no Protheus, o ponto de entrada [`M460FIM.prw`](file:///c:/D/@Fortbras/Fontes/ProtheusFontes021026/faturamento/M460FIM.prw) aciona automaticamente a rotina [`NuvFatRet.prw`](file:///c:/D/@Fortbras/Fontes/02_Integracao_Nuvemshop/NuvFatRet.prw):

```
       [ Emissão de NF-e no Protheus ]
                     │
                     ▼
          [ Ponto de Entrada M460FIM ]
                     │
                     ▼
         [ Executa U_NUVFATRET ]
                     │
    ┌────────────────┴────────────────┐
    │                                 │
    ▼                                 ▼
[ 1. Notifica Nuvemshop ]      [ 2. Atualiza Saldo Delta ]
• Envia Chave NF-e 44 dígitos   • Lê itens faturados em SD2
  (Metafields /orders/{id}/nfe) • Enfileira na tabela VTF
• Se houver rastreio, despacha  • Job ECJOBNUV envia novo
• Atualiza status VT1 para '6'    estoque para a Nuvemshop
```

---

### 3. Integração com a Esteira Corporativa ECTRACKER (`ECTRACKER.prw`)

Além do disparo imediato no `M460FIM`, o conector foi plugado no motor de rastreamento corporativo [`ECTRACKER.prw`](file:///c:/D/@Fortbras/Fontes/ProtheusFontes021026/Ecommerce/Transportadoras/ECTRACKER.prw):
* **No método `EnviaNotaFiscal()`:** Quando o Job `ECJOB_5` roda, ele reconhece a API `NUVEMSHOP` e envia a nota via `NuvemPedido:SetFaturar()`.
* **No método `Despachar()`:** Quando o Job `ECJOB_7` processa os despachos ou romaneios, ele invoca `NuvemPedido:SetEnviar()` com código de rastreio e nome da transportadora.

---

### 4. Ciclo de Auditoria e Reprocessamento de Erros

| Tipo de Erro | Onde Fica Registrado | Como Corrigir | Como Reprocessar |
| :--- | :--- | :--- | :--- |
| **SKU não cadastrado no Protheus** | `VT1_OBS` no Painel | Amarrar o SKU na tabela `VT9` ou cadastrar no `SB1` | Clicar em **"Reprocessar Pedido"** no Painel |
| **Cliente com CPF/Endereço inválido** | `VT1_OBS` no Painel | Corrigir ou ajustar o cadastro do cliente em `SA1` | Clicar em **"Reprocessar Pedido"** no Painel |
| **Falha temporária de rede/API** | Console `ConOut` e `VTF_OBS` | O Job faz retentativa automática no ciclo seguinte | Automático pelo Schedule ou manual no Painel |
