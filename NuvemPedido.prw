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
	METHOD SeekProductERP(cSku, cBarcode)
	METHOD MockPedido(cIdPedido)

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
	Local nI        := 0
	Local jPed      := Nil
	Local cId       := ""

	cPath := "/orders?status=any&per_page=50"
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
	Local cLockKey        := "NUVEMPEDIDO" + cIdPedido
	Local oJson           := JsonObject():New()
	Local jOrder          := Nil
	Local lOk             := .F.
	Local cStatus         := ""
	Local cStatusPgto     := ""
	Local xDataCorte      := Nil
	Local dDataCorte      := CtoD("//")
	Local cDataPedido     := ""
	Local dDataWeb        := CtoD("//")
	Local oSellerService  := Nil
	Local jSellerData     := Nil
	Local cAliasQry       := ""
	Local cQuery          := ""

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
		If oJson:FromJson(::cLastResult) == Nil
			jOrder := oJson
		Else
			jOrder := Nil
		EndIf

		If jOrder <> Nil
			cStatus      := Lower(cValToChar(jOrder["status"]))
			cStatusPgto  := Lower(cValToChar(jOrder["payment_status"]))

			// Normaliza Data de Corte (FB_DTERPHP pode estar gravado como C ou D no SX6)
			xDataCorte := SuperGetMV("FB_DTERPHP", .F., CtoD("01/01/2020"))
			If ValType(xDataCorte) == "C"
				If "/" $ xDataCorte
					dDataCorte := CtoD(xDataCorte)
				ElseIf Len(AllTrim(xDataCorte)) == 8
					dDataCorte := Stod(AllTrim(xDataCorte))
				Else
					dDataCorte := CtoD("01/01/2020")
				EndIf
			ElseIf ValType(xDataCorte) == "D"
				dDataCorte := xDataCorte
			Else
				dDataCorte := CtoD("01/01/2020")
			EndIf

			cDataPedido  := SubStr(cValToChar(jOrder["created_at"]), 1, 10)
			dDataWeb     := Stod(StrTran(cDataPedido, "-", ""))
			If ValType(dDataWeb) <> "D" .Or. Empty(dDataWeb)
				dDataWeb := dDataBase
			EndIf

			ConOut("[NUVEMSHOP] Ingestao VT1 - Pedido ID: " + cIdPedido + " | Num: " + cValToChar(jOrder["number"]) + " | Data: " + DtoC(dDataWeb))

			// Trava GOL: desconsidera pedidos anteriores a data de corte
			If ValType(dDataWeb) == "D" .And. ValType(dDataCorte) == "D" .And. !Empty(dDataWeb) .And. !Empty(dDataCorte)
				If dDataWeb < dDataCorte
					ConOut("[NUVEMSHOP] Pedido " + cIdPedido + " desconsiderado por data anterior ao corte (Data: " + DtoC(dDataWeb) + " < Corte: " + DtoC(dDataCorte) + ")")
					UnLockByName(cLockKey, .T., .T., .T.)
					FreeObj(oJson)
					Return .F.
				EndIf
			EndIf

			// 3. Mantem a filial posicionada (ou resolve via SellerIntegrationService se configurado)
			If FindClass("SellerIntegrationService")
				oSellerService := SellerIntegrationService():New("NUVEMSHOP", ::cStoreId, "NUVEMSHOP")
				jSellerData    := oSellerService:Locate()

				If ValType(jSellerData) $ "O|J"
					If jSellerData:HasProperty("ErpFil") .And. !Empty(jSellerData["ErpFil"])
						cFilAnt := jSellerData["ErpFil"]
					EndIf
				EndIf
				FreeObj(oSellerService)
			EndIf

			If Empty(cFilAnt)
				cFilAnt := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
			EndIf

			// 4. Ingestao oficial na esteira VT1 do Protheus
			If ChkFile("VT1")
				DbSelectArea("VT1")
				VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID

				// Verifica via Indice 1 se o pedido ja existe na esteira VT1
				If VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))
					ConOut("[NUVEMSHOP] Pedido " + cIdPedido + " ja consta na esteira VT1 (Status: '" + VT1->VT1_STATUS + "').")
					lOk := .T.
				Else
					ConOut("[NUVEMSHOP] Gravando novo pedido " + cIdPedido + " (Seq: " + cValToChar(jOrder["number"]) + ") na filial " + cFilAnt + " (tabela VT1)...")

					RecLock("VT1", .T.)
					VT1->VT1_FILIAL := xFilial("VT1")
					VT1->VT1_ORDID  := PADR(cIdPedido, TamSX3("VT1_ORDID")[1])

					If VT1->(FieldPos("VT1_SEQUEN")) > 0
						VT1->VT1_SEQUEN := PADR(cValToChar(jOrder["number"]), TamSX3("VT1_SEQUEN")[1])
					EndIf
					If VT1->(FieldPos("VT1_STATUS")) > 0
						VT1->VT1_STATUS := " "  // Em branco para processamento da esteira
					EndIf
					If VT1->(FieldPos("VT1_DATAIN")) > 0
						VT1->VT1_DATAIN := dDataWeb
					EndIf
					If VT1->(FieldPos("VT1_HORAIN")) > 0
						VT1->VT1_HORAIN := SubStr(cValToChar(jOrder["created_at"]), 12, 8)
					EndIf
					If VT1->(FieldPos("VT1_DTWEB")) > 0
						VT1->VT1_DTWEB := dDataWeb
					EndIf
					If VT1->(FieldPos("VT1_HRWEB")) > 0
						VT1->VT1_HRWEB := SubStr(cValToChar(jOrder["created_at"]), 12, 8)
					EndIf
					If VT1->(FieldPos("VT1_DATAUL")) > 0
						VT1->VT1_DATAUL := dDataBase
					EndIf
					If VT1->(FieldPos("VT1_HORAUL")) > 0
						VT1->VT1_HORAUL := Time()
					EndIf
					If VT1->(FieldPos("VT1_OBS")) > 0
						VT1->VT1_OBS := ::cLastResult
					EndIf
					If VT1->(FieldPos("VT1_NUMPED")) > 0
						VT1->VT1_NUMPED := Space(TamSX3("VT1_NUMPED")[1])
					EndIf
					If VT1->(FieldPos("VT1_JSON")) > 0
						VT1->VT1_JSON := ::cLastResult
					EndIf
					If VT1->(FieldPos("VT1_API")) > 0
						VT1->VT1_API := "NUVEMSHOP"
					EndIf
					If VT1->(FieldPos("VT1_VALOR")) > 0
						VT1->VT1_VALOR := Val(cValToChar(jOrder["total"]))
					EndIf
					If VT1->(FieldPos("VT1_VALFRE")) > 0
						VT1->VT1_VALFRE := Val(cValToChar(jOrder["shipping_cost_customer"]))
					EndIf
					If VT1->(FieldPos("VT1_MODFRE")) > 0
						VT1->VT1_MODFRE := "NUV"
					EndIf
					If VT1->(FieldPos("VT1_TPPED")) > 0
						VT1->VT1_TPPED := "SC5"
					EndIf
					If VT1->(FieldPos("VT1_TIPPED")) > 0
						VT1->VT1_TIPPED := "SC5"
					EndIf
					If VT1->(FieldPos("VT1_CODSA3")) > 0 .And. Empty(VT1->VT1_CODSA3)
						VT1->VT1_CODSA3 := SuperGetMv("MV_YVENNUV", .F., SuperGetMv("VT_VENDPAD", .F., ""))
					EndIf
					SetVT8Nuv()
					VT1->(MsUnlock())
					lOk := .T.
					ConOut("[NUVEMSHOP] Pedido " + cIdPedido + " gravado com sucesso na esteira VT1!")
				EndIf
			Else
				ConOut("[NUVEMSHOP] ATENCAO: Tabela VT1 nao encontrada no dicionario do Protheus!")
				lOk := .F.
			EndIf
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
	Local jFo   := Nil

	If ::ExecuteRest("/orders/" + cOrderId + "/fulfillment-orders", "GET")
		oJson:FromJson(::cLastResult)
		If ValType(oJson:GetJsonObject()) == "A" .And. Len(oJson:GetJsonObject()) > 0
			jFo := oJson:GetJsonObject()[1]
			cFoId := cValToChar(jFo["id"])
		EndIf
	EndIf

	FreeObj(oJson)
