#INCLUDE "TOTVS.CH"

/*/{Protheus.doc} NuvemPedido
Classe de integracao de Pedidos Nuvemshop - TOTVS Protheus.
Responsavel pela descoberta/ingestao de pedidos, parser do JSON,
inclusao na tabela VT1 e notificacao de faturamento, rastreio e cancelamento.

@author Claudio Guidi
@since 05/09/2026
@version 1.0
@project Integracao Nuvemshop - TOTVS Protheus
/*/
CLASS NuvemPedido FROM NuvemAcesso

	DATA cUltimoId AS CHARACTER

	METHOD New() CONSTRUCTOR
	METHOD CreatePedWeb()
	METHOD SetIncPedido(cIdPedido)
	METHOD SetFaturar(cOrderId, cDoc, cSerie, cChvNFe)
	METHOD SetEnviar(cOrderId, cTrackingCode, cTransp, cTrackURL)
	METHOD SetConcluir(cOrderId)
	METHOD SetCancelar(cOrderId, cMotivo)
	METHOD GetFulfillmentOrderId(cOrderId)

ENDCLASS

/*/{Protheus.doc} New
Construtor da classe NuvemPedido.
/*/
METHOD New() CLASS NuvemPedido
	_Super:New()
	::cUltimoId := AllTrim(SuperGetMV("MV_NUVULTP", .F., "0"))
Return Self

/*/{Protheus.doc} CreatePedWeb
Metodo invocado periodicamente pelo ECJOB_W para leitura dos novos pedidos na Nuvemshop.
Realiza polling incremental com base no ultimo ID importado.
/*/
METHOD CreatePedWeb() CLASS NuvemPedido
	Local cPath     := ""
	Local oJson     := JsonObject():New()
	Local aPedidos  := {}
	Local cMaxId    := ::cUltimoId

	cPath := "/orders?status=open&per_page=50"
	If Val(::cUltimoId) > 0
		cPath += "&since_id=" + ::cUltimoId
	EndIf

	If ::ExecuteRest(cPath, "GET")
		oJson:FromJson(::cLastResult)

		If ValType(oJson:GetJsonObject()) == "A"
			aPedidos := oJson:GetJsonObject()

			For nI := 1 To Len(aPedidos)
				jPed  := aPedidos[nI]
				cId   := cValToChar(jPed["id"])

				// Despacha cada pedido para a fila de threads IpcGo do Protheus
				IpcGo("THREAD_" + cEmpAnt, "U_NUVCREATPED", {cId, "", cFilAnt})

				If Val(cId) > Val(cMaxId)
					cMaxId := cId
				EndIf
			Next nI

			// Atualiza o parametro de controle do ultimo ID
			If Val(cMaxId) > Val(::cUltimoId)
				PutMV("MV_NUVULTP", cMaxId)
				::cUltimoId := cMaxId
			EndIf
		EndIf
	EndIf

	FreeObj(oJson)
Return .T.

/*/{Protheus.doc} U_NUVCREATPED
Funcao executada pela thread em background para processamento individual do pedido.
/*/
User Function NUVCREATPED(aParam)
	Local oPedido := NuvemPedido():New()
	Local cId     := aParam[1]
	Local cFil    := aParam[3]

	If !Empty(cFil) .And. cFil <> cFilAnt
		cFilAnt := cFil
	EndIf

	oPedido:SetIncPedido(cId)
	FreeObj(oPedido)
Return .T.

