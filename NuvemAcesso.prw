#INCLUDE "TOTVS.CH"
#INCLUDE "RESTFUL.CH"

/*/{Protheus.doc} NuvemAcesso
Classe base de integracao com a plataforma Nuvemshop (API REST unstable).
Responsavel pelo transporte HTTP, autenticacao OAuth 2.0 (Bearer Token permanente),
governanca de Rate Limit (Leaky Bucket 2 req/s) e logs unificados.

@author Claudio Guidi
@since 05/09/2026
@version 1.1
@project Integracao Nuvemshop - TOTVS Protheus
/*/
CLASS NuvemAcesso FROM SchedAcesso

	DATA cURLBase       AS CHARACTER
	DATA cAccessToken   AS CHARACTER
	DATA cStoreId       AS CHARACTER
	DATA cAppId         AS CHARACTER
	DATA cUserAgent     AS CHARACTER
	DATA aHeadStr       AS ARRAY
	DATA nRateLimitWait AS NUMERIC
	DATA cLastResult    AS CHARACTER
	DATA nLastStatus    AS NUMERIC
	DATA aMsgErro       AS ARRAY

	METHOD New() CONSTRUCTOR
	METHOD ConfigCredentials(cFil)
	METHOD ExecuteRest(cPath, cMethod, cBody, aCustomHeaders)
	METHOD CheckRateLimit(oRest)
	METHOD GetStoreId()
	METHOD GetToken()
	METHOD GetLastError()
	METHOD Get(cPath, aCustomHeaders)
	METHOD Post(cPath, cBody, aCustomHeaders)
	METHOD Put(cPath, cBody, aCustomHeaders)
	METHOD Patch(cPath, cBody, aCustomHeaders)
	METHOD Delete(cPath, aCustomHeaders)
	METHOD SendMonitor(cMethod, cPath, nStatus, cBody, cResult)

ENDCLASS

/*/{Protheus.doc} New
Construtor da classe NuvemAcesso.
/*/
METHOD New() CLASS NuvemAcesso
	_Super:New()
	::cURLBase       := "https://api.nuvemshop.com.br/unstable"
	::cAccessToken   := ""
	::cStoreId       := ""
	::cAppId         := ""
	::cUserAgent     := ""
	::aHeadStr       := {}
	::nRateLimitWait := 500  // Pausa padrao de 500ms entre requisicoes para respeitar 2 req/s
	::cLastResult    := ""
	::nLastStatus    := 0
	::aMsgErro       := {}

	// Inicializa credenciais com base na filial corrente
	::ConfigCredentials(cFilAnt)
Return Self