Return cFoId

/*/{Protheus.doc} SeekProductERP
Localiza o codigo do produto no Protheus (SB1) a partir do SKU ou EAN da Nuvemshop.
Prioridade de resolucao:
1. SB1 por B1_CODBAR (EAN / Codigo de Barras - Chave Universal GTIN)
2. SB1 por B1_COD (SKU direto)
3. VT9 (De-Para oficial E-Commerce Fortbras)
/*/
METHOD SeekProductERP(cSku, cBarcode) CLASS NuvemPedido
	Local cCodProd  := ""
	Local cFilSB1   := xFilial("SB1")
	Local cAliasQry := ""
	Local cQuery    := ""

	Default cSku     := ""
	Default cBarcode := ""

	cSku     := AllTrim(cSku)
	cBarcode := AllTrim(cBarcode)

	// 1. PRIORIDADE MAXIMA: Busca por Codigo de Barras / EAN (Chave Unica Universal GTIN)
	If !Empty(cBarcode)
		cAliasQry := GetNextAlias()
		cQuery := "SELECT B1_COD, B1_DESC, B1_CODBAR FROM " + RetSqlName("SB1") + " SB1 "
		cQuery += " WHERE SB1.D_E_L_E_T_ = ' ' "
		cQuery += "   AND SB1.B1_FILIAL = '" + cFilSB1 + "' "
		cQuery += "   AND SB1.B1_CODBAR = '" + cBarcode + "' "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

		If !(cAliasQry)->(Eof()) .And. !Empty((cAliasQry)->B1_COD)
			cCodProd := AllTrim((cAliasQry)->B1_COD)
			(cAliasQry)->(dbCloseArea())
			Return cCodProd
		EndIf
		(cAliasQry)->(dbCloseArea())

		// Fallback EAN caso filial compartilhada ou vazia
		cAliasQry := GetNextAlias()
		cQuery := "SELECT B1_COD, B1_DESC, B1_CODBAR FROM " + RetSqlName("SB1") + " SB1 "
		cQuery += " WHERE SB1.D_E_L_E_T_ = ' ' "
		cQuery += "   AND SB1.B1_CODBAR = '" + cBarcode + "' "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

		If !(cAliasQry)->(Eof()) .And. !Empty((cAliasQry)->B1_COD)
			cCodProd := AllTrim((cAliasQry)->B1_COD)
			(cAliasQry)->(dbCloseArea())
			Return cCodProd
		EndIf
		(cAliasQry)->(dbCloseArea())
	EndIf

	// 2. Busca direta por B1_COD (Ordem 1: B1_FILIAL + B1_COD)
	If !Empty(cSku)
		DbSelectArea("SB1")
		SB1->(DbSetOrder(1))
		If SB1->(DbSeek(cFilSB1 + PADR(cSku, TamSX3("B1_COD")[1])))
			Return AllTrim(SB1->B1_COD)
		EndIf

		If SB1->(DbSeek(PADR(cSku, TamSX3("B1_COD")[1])))
			Return AllTrim(SB1->B1_COD)
		EndIf
	EndIf

	// 3. Busca no De-Para oficial VT9 da Fortbras
	If ChkFile("VT9") .And. !Empty(cSku)
		DbSelectArea("VT9")
		VT9->(DbSetOrder(1))
		If VT9->(DbSeek(xFilial("VT9") + PADR("NUVEMSHOP", TamSX3("VT9_API")[1]) + cSku))
			Return AllTrim(VT9->VT9_PRODUT)
		EndIf
	EndIf

	// 4. Se ainda nao achou, retorna o proprio SKU para tentativa no ERP
	If !Empty(cSku)
		cCodProd := cSku
	EndIf

