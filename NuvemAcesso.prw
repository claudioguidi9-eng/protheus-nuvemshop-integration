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
	Local cAliasVT8 := GetNextAlias()

	Default cFil := cFilAnt

	cQuery := "SELECT VT8_CODIGO, VT8_CGC, VT8_MSBLQL "
	cQuery += " FROM " + RetSqlName("VT8") + " VT8 "
	cQuery += " WHERE VT8.D_E_L_E_T_ = ' ' "
	cQuery += "   AND VT8.VT8_API = 'NUVEMSHOP' "
	cQuery += "   AND VT8.VT8_MSBLQL <> '1' "

	cQuery := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasVT8, .F., .T.)

	// 1. Parametro MV_NUVSTOR e prioritario para definir o Store ID da Nuvemshop
	::cStoreId := AllTrim(cValToChar(SuperGetMV("MV_NUVSTOR", .F., "8117213")))

	// 2. Se vazio ou zerado no parametro, tenta recuperar da tabela VT8
	If Empty(::cStoreId) .Or. ::cStoreId == "0"
		cQuery := "SELECT VT8_CODIGO, VT8_CGC, VT8_MSBLQL "
		cQuery += " FROM " + RetSqlName("VT8") + " VT8 "
		cQuery += " WHERE VT8.D_E_L_E_T_ = ' ' "
		cQuery += "   AND VT8.VT8_API = 'NUVEMSHOP' "
		cQuery += "   AND VT8.VT8_MSBLQL <> '1' "

		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasVT8, .F., .T.)

		If !(cAliasVT8)->(Eof()) .And. !Empty((cAliasVT8)->VT8_CGC)
			::cStoreId := AllTrim((cAliasVT8)->VT8_CGC)
		EndIf
		(cAliasVT8)->(dbCloseArea())
	EndIf

	// 3. Fallback definitivo se ainda vazio: Store ID 8117213 (demofortbras)
	If Empty(::cStoreId) .Or. ::cStoreId == "0"
		::cStoreId := "8117213"
	EndIf

	// Recupera App ID, Access Token e User-Agent via parametros SuperGetMV
	::cAppId := AllTrim(cValToChar(SuperGetMV("MV_NUVAPP", .F., "9876")))
	If Empty(::cAppId)
		::cAppId := "9876"
	EndIf

	::cAccessToken := AllTrim(cValToChar(SuperGetMV("MV_NUVTOK", .F., "44ffe7a14117c3bdde82906080a810f477c6368d")))
	If Empty(::cAccessToken)
		::cAccessToken := "44ffe7a14117c3bdde82906080a810f477c6368d"
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

	ConOut("[NUVEMSHOP][CONFIG] Store ID: " + ::cStoreId + " | User-Agent: " + ::cUserAgent)
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
			AAdd(::aMsgErro, "Erro Nuvemshop [" + cValToChar(::nLastStatus) + "]: " + ::cLastResult)
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