/*/{Protheus.doc} ConfigCredentials
Le as credenciais da API NUVEMSHOP cadastradas na tabela VT8 ou parametros SX6.
O token gerado no Partner Portal da Nuvemshop e permanente e nao expira.
/*/
METHOD ConfigCredentials(cFil) CLASS NuvemAcesso
	Local cQuery    := ""
	Local cAliasQry := ""
	Local cCodVT8   := ""

	Default cFil := cFilAnt

	// 1. Tenta recuperar credenciais nas tabelas corporativas padrao da Fortbras (VT8 e VTN)
	If ChkFile("VT8")
		cAliasQry := GetNextAlias()
		cQuery := "SELECT VT8_CODIGO, VT8_CGC, VT8_MSBLQL "
		cQuery += " FROM " + RetSqlName("VT8") + " VT8 "
		cQuery += " WHERE VT8.D_E_L_E_T_ = ' ' "
		cQuery += "   AND (VT8.VT8_API = 'NUVEMSHOP' OR VT8.VT8_CODIGO = 'NUVEMSHOP') "
		cQuery += "   AND VT8.VT8_MSBLQL <> '1' "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

		If !(cAliasQry)->(Eof())
			cCodVT8 := AllTrim((cAliasQry)->VT8_CODIGO)
			// Se o VT8_CGC tiver ate 10 digitos, e o proprio Store ID. Se for CNPJ (14 digitos), busca do MV_NUVSTOR
			If !Empty((cAliasQry)->VT8_CGC) .And. Len(AllTrim((cAliasQry)->VT8_CGC)) <= 10
				::cStoreId := AllTrim((cAliasQry)->VT8_CGC)
			EndIf
		EndIf
		(cAliasQry)->(dbCloseArea())
	EndIf

	// Leitura do Cadastro de Ambientes / Credenciais (VTN) apenas se os campos customizados existirem
	If !Empty(cCodVT8) .And. ChkFile("VTN")
		DbSelectArea("VTN")
		If VTN->(FieldPos("VTN_TOKEN")) > 0 .Or. VTN->(FieldPos("VTN_STORE")) > 0
			cAliasQry := GetNextAlias()
			cQuery := "SELECT * "
			cQuery += " FROM " + RetSqlName("VTN") + " VTN "
			cQuery += " WHERE VTN.D_E_L_E_T_ = ' ' "
			cQuery += "   AND VTN.VTN_CODVT8 = '" + cCodVT8 + "' "
			cQuery += "   AND (VTN.VTN_FILIAL = '" + cFil + "' OR VTN.VTN_FILIAL = '" + xFilial("VTN") + "' OR VTN.VTN_FILIAL = ' ') "
			cQuery := ChangeQuery(cQuery)
			dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

			If !(cAliasQry)->(Eof())
				If (cAliasQry)->(FieldPos("VTN_TOKEN")) > 0 .And. !Empty((cAliasQry)->VTN_TOKEN)
					::cAccessToken := AllTrim((cAliasQry)->VTN_TOKEN)
				EndIf
				If (cAliasQry)->(FieldPos("VTN_APPID")) > 0 .And. !Empty((cAliasQry)->VTN_APPID)
					::cAppId := AllTrim((cAliasQry)->VTN_APPID)
				EndIf
				If (cAliasQry)->(FieldPos("VTN_STORE")) > 0 .And. !Empty((cAliasQry)->VTN_STORE) .And. Len(AllTrim((cAliasQry)->VTN_STORE)) <= 10
					::cStoreId := AllTrim((cAliasQry)->VTN_STORE)
				EndIf
			EndIf
			(cAliasQry)->(dbCloseArea())
		EndIf
	EndIf

	// 2. Fallback para Parametros SX6 (caso ainda nao cadastrado no VT8/VTN)
	If Empty(::cStoreId) .Or. ::cStoreId == "0" .Or. Len(::cStoreId) > 10
		::cStoreId := AllTrim(cValToChar(SuperGetMV("MV_NUVSTOR", .F., "8117213")))
	EndIf
	If Empty(::cStoreId) .Or. ::cStoreId == "0" .Or. Len(::cStoreId) > 10
		::cStoreId := "8117213"
	EndIf

	If Empty(::cAppId)
		::cAppId := AllTrim(cValToChar(SuperGetMV("MV_NUVAPP", .F., "9876")))
	EndIf
	If Empty(::cAppId)
		::cAppId := "9876"
	EndIf

	If Empty(::cAccessToken)
		::cAccessToken := AllTrim(cValToChar(SuperGetMV("MV_NUVTOK", .F., "1637dd9821cec89241d671a7307f6001c5450eb5")))
	EndIf

	// Auto-recuperacao: caso o SX6 esteja com os tokens legados (44ffe7a1... ou f9255da9...)
	If Empty(::cAccessToken) .Or. ::cAccessToken == "44ffe7a14117c3bdde82906080a810f477c6368d" .Or. ::cAccessToken == "f9255da9858fc4c00eb3c5a4078a6c86cc918e85"
		::cAccessToken := "1637dd9821cec89241d671a7307f6001c5450eb5"
		PutMV("MV_NUVTOK", ::cAccessToken)
	EndIf

	// Header User-Agent e OBRIGATORIO na Nuvemshop sob pena de retorno HTTP 400 Bad Request
	::cUserAgent := AllTrim(cValToChar(SuperGetMV("MV_NUVUAGT", .F., "VMS Services (dev@vmstech.co)")))
	If Empty(::cUserAgent)
		::cUserAgent := "VMS Services (dev@vmstech.co)"
	EndIf

	// Auto-correcao defensiva: se informado apenas o e-mail puro, encapsula no formato exigido NomeApp (email)
	If !Empty(::cUserAgent) .And. !("(" $ ::cUserAgent)
		::cUserAgent := "Fortbras Protheus (" + ::cUserAgent + ")"
	EndIf

	// URL base final direcionada para a loja na versao UNSTABLE (necessaria para Custom Objects e Custom Fields)
	::cURLBase := "https://api.nuvemshop.com.br/unstable/" + ::cStoreId

	ConOut("[NUVEMSHOP][CONFIG] Store ID: " + ::cStoreId + " | User-Agent: " + ::cUserAgent + " | Origem: " + Iif(!Empty(cCodVT8), "Tabela VT8/VTN", "Parametros SX6"))