Return cCodProd

/*/{Protheus.doc} NUVPED
Funcao simples para consulta e sincronizacao de pedidos da Nuvemshop no Protheus.
Execucao direta no SmartClient ou Menu: U_NUVPED
/*/
User Function NUVPED(cIdPedido)
	Local oNuvPed    := NuvemPedido():New()
	Local lOk        := .F.
	Local cMsg       := ""
	Local oJson      := Nil
	Local jOrder     := Nil
	Local cNumPed    := ""
	Local cCliNome   := ""
	Local cCliDoc    := ""
	Local cTotPed    := ""
	Local aProds     := {}
	Local nI         := 0
	Local cItensTxt  := ""
	Local cSkuItem   := ""
	Local cEanItem   := ""
	Local cCodProtheus := ""
	Local cDescProd  := ""
	Local cStatusPed := ""
	Local cStatusPg  := ""
	Local cMetodoBusca := ""

	Default cIdPedido := ""

	If Empty(cIdPedido)
		cIdPedido := AllTrim(FWInputBox("Informe o ID do Pedido Nuvemshop (Filial Atual: " + cFilAnt + "):", "2082712287"))
	EndIf

	If Empty(cIdPedido)
		Return .F.
	EndIf

	// 0. Verifica se o pedido ja existe na tabela VT1
	DbSelectArea("VT1")
	VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID
	If VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))
		cMsg := "O Pedido Nuvemshop (ID: " + cIdPedido + ") JA CONSTA na tabela VT1!" + CRLF + CRLF
		cMsg += "Filial: " + cFilAnt + CRLF
		cMsg += "Sequencial VT1: " + AllTrim(VT1->VT1_SEQUEN) + CRLF
		cMsg += "Status VT1: '" + VT1->VT1_STATUS + "'" + CRLF
		cMsg += "Pedido de Venda (SC5): " + IIf(!Empty(VT1->VT1_NUMPED), VT1->VT1_NUMPED, "[Ainda nao gerado]") + CRLF + CRLF
		cMsg += "Deseja processar este pedido agora via esteira oficial ECPEDIDO para gerar a SC5/SC6 imediatamente?"
		If MsgYesNo(cMsg, "Pedido Ja Cadastrado na VT1")
			U_NUVPEDSC5(cIdPedido)
			FreeObj(oNuvPed)
			Return .T.
		EndIf
	EndIf

	ConOut("[NUVEMSHOP] Iniciando consulta/importacao manual do pedido: " + cIdPedido + " na Filial: " + cFilAnt)

	// Garante o Token Mestre com escopo de leitura e gravacao de pedidos (read_orders/write_orders)
	If Empty(oNuvPed:cAccessToken) .Or. oNuvPed:cAccessToken == "44ffe7a14117c3bdde82906080a810f477c6368d" .Or. oNuvPed:cAccessToken == "f9255da9858fc4c00eb3c5a4078a6c86cc918e85"
		oNuvPed:cAccessToken := "1637dd9821cec89241d671a7307f6001c5450eb5"
		PutMV("MV_NUVTOK", oNuvPed:cAccessToken)
	EndIf

	// 1. Busca detalhes do pedido diretamente na API da Nuvemshop
	If oNuvPed:ExecuteRest("/orders/" + cIdPedido, "GET")
		oJson := JsonObject():New()
		If oJson:FromJson(oNuvPed:cLastResult) == Nil
			jOrder := oJson
		Else
			jOrder := Nil
		EndIf

		If jOrder <> Nil
			cNumPed   := cValToChar(jOrder["number"])
			cStatusPed:= cValToChar(jOrder["status"])
			cStatusPg := cValToChar(jOrder["payment_status"])
			cTotPed   := cValToChar(jOrder["total"])

			If jOrder:HasProperty("customer") .And. jOrder["customer"] <> Nil
				cCliNome := cValToChar(jOrder["customer"]["name"])
				cCliDoc  := cValToChar(jOrder["customer"]["identification"])
			EndIf

			If jOrder:HasProperty("products") .And. ValType(jOrder["products"]) == "A"
				aProds := jOrder["products"]
				For nI := 1 To Len(aProds)
					cSkuItem := cValToChar(aProds[nI]["sku"])
					cEanItem := IIf(aProds[nI]:HasProperty("barcode"), cValToChar(aProds[nI]["barcode"]), "")

					// Verifica como o produto e resolvido no Protheus (Priorizando EAN)
					cCodProtheus := oNuvPed:SeekProductERP(cSkuItem, cEanItem)

					DbSelectArea("SB1")
					SB1->(DbSetOrder(1))
					If SB1->(DbSeek(xFilial("SB1") + PADR(cCodProtheus, TamSX3("B1_COD")[1])))
						cDescProd := AllTrim(SB1->B1_DESC)
						If !Empty(cEanItem) .And. AllTrim(SB1->B1_CODBAR) == cEanItem
							cMetodoBusca := "EAN (B1_CODBAR: " + cEanItem + ")"
						Else
							cMetodoBusca := "SKU Direto (B1_COD: " + cCodProtheus + ")"
						EndIf
					Else
						cDescProd := "[NAO LOCALIZADO NA SB1 COM ESTE CODIGO]"
						cMetodoBusca := "Nao Encontrado"
					EndIf

					cItensTxt += "- Item " + cValToChar(nI) + ": " + CRLF
					cItensTxt += "  * SKU Nuvemshop: " + cSkuItem + CRLF
					cItensTxt += "  * EAN/Barras: " + cEanItem + CRLF
					cItensTxt += "  * Codigo Localizado Protheus: " + cCodProtheus + CRLF
					cItensTxt += "  * Metodo de Encontro: " + cMetodoBusca + CRLF
					cItensTxt += "  * Descricao SB1: " + cDescProd + CRLF
					cItensTxt += "  * Quantidade: " + cValToChar(aProds[nI]["quantity"]) + " | Preco: R$ " + cValToChar(aProds[nI]["price"]) + CRLF + CRLF
				Next nI
			EndIf
		EndIf
		FreeObj(oJson)
	Else
		cMsg := "Falha ao comunicar com a Nuvemshop online para o pedido " + cIdPedido + "!" + CRLF + CRLF
		cMsg += "Status HTTP: " + cValToChar(oNuvPed:nLastStatus) + CRLF
		cMsg += "Erro: " + oNuvPed:GetLastError() + CRLF + CRLF
		cMsg += "Deseja carregar o payload do pedido de teste homologado (2082712287 - Larissa Fernandes) diretamente para a tabela VT1 agora para validar a geracao de SC5/SC6?"
		If MsgYesNo(cMsg, "Carga Local / Teste VT1")
			lOk := oNuvPed:MockPedido(cIdPedido)
			If lOk
				MsgInfo("Pedido " + cIdPedido + " gravado com SUCESSO na tabela VT1!" + CRLF + CRLF + ;
					"Disparando agora a geracao do Pedido de Venda oficial SC5/SC6 via esteira ECPEDIDO...", "Sucesso - Pedido na VT1")
				U_NUVPEDSC5(cIdPedido)
				FreeObj(oNuvPed)
				Return .T.
			EndIf
		EndIf
		FreeObj(oNuvPed)
		Return .F.
	EndIf

	// 2. Executa a ingestao oficial na esteira VT1 do Protheus
	lOk := oNuvPed:SetIncPedido(cIdPedido)

	If lOk
		cMsg := "=== PEDIDO NUVEMSHOP #" + cNumPed + " (ID: " + cIdPedido + ") ===" + CRLF + CRLF
		cMsg += "Filial Posicionada: " + cFilAnt + CRLF
		cMsg += "Status Nuvem: " + cStatusPed + " | Pagamento: " + cStatusPg + CRLF
		cMsg += "Cliente: " + cCliNome + " (CPF/CNPJ: " + cCliDoc + ")" + CRLF
		cMsg += "Total: R$ " + cTotPed + CRLF + CRLF
		cMsg += "PRODUTOS E RESOLUCAO NO TOTVS PROTHEUS:" + CRLF
		cMsg += cItensTxt
		cMsg += ">> GRAVADO COM SUCESSO NA TABELA VT1 (Esteira E-Commerce Protheus)! <<" + CRLF + CRLF
		cMsg += "O pedido ja esta na esteira aguardando a geracao de SC5/SC6."
		MsgInfo(cMsg, "Sucesso - Pedido Nuvemshop na VT1")
		If MsgYesNo("Deseja executar agora o processamento oficial da esteira (ECPEDIDO) para gerar o Pedido de Venda SC5/SC6 imediatamente?", "Gerar SC5/SC6 Agora?")
			U_NUVPEDSC5(cIdPedido)
		EndIf
	Else
		cMsg := "O pedido #" + cNumPed + " (ID: " + cIdPedido + ") foi lido na Nuvemshop, mas nao foi gravado na VT1." + CRLF + CRLF
		cMsg += "Filial Atual: " + cFilAnt + CRLF + CRLF
		cMsg += "Possiveis causas:" + CRLF
		cMsg += "1. Pedido ja cadastrado anteriormente na VT1." + CRLF
		cMsg += "2. Data do pedido anterior a data de corte (FB_DTERPHP)." + CRLF
		cMsg += "3. Verifique o console do AppServer Protheus para detalhes."
		MsgAlert(cMsg, "Atencao - Ingestao VT1")
	EndIf

	FreeObj(oNuvPed)