/*/{Protheus.doc} SetIncPedido
Realiza a captura do pedido completo na Nuvemshop, resolve o seller e filial
atraves do SellerIntegrationService e grava o pedido na tabela VT1 (status '').
/*/
METHOD SetIncPedido(cIdPedido) CLASS NuvemPedido
	Local cLockKey  := "NUVEMPEDIDO" + cIdPedido
	Local oJson     := JsonObject():New()
	Local oEcPedido := Nil
	Local jOrder    := Nil
	Local lOk       := .F.

	// Garante exclusividade de processamento por pedido via mutex nomeado
	If !LockByName(cLockKey, .T., .T., .T.)
		Return .F.
	EndIf

	// 1. Verifica se a API esta liberada (VT8_MSBLQL <> '1')
	If !::ConfigCredentials()
		UnLockByName(cLockKey, .T., .T., .T.)
		Return .F.
	EndIf

	// 2. Busca o pedido completo na Nuvemshop
	If ::ExecuteRest("/orders/" + cIdPedido, "GET")
		oJson:FromJson(::cLastResult)
		jOrder := oJson:GetJsonObject()

		If jOrder <> Nil
			cStatus      := Lower(cValToChar(jOrder["status"]))
			cStatusPgto  := Lower(cValToChar(jOrder["payment_status"]))
			dDataCorte   := SuperGetMV("FB_DTERPHP", .F., CtoD("01/01/2026"))
			cDataPedido  := SubStr(cValToChar(jOrder["created_at"]), 1, 10)
			dDataWeb     := Stod(StrTran(cDataPedido, "-", ""))

			// Trava GOL: desconsidera pedidos anteriores a data de corte
			If !Empty(dDataWeb) .And. dDataWeb < dDataCorte
				UnLockByName(cLockKey, .T., .T., .T.)
				FreeObj(oJson)
				Return .F.
			EndIf

			// Instancia o orquestrador de pedidos oficial do ERP
			oEcPedido := ECPEDIDO():New()
			oEcPedido:cAPI       := "NUVEMSHOP"
			oEcPedido:cOrderID   := cValToChar(jOrder["id"])
			oEcPedido:cSequence  := cValToChar(jOrder["number"])
			oEcPedido:cJSON      := ::cLastResult
			oEcPedido:dDataWeb   := dDataWeb
			oEcPedido:cHoraWeb   := SubStr(cValToChar(jOrder["created_at"]), 12, 8)
			oEcPedido:nValFrete  := Val(cValToChar(jOrder["shipping_cost_customer"]))
			oEcPedido:cModalidadeFrete := "NUV"

			// 3. Resolve Seller / Filial do ERP via SellerIntegrationService
			If FindClass("SellerIntegrationService")
				oSellerService := SellerIntegrationService():New("NUVEMSHOP", ::cStoreId, "NUVEMSHOP")
				jSellerData    := oSellerService:Locate()

				If jSellerData <> Nil
					If jSellerData:HasProperty("ErpFil") .And. !Empty(jSellerData["ErpFil"])
						cFilAnt := jSellerData["ErpFil"]
					EndIf
					oEcPedido:cTipoPed := IIf(jSellerData:HasProperty("ErpTpPed"), jSellerData["ErpTpPed"], "SC5")
				Else
					oEcPedido:cTipoPed := "SC5"
				EndIf
			Else
				oEcPedido:cTipoPed := "SC5"
			EndIf

			// 4. Trata cancelamento caso ja chegue cancelado na plataforma
			If cStatus == "cancelled" .Or. cStatusPgto == "voided" .Or. cStatusPgto == "refunded"
				oEcPedido:StartERPCanc()
			Else
				// 5. Cria/Insere na esteira VT1 com status em branco ('')
				oEcPedido:cStatus := ""
				lOk := oEcPedido:CreatePedWeb()
				ConOut("[NUVEMSHOP] Pedido " + oEcPedido:cOrderID + " (Seq: " + oEcPedido:cSequence + ") gravado com sucesso na VT1.")
			EndIf

			FreeObj(oEcPedido)
		EndIf
	EndIf

	UnLockByName(cLockKey, .T., .T., .T.)
	FreeObj(oJson)
Return lOk