Return .T.

/*/{Protheus.doc} ExecuteRest
Executa chamadas HTTP REST via FWRest com tratamento automatico de cabecalhos e Rate Limit.
/*/
METHOD ExecuteRest(cPath, cMethod, cBody, aCustomHeaders) CLASS NuvemAcesso
	Local oRest       := Nil
	Local cBaseHost   := "https://api.nuvemshop.com.br"
	Local cFullPath   := ""
	Local cFullURL    := ""
	Local aHeaders    := {}
	Local lSuccess    := .F.
	Local nRetry      := 0
	Local nMaxRetry   := 3
	Local nWaitReset  := 0
	Local nI          := 0
	Local cHeaderRet  := ""
	Local cResponse   := ""
	Local nPosHttp    := 0

	Default cMethod       := "GET"
	Default cBody         := ""
	Default aCustomHeaders:= {}

	// Garante que o path sempre inclua /unstable/{store_id} exigido pela API Nuvemshop
	If "/unstable/" $ cPath
		cFullPath := cPath
	Else
		cFullPath := "/unstable/" + ::cStoreId + IIf(Left(cPath, 1) == "/", cPath, "/" + cPath)
	EndIf

	cFullURL := cBaseHost + cFullPath

	// Montagem dos headers padroes (Nuvemshop exige Authentication: bearer)
	AAdd(aHeaders, "Authentication: bearer " + ::cAccessToken)
	AAdd(aHeaders, "Authorization: Bearer " + ::cAccessToken)
	AAdd(aHeaders, "User-Agent: " + ::cUserAgent)
	AAdd(aHeaders, "Content-Type: application/json; charset=utf-8")

	// Headers adicionais customizados
	For nI := 1 To Len(aCustomHeaders)
		AAdd(aHeaders, aCustomHeaders[nI])
	Next nI

	While nRetry < nMaxRetry .And. !lSuccess
		nRetry++
		oRest := FWRest():New(cBaseHost)
		oRest:setPath(cFullPath)

		Do Case
		Case Upper(cMethod) == "GET"
			lSuccess := oRest:Get(aHeaders)
		Case Upper(cMethod) == "POST"
			oRest:SetPostParams(cBody)
			lSuccess := oRest:Post(aHeaders, cBody)
		Case Upper(cMethod) == "PUT"
			oRest:SetPostParams(cBody)
			lSuccess := oRest:Put(aHeaders, cBody)
		Case Upper(cMethod) == "PATCH"
			// No FWRest o envio de PATCH utiliza metodo customizado ou Put com header de override
			AAdd(aHeaders, "X-HTTP-Method-Override: PATCH")
			oRest:SetPostParams(cBody)
			lSuccess := oRest:Put(aHeaders, cBody)
		Case Upper(cMethod) == "DELETE"
			lSuccess := oRest:Delete(aHeaders)
		EndCase

		::nLastStatus := Val(oRest:GetHTTPCode())
		::cLastResult := oRest:GetResult()

		If ::cLastResult == Nil
			::cLastResult := ""
		EndIf

		// Fallback para funcoes nativas HTTPSGet/HTTPSPost/HTTPSQuote (usadas pelo Protheus da Fortbras no xSantander)
		// Caso o FWRest falhe com status 0 por handshake SSL ou restricao de biblioteca interna no AppServer
		If ::nLastStatus == 0 .Or. Empty(::cLastResult)
			cHeaderRet := ""
			cResponse  := ""
			Do Case
			Case Upper(cMethod) == "GET"
				cResponse := HTTPSGet(cFullURL, "", "", "", "", 30, aHeaders, @cHeaderRet, .F.)
			Case Upper(cMethod) == "POST"
				cResponse := HTTPSPost(cFullURL, "", "", "", "", cBody, 30, aHeaders, @cHeaderRet, .F.)
			OtherWise
				cResponse := HTTPSQuote(cFullURL, "", "", "", Upper(cMethod), "", cBody, 30, aHeaders, @cHeaderRet)
			EndCase

			If !Empty(cHeaderRet)
				If "HTTP/" $ Upper(cHeaderRet)
					nPosHttp := At("HTTP/", Upper(cHeaderRet))
					::nLastStatus := Val(SubStr(cHeaderRet, nPosHttp + 9, 3))
				EndIf
				If !Empty(cResponse)
					::cLastResult := cResponse
				EndIf
				If ::nLastStatus >= 200 .And. ::nLastStatus < 300
					lSuccess := .T.
				EndIf
			EndIf
		EndIf

		If Empty(::cLastResult) .And. !Empty(oRest:GetLastError())
			::cLastResult := "Erro FWRest: " + oRest:GetLastError()
		EndIf

		ConOut("[NUVEMSHOP REST] " + cMethod + " " + cFullPath + " -> HTTP Status: " + cValToChar(::nLastStatus))
		If ::nLastStatus < 200 .Or. ::nLastStatus >= 300
			ConOut("[NUVEMSHOP ERRO RETORNO] " + SubStr(::cLastResult, 1, 300))
		EndIf

		// Log unificado da chamada Fortbras na tabela LOGINTAPI
		If FindFunction("U_FBAPILOG")
			U_FBAPILOG("NUVEMSHOP", cFullURL, IIf(::nLastStatus >= 200 .And. ::nLastStatus < 300, "T", "F"), Dtos(dDataBase), Time(), "NUV", cValToChar(cBody), cValToChar(::cLastResult), cEmpAnt, Funname())
		EndIf

		// Notificacao ao Monitor em Tempo Real (Vercel) se parametro MV_XURLMON estiver configurado
		::SendMonitor(cMethod, cFullURL, ::nLastStatus, cValToChar(cBody), cValToChar(::cLastResult))

		// Tratamento do Rate Limit HTTP 429 (Too Many Requests - Leaky Bucket)
		If ::nLastStatus == 429
			lSuccess := .F.
			nWaitReset := ::CheckRateLimit(oRest)
			ConOut("[NUVEMSHOP][RATE LIMIT 429] Limite atingido. Aguardando " + cValToChar(nWaitReset) + "ms para retry (" + cValToChar(nRetry) + "/" + cValToChar(nMaxRetry) + ")")
			Sleep(nWaitReset)
		ElseIf ::nLastStatus >= 200 .And. ::nLastStatus < 300
			lSuccess := .T.
			// Pequena pausa preventiva para manter ritmo <= 2 req/s
			Sleep(::nRateLimitWait)
		Else
			// Erro de requisicao (ex.: 404, 400, 422, 500)
			AAdd(::aMsgErro, "Erro Nuvemshop [" + cValToChar(::nLastStatus) + "]: " + cValToChar(::cLastResult))
			Exit
		EndIf

		FreeObj(oRest)
	EndDo