Return lOk

User Function NUVEMPED(cIdPedido)
Return U_NUVPED(cIdPedido)

User Function NuvSyncPed(cIdPedido)
Return U_NUVPED(cIdPedido)



/*/{Protheus.doc} NUVPEDSC5
Processa o pedido gravado na VT1 gerando o Pedido de Venda oficial SC5/SC6 via ECPEDIDO.
@param cIdPedido, character, ID do pedido da Nuvemshop (ex: "2082712287")
@author Claudio Guidi
@since 30/09/2026
/*/
User Function NUVPEDSC5(cIdPedido)
	Local oECPEDIDO   := Nil
	Local cSeqPed     := ""
	Local cMsgErr     := ""
	Local nI          := 0
	Local lSuccess    := .F.
	Local cNumGerado  := ""

	Default cIdPedido := "2082712287"

	// 1. Garante que o canal NUVEMSHOP existe e esta ativo na VT8
	SetVT8Nuv()

	// 2. Posiciona no registro da VT1
	DbSelectArea("VT1")
	VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID
	If VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))
		cSeqPed := AllTrim(VT1->VT1_SEQUEN)

		// Reseta status para branco (' ') e garante campos essenciais caso o pedido tenha ficado com status anterior
		If Empty(VT1->VT1_NUMPED)
			RecLock("VT1", .F.)
			If VT1->(FieldPos("VT1_STATUS")) > 0
				VT1->VT1_STATUS := " "
			EndIf
			If VT1->(FieldPos("VT1_DTWEB")) > 0 .And. Empty(VT1->VT1_DTWEB)
				VT1->VT1_DTWEB := IIf(!Empty(VT1->VT1_DATAIN), VT1->VT1_DATAIN, dDataBase)
			EndIf
			If VT1->(FieldPos("VT1_HRWEB")) > 0 .And. Empty(VT1->VT1_HRWEB)
				VT1->VT1_HRWEB := IIf(!Empty(VT1->VT1_HORAIN), VT1->VT1_HORAIN, Time())
			EndIf
			VT1->(MsUnlock())
		EndIf

		// Dispara a rotina oficial de processamento de pedidos do e-commerce da Fortbras
		oECPEDIDO := ECPEDIDO():New()
		oECPEDIDO:cApi      := VT1->VT1_API
		oECPEDIDO:cOrderID  := VT1->VT1_ORDID
		oECPEDIDO:cSequence := VT1->VT1_SEQUEN

		ConOut("[NUVEMSHOP] Disparando ECPEDIDO:StartPedido() para ID: " + cIdPedido + " Filial: " + cFilAnt)
		oECPEDIDO:StartPedido()

		// Recarrega o registro da VT1 para validar o status
		VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))

		If !Empty(oECPEDIDO:cNumPedido) .Or. !Empty(VT1->VT1_NUMPED)
			lSuccess := .T.
			cNumGerado := IIf(!Empty(oECPEDIDO:cNumPedido), oECPEDIDO:cNumPedido, VT1->VT1_NUMPED)
			MsgInfo("=== PEDIDO DE VENDA GERADO COM SUCESSO! ===" + CRLF + CRLF + ;
				"Numero SC5 (C5_NUM): " + cNumGerado + CRLF + ;
				"Filial: " + cFilAnt + CRLF + ;
				"Pedido Nuvemshop: #" + cSeqPed + " (ID: " + cIdPedido + ")" + CRLF + ;
				"Status VT1: " + VT1->VT1_STATUS + CRLF + ;
				"Campo VT1_NUMPED: " + VT1->VT1_NUMPED + CRLF + CRLF + ;
				"O pedido agora pode seguir pela esteira oficial de faturamento!", "Sucesso - SC5/SC6 Gerada")
		Else
			For nI := 1 To Len(oECPEDIDO:aMsgErro)
				cMsgErr += "- " + oECPEDIDO:aMsgErro[nI] + CRLF
			Next nI
			If Empty(cMsgErr) .And. !Empty(VT1->VT1_OBS)
				cMsgErr := "- " + AllTrim(VT1->VT1_OBS) + CRLF
			EndIf
			If Empty(cMsgErr)
				cMsgErr := "Status VT1 atual: '" + VT1->VT1_STATUS + "'. Nenhuma mensagem detalhada retornada."
			EndIf
			MsgAlert("Nao foi possivel gerar a SC5/SC6 para o pedido Nuvemshop #" + cSeqPed + "!" + CRLF + CRLF + ;
				"Motivo(s):" + CRLF + cMsgErr, "Atencao - Falha na Geracao SC5")
		EndIf

		FreeObj(oECPEDIDO)
	Else
		MsgStop("Pedido " + cIdPedido + " nao localizado na tabela VT1 da filial " + cFilAnt + "!" + CRLF + ;
			"Execute primeiro a captura com U_NUVPED(" + cIdPedido + ").", "Pedido Nao Encontrado na VT1")
	EndIf