/*/{Protheus.doc} SetFaturar
Registra a Nota Fiscal emitida no Protheus como Metafield no pedido da Nuvemshop.
/*/
METHOD SetFaturar(cOrderId, cDoc, cSerie, cChvNFe) CLASS NuvemPedido
	Local cBody  := ""
	Local cPath  := "/orders/" + cOrderId + "/metafields"
	Local lOk    := .F.

	cBody := '{'
	cBody += '  "namespace": "nfe",'
	cBody += '  "key": "access_key",'
	cBody += '  "value": "' + cChvNFe + '",'
	cBody += '  "description": "Chave de Acesso NF-e ' + cDoc + '-' + cSerie + '"'
	cBody += '}'

	lOk := ::ExecuteRest(cPath, "POST", cBody)
	ConOut("[NUVEMSHOP] Chave NF-e " + cChvNFe + " enviada para o pedido " + cOrderId + ". Status: " + cValToChar(::nLastStatus))
Return lOk

/*/{Protheus.doc} SetEnviar
Notifica o despacho da mercadoria na Nuvemshop atualizando o Fulfillment Order
com os dados da transportadora, codigo de rastreamento e link de tracking.
/*/
METHOD SetEnviar(cOrderId, cTrackingCode, cTransp, cTrackURL) CLASS NuvemPedido
	Local cFoId  := ::GetFulfillmentOrderId(cOrderId)
	Local cPath  := ""
	Local cBody  := ""
	Local lOk    := .F.

	Default cTrackingCode := ""
	Default cTransp       := "Transportadora Oficial"
	Default cTrackURL     := ""

	If !Empty(cFoId)
		cPath := "/orders/" + cOrderId + "/fulfillment-orders/" + cFoId

		cBody := '{'
		cBody += '  "status": "DISPATCHED",'
		cBody += '  "tracking_info": {'
		cBody += '    "code": "' + cTrackingCode + '",'
		cBody += '    "shipping_company": "' + cTransp + '",'
		cBody += '    "tracking_url": "' + cTrackURL + '",'
		cBody += '    "notify_customer": true'
		cBody += '  }'
		cBody += '}'

		lOk := ::ExecuteRest(cPath, "PATCH", cBody)

		// Registra evento de rastreio "dispatched"
		If lOk
			::ExecuteRest(cPath + "/tracking-events", "POST", '{"status": "dispatched"}')
			ConOut("[NUVEMSHOP] Despacho e rastreio informados com sucesso para o pedido " + cOrderId)
		EndIf
	EndIf
Return lOk

/*/{Protheus.doc} SetConcluir
Notifica a entrega do pedido ao cliente.
/*/
METHOD SetConcluir(cOrderId) CLASS NuvemPedido
	Local cFoId := ::GetFulfillmentOrderId(cOrderId)
	Local lOk   := .F.

	If !Empty(cFoId)
		lOk := ::ExecuteRest("/orders/" + cOrderId + "/fulfillment-orders/" + cFoId + "/tracking-events", "POST", '{"status": "delivered"}')
	EndIf
Return lOk

/*/{Protheus.doc} SetCancelar
Comunica o cancelamento do pedido a Nuvemshop.
/*/
METHOD SetCancelar(cOrderId, cMotivo) CLASS NuvemPedido
	Local cBody := ""
	Default cMotivo := "Cancelamento solicitado via ERP Protheus"

	cBody := '{'
	cBody += '  "reason": "' + cMotivo + '",'
	cBody += '  "restock": false,'
	cBody += '  "email": true'
	cBody += '}'

Return ::ExecuteRest("/orders/" + cOrderId + "/cancel", "POST", cBody)

/*/{Protheus.doc} GetFulfillmentOrderId
Recupera o ID do Fulfillment Order associado ao pedido.
/*/
METHOD GetFulfillmentOrderId(cOrderId) CLASS NuvemPedido
	Local cFoId := ""
	Local oJson := JsonObject():New()

	If ::ExecuteRest("/orders/" + cOrderId + "/fulfillment-orders", "GET")
		oJson:FromJson(::cLastResult)
		If ValType(oJson:GetJsonObject()) == "A" .And. Len(oJson:GetJsonObject()) > 0
			jFo := oJson:GetJsonObject()[1]
			cFoId := cValToChar(jFo["id"])
		EndIf
	EndIf

	FreeObj(oJson)
Return cFoId