Return lSuccess

/*/{Protheus.doc} CheckRateLimit
Avalia os headers x-rate-limit-remaining e x-rate-limit-reset retornados pela Nuvemshop.
/*/
METHOD CheckRateLimit(oRest) CLASS NuvemAcesso
	Local cHeaderReset := oRest:GetHeader("x-rate-limit-reset")
	Local nWaitMs      := 1000

	If !Empty(cHeaderReset)
		nWaitMs := Val(cHeaderReset) + 200 // Margem de seguranca de 200ms
	Else
		nWaitMs := 1500
	EndIf
Return nWaitMs

METHOD GetStoreId() CLASS NuvemAcesso
Return ::cStoreId

METHOD GetToken() CLASS NuvemAcesso
Return ::cAccessToken

METHOD GetLastError() CLASS NuvemAcesso
	Local cErro := ""
	If Len(::aMsgErro) > 0
		cErro := ::aMsgErro[Len(::aMsgErro)]
	ElseIf !Empty(::cLastResult) .And. (::nLastStatus < 200 .Or. ::nLastStatus >= 300)
		cErro := "[" + cValToChar(::nLastStatus) + "] " + ::cLastResult
	EndIf
Return cErro

METHOD Get(cPath, aCustomHeaders) CLASS NuvemAcesso
Return ::ExecuteRest(cPath, "GET", "", aCustomHeaders)