Return lSuccess

/*/{Protheus.doc} SetVT8Nuv
Garante que a tabela VT8 (Canais de Integracao / APIs E-Commerce) possui o canal NUVEMSHOP ativo.
/*/
Static Function SetVT8Nuv()
	Local aAreaVT8 := VT8->(GetArea())
	DbSelectArea("VT8")
	VT8->(DbSetOrder(1)) // VT8_FILIAL + VT8_API
	If !VT8->(DbSeek(xFilial("VT8") + PADR("NUVEMSHOP", TamSX3("VT8_API")[1])))
		RecLock("VT8", .T.)
		VT8->VT8_FILIAL := xFilial("VT8")
		If VT8->(FieldPos("VT8_CODIGO")) > 0
			VT8->VT8_CODIGO := GetSxeNum("VT8", "VT8_CODIGO")
			ConfirmSx8()
		EndIf
		VT8->VT8_API := "NUVEMSHOP"
		If VT8->(FieldPos("VT8_DESC")) > 0
			VT8->VT8_DESC := "INTEGRACAO NUVEMSHOP"
		EndIf
		If VT8->(FieldPos("VT8_MSBLQL")) > 0
			VT8->VT8_MSBLQL := "2" // 2=Nao bloqueado (Ativo)
		EndIf
		VT8->(MsUnlock())
		ConOut("[NUVEMSHOP] Canal NUVEMSHOP criado com sucesso na tabela VT8!")
	Else
		If VT8->(FieldPos("VT8_MSBLQL")) > 0 .And. VT8->VT8_MSBLQL == "1"
			RecLock("VT8", .F.)
			VT8->VT8_MSBLQL := "2"
			VT8->(MsUnlock())
			ConOut("[NUVEMSHOP] Canal NUVEMSHOP desbloqueado na tabela VT8!")
		EndIf
	EndIf
	RestArea(aAreaVT8)
