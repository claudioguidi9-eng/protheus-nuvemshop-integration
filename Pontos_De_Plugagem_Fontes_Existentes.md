# Guia de Plugagem nos Fontes Existentes do Protheus

Este documento fornece os blocos exatos de código AdvPL que devem ser inseridos nos fontes existentes do repositório para ativar a integração com a **Nuvemshop**.

---

### 1. No arquivo `ECJOB_W.prw` (Descoberta e Ingestão de Pedidos)
No método ou função onde é feito o loop pelas APIs cadastradas na tabela `VT8`, localize a estrutura `Do Case` por `cAPI` e adicione o ramo da Nuvemshop:

```advpl
// ... dentro do loop de APIs ativas ...
Do Case
    Case cAPI == "ANYMARKET"
        AnyPedido():New():CreatePedWeb()

    Case cAPI == "LINKAPI"
        VTEXOrder():New():CreatePedWeb()

    Case cAPI == "COCKPIT"
        CockPedido():New():CreatePedWeb()

    Case cAPI == "CWS"
        CWSPedido():New():CreatePedWeb()

    // >>> NOVO BLOCO NUVEMSHOP <<<
    Case cAPI == "NUVEMSHOP"
        NuvemPedido():New():CreatePedWeb()
EndCase
```

---

### 2. No arquivo `ECPEDIDO.prw` (Processamento do Pedido no ERP)
No método `StartPedido()` da classe `ECPEDIDO`:

```advpl
Do Case
    Case ::cAPI == "ANYMARKET"
        ::StartPedAny()

    Case ::cAPI == "LINKAPI"
        ::StartPedVTEX()

    Case ::cAPI == "COCKPIT"
        ::StartPedCock()

    Case ::cAPI == "CWS"
        ::StartPedCWS()

    // >>> NOVO BLOCO NUVEMSHOP <<<
    Case ::cAPI == "NUVEMSHOP"
        ::StartPedNuvem()
EndCase
```

E no método `StartERPCanc()` (Cancelamento de Pedidos):
```advpl
Do Case
    Case ::cAPI == "ANYMARKET"
        // cancelamento AnyMarket...
    Case ::cAPI == "NUVEMSHOP"
        NuvemPedido():New():SetCancelar(::cOrderID, "Cancelado no Protheus")
EndCase
```

---

### 3. No arquivo `ECPAGAM.prw` (Validação de Pagamento)
No método `StartPgto()` (acionado pelo `ECJOB_1`), tratar o status de pagamento da Nuvemshop:

```advpl
If ::cAPI == "NUVEMSHOP"
    oJson := JsonObject():New()
    oJson:FromJson(VT1->VT1_JSON)
    jOrder := oJson:GetJsonObject()
    
    // Na Nuvemshop, o status de pagamento aprovado e "paid"
    If Lower(cValToChar(jOrder["payment_status"])) == "paid"
        ::lPago := .T.
        // Carrega parcelas financeiras e de-para de administradoras da VT5
        ::GetCondNuvem(jOrder)
    ElseIf Lower(cValToChar(jOrder["payment_status"])) $ "voided|refunded"
        ::lCancelado := .T.
    EndIf
    FreeObj(oJson)
EndIf
```

---

### 4. No arquivo `ECTRACKER.prw` (Faturamento, Despacho e Rastreio)

#### A. No método `StartFatWEB()` (Acionado pelo `ECJOB_5` após faturamento):
```advpl
If ::cAPI == "NUVEMSHOP"
    oNuvPed := NuvemPedido():New()
    // Envia a chave da NF-e para a Nuvemshop
    For nI := 1 To Len(::aNotaFiscal)
        cDoc   := ::aNotaFiscal[nI][1]
        cSerie := ::aNotaFiscal[nI][2]
        
        // Busca a chave de 44 digitos na tabela SF2
        cChaveNFe := POSICIONE("SF2", 1, xFilial("SF2") + cDoc + cSerie, "F2_CHVNFE")
        
        oNuvPed:SetFaturar(::cOrderID, cDoc, cSerie, cChaveNFe)
    Next nI
    FreeObj(oNuvPed)
EndIf
```

#### B. No método `Despachar()` (Acionado pelo `ECJOB_7` após emissão de romaneio):
```advpl
If ::cAPI == "NUVEMSHOP"
    oNuvPed := NuvemPedido():New()
    // Dispara a notificacao de despacho com codigo de rastreamento
    oNuvPed:SetEnviar(::cOrderID, ::cRastreio, ::cTranspNome, ::cRastreioURL)
    FreeObj(oNuvPed)
EndIf
```

---

### 5. Parâmetros a Criar na Tabela `SX6` (Via Configurador Protheus)

| Parâmetro | Tipo | Conteúdo Padrão | Descrição |
| :--- | :---: | :---: | :--- |
| `MV_NUVAPP` | C | `"9876"` | App ID cadastrado no Partner Portal da Nuvemshop |
| `MV_NUVTOK` | C | `""` | Access Token permanente gerado na instalação do App |
| `MV_NUVULTP`| C | `"0"` | Último ID de pedido importado da Nuvemshop (controle de polling) |
| `MV_NUVLOTE`| N | `50` | Tamanho do lote para envio de estoque/preço (máximo 50) |
| `JOB_NUVSLEEP` | N | `60` | Tempo de espera em segundos entre ciclos do JOB ECJOBNUV |