METHOD Post(cPath, cBody, aCustomHeaders) CLASS NuvemAcesso
Return ::ExecuteRest(cPath, "POST", cBody, aCustomHeaders)

METHOD Put(cPath, cBody, aCustomHeaders) CLASS NuvemAcesso
Return ::ExecuteRest(cPath, "PUT", cBody, aCustomHeaders)

METHOD Patch(cPath, cBody, aCustomHeaders) CLASS NuvemAcesso
Return ::ExecuteRest(cPath, "PATCH", cBody, aCustomHeaders)

METHOD Delete(cPath, aCustomHeaders) CLASS NuvemAcesso
Return ::ExecuteRest(cPath, "DELETE", "", aCustomHeaders)

/*/{Protheus.doc} SendMonitor
Disparo assincrono e seguro de eventos para a Torre de Controle (Monitor Vercel).
Ativado apenas quando o parametro MV_XURLMON contiver a URL da API (ex: https://monitor.vercel.app/api/events).
/*/
METHOD SendMonitor(cMethod, cPath, nStatus, cBody, cResult) CLASS NuvemAcesso
	Local cUrlMon   := ""
	Local oRestMon  := Nil
	Local aHeadMon  := {}
	Local oJsonMon  := Nil
	Local cBodyMon  := ""
	Local cBaseUrl  := ""
	Local cPathMon  := "/api/events"

	If FindFunction("SuperGetMv")
		cUrlMon := SuperGetMv("MV_XURLMON", .F., "")
	EndIf

	If Empty(cUrlMon)
		Return .T.
	EndIf

	oJsonMon := JsonObject():New()
	oJsonMon["source"] := "PROTHEUS"
	oJsonMon["eventType"] := IIf("stock-price" $ Lower(cPath), "ESTOQUE_PRECO_LOTE", IIf("orders" $ Lower(cPath), "PEDIDO_VENDA", IIf("products" $ Lower(cPath), "CATALOGO_PRODUTO", "OUTROS")))
	oJsonMon["status"] := IIf(nStatus >= 200 .And. nStatus < 300, "SUCCESS", IIf(nStatus == 429, "WARNING", "ERROR"))
	oJsonMon["httpStatus"] := nStatus
	oJsonMon["filial"] := cFilAnt
	oJsonMon["summary"] := "[" + cMethod + "] " + cPath + " -> " + cValToChar(nStatus)
	oJsonMon["details"] := IIf(nStatus >= 200 .And. nStatus < 300, "Integracao Protheus executada com sucesso.", "Falha na chamada da API: " + SubStr(cResult, 1, 250))
	cBodyMon := oJsonMon:ToJson()

	If "/api/events" $ Lower(cUrlMon)
		cBaseUrl := SubStr(cUrlMon, 1, At("/api/events", Lower(cUrlMon)) - 1)
	Else
		cBaseUrl := cUrlMon
	EndIf

	If SubStr(cBaseUrl, Len(cBaseUrl), 1) == "/"
		cBaseUrl := SubStr(cBaseUrl, 1, Len(cBaseUrl) - 1)
	EndIf

	AAdd(aHeadMon, "Content-Type: application/json")
	oRestMon := FWRest():New(cBaseUrl)
	oRestMon:SetPath(cPathMon)
	oRestMon:SetPostParams(cBodyMon)
	oRestMon:Post(aHeadMon)

	FreeObj(oRestMon)
	FreeObj(oJsonMon)
Return .T.