Return

/*/{Protheus.doc} NUVCLEANPED
Limpa/exclui o pedido da tabela VT1 para permitir novo reprocessamento de teste.
Uso via SmartClient: U_NUVCLEANPED("2082712287")
/*/
User Function NUVCLEANPED(cIdPedido)
	Local aAreaVT1 := VT1->(GetArea())
	Default cIdPedido := "2082712287"

	DbSelectArea("VT1")
	VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID
	If VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))
		RecLock("VT1", .F.)
		VT1->(DbDelete())
		VT1->(MsUnlock())
		MsgInfo("Pedido #" + cIdPedido + " excluido da tabela VT1 com sucesso!" + CRLF + CRLF + ;
			"Agora a esteira permitira capturar e processar este pedido novamente do zero.", "VT1 Limpa")
	Else
		MsgAlert("Pedido #" + cIdPedido + " nao localizado na tabela VT1 da filial " + cFilAnt + ".", "Aviso")
	EndIf
	RestArea(aAreaVT1)
Return .T.

User Function NUVRESET(cIdPedido)
Return U_NUVCLEANPED(cIdPedido)

/*/{Protheus.doc} MockPedido
Grava na tabela VT1 o payload homologado do pedido teste (2082712287 - Larissa Fernandes)
permitindo testar a geracao de SC5/SC6 mesmo quando o servidor AppServer nao tiver rota de internet direta.
/*/
METHOD MockPedido(cIdPedido) CLASS NuvemPedido
	Local lOk       := .F.
	Local cJsonMock := ""

	Default cIdPedido := "2082712287"

	// JSON estruturado do pedido homologado com cliente Larissa Fernandes e item T1SB55WH985K
	cJsonMock := '{"id":2082712287,"number":104,"status":"open","payment_status":"paid",'
	cJsonMock += '"total":"20.95","subtotal":"20.95","shipping_cost_customer":"0.00","shipping_option":"Padrao",'
	cJsonMock += '"created_at":"' + Dtos(dDataBase) + 'T' + Time() + '+00:00",'
	cJsonMock += '"customer":{"name":"Larissa Fernandes","email":"larissa.fernandes@fortbras.com.br","identification":"38855870840","phone":""},'
	cJsonMock += '"billing_address":{"name":"Larissa Fernandes","address":"Rua Federacao Paulista de Futebol","number":"61","locality":"Barra Funda","zipcode":"01141040","city":"Sao Paulo","province":"SP","country":"BR"},'
	cJsonMock += '"shipping_address":{"name":"Larissa Fernandes","address":"Rua Federacao Paulista de Futebol","number":"61","locality":"Barra Funda","zipcode":"01141040","city":"Sao Paulo","province":"SP","country":"BR"},'
	cJsonMock += '"products":[{"id":3567249348,"name":"Lampada Farol 12v 55w 8500k Super Branca H9 Techone T1SB55WH985K","sku":"T1SB55WH985K","barcode":"7898613221942","quantity":1,"price":"20.95"}]}'

	If ChkFile("VT1")
		DbSelectArea("VT1")
		VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID
		If VT1->(DbSeek(xFilial("VT1") + PADR(cIdPedido, TamSX3("VT1_ORDID")[1])))
			RecLock("VT1", .F.)
		Else
			RecLock("VT1", .T.)
			VT1->VT1_FILIAL := xFilial("VT1")
			VT1->VT1_ORDID  := PADR(cIdPedido, TamSX3("VT1_ORDID")[1])
		EndIf

		If VT1->(FieldPos("VT1_SEQUEN")) > 0
			VT1->VT1_SEQUEN := PADR("104", TamSX3("VT1_SEQUEN")[1])
		EndIf
		If VT1->(FieldPos("VT1_STATUS")) > 0
			VT1->VT1_STATUS := " "
		EndIf
		If VT1->(FieldPos("VT1_DATAIN")) > 0
			VT1->VT1_DATAIN := dDataBase
		EndIf
		If VT1->(FieldPos("VT1_HORAIN")) > 0
			VT1->VT1_HORAIN := Time()
		EndIf
		If VT1->(FieldPos("VT1_DTWEB")) > 0
			VT1->VT1_DTWEB := dDataBase
		EndIf
		If VT1->(FieldPos("VT1_HRWEB")) > 0
			VT1->VT1_HRWEB := Time()
		EndIf
		If VT1->(FieldPos("VT1_DATAUL")) > 0
			VT1->VT1_DATAUL := dDataBase
		EndIf
		If VT1->(FieldPos("VT1_HORAUL")) > 0
			VT1->VT1_HORAUL := Time()
		EndIf
		If VT1->(FieldPos("VT1_JSON")) > 0
			VT1->VT1_JSON := cJsonMock
		EndIf
		If VT1->(FieldPos("VT1_OBS")) > 0
			VT1->VT1_OBS := cJsonMock
		EndIf
		If VT1->(FieldPos("VT1_API")) > 0
			VT1->VT1_API := "NUVEMSHOP"
		EndIf
		If VT1->(FieldPos("VT1_VALOR")) > 0
			VT1->VT1_VALOR := 20.95
		EndIf
		If VT1->(FieldPos("VT1_VALFRE")) > 0
			VT1->VT1_VALFRE := 0
		EndIf
		If VT1->(FieldPos("VT1_MODFRE")) > 0
			VT1->VT1_MODFRE := "NUV"
		EndIf
		If VT1->(FieldPos("VT1_TPPED")) > 0
			VT1->VT1_TPPED := "SC5"
		EndIf
		If VT1->(FieldPos("VT1_TIPPED")) > 0
			VT1->VT1_TIPPED := "SC5"
		EndIf
		If VT1->(FieldPos("VT1_CODSA3")) > 0 .And. Empty(VT1->VT1_CODSA3)
			VT1->VT1_CODSA3 := SuperGetMv("MV_YVENNUV", .F., SuperGetMv("VT_VENDPAD", .F., ""))
		EndIf
		SetVT8Nuv()
		VT1->(MsUnlock())
		lOk := .T.
		ConOut("[NUVEMSHOP] Pedido Mock " + cIdPedido + " gravado com sucesso na esteira VT1!")
	EndIf

Return lOk

/*/{Protheus.doc} NUVMOCK
Funcao executavel via SmartClient para carregar o pedido teste na VT1 e gerar a SC5/SC6 imediatamente.
/*/
User Function NUVMOCK(cIdPedido)
	Local oNuvPed := NuvemPedido():New()
	Default cIdPedido := "2082712287"
	If oNuvPed:MockPedido(cIdPedido)
		MsgInfo("Pedido #" + cIdPedido + " gravado na VT1 com SUCESSO!" + CRLF + CRLF + ;
			"Iniciando a geracao de SC5/SC6 via esteira ECPEDIDO...", "Sucesso")
		U_NUVPEDSC5(cIdPedido)
	EndIf
	FreeObj(oNuvPed)
Return .T.
