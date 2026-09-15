#INCLUDE "TOTVS.CH"

/*/{Protheus.doc} TestNuvCon
Funcao executavel via SmartClient (U_TestNuvCon) para validar
a conectividade, autenticacao e resposta da API Nuvemshop.

@author Claudio Guidi
@since 06/09/2026
@version 1.1
/*/
User Function TestNuvCon()
	Local oAcesso   := Nil
	Local cJsonRes  := ""
	Local oJson     := Nil
	Local cLojaNome := ""
	Local cMsg      := ""
	Local lOk       := .F.

	ConOut("[TESTE NUVEMSHOP] Iniciando teste de conexao com Nuvemshop...")

	// Instancia classe base de comunicacao
	oAcesso := NuvemAcesso():New()

	// Valida credenciais basicas configuradas no SX6 / VT8
	If Empty(oAcesso:cAccessToken) .Or. Empty(oAcesso:cStoreId)
		cMsg := "Credenciais nao configuradas no Protheus!" + CRLF + CRLF
		cMsg += "Store ID (VT8_CGC ou MV_NUVSTOR): " + IIf(Empty(oAcesso:cStoreId), "VAZIO (configure na VT8)", oAcesso:cStoreId) + CRLF
		cMsg += "Token (MV_NUVTOK): " + IIf(Empty(oAcesso:cAccessToken), "VAZIO (configure no SX6)", "CONFIGURADO") + CRLF
		cMsg += "App ID (MV_NUVAPP): " + IIf(Empty(oAcesso:cAppId), "VAZIO", oAcesso:cAppId) + CRLF
		cMsg += "User-Agent: " + oAcesso:cUserAgent + CRLF
		cMsg += "Base URL: " + oAcesso:cURLBase
		MsgStop(cMsg, "Teste Nuvemshop - Erro de Configuracao")
		FreeObj(oAcesso)
		Return .F.
	EndIf

	// Executa requisicao GET para listar produtos na API unstable da loja: /unstable/{store_id}/products?limit=1
	lOk := oAcesso:Get("/products?limit=1")
	cJsonRes := oAcesso:cLastResult

	If lOk .And. oAcesso:nLastStatus == 200
		oJson := JsonObject():New()
		If oJson:FromJson(cJsonRes) == Nil
			aProdList := {}
			If ValType(oJson:GetJsonObject()) == "A"
				aProdList := oJson:GetJsonObject()
			ElseIf ValType(oJson) == "A"
				aProdList := oJson
			EndIf

			If Len(aProdList) > 0
				If ValType(aProdList[1]["name"]) == "J"
					cLojaNome := aProdList[1]["name"]["pt"]
				ElseIf ValType(aProdList[1]["name"]) == "C"
					cLojaNome := aProdList[1]["name"]
				EndIf
			EndIf

			If Empty(cLojaNome)
				cLojaNome := "Catalogo Nuvemshop Conectado"
			EndIf

			cMsg := "Conexao com a Nuvemshop realizada com SUCESSO!" + CRLF + CRLF
			cMsg += "Status HTTP: 200 OK" + CRLF
			cMsg += "Loja / Catalogo: " + cLojaNome + CRLF
			cMsg += "Store ID: " + oAcesso:cStoreId + CRLF
			cMsg += "User-Agent: " + oAcesso:cUserAgent + CRLF + CRLF
			cMsg += "A esteira Protheus esta autorizada e comunicando perfeitamente."

			MsgInfo(cMsg, "Sucesso - Conexao Nuvemshop")
			ConOut("[TESTE NUVEMSHOP] Sucesso: Loja " + cLojaNome)
			FreeObj(oJson)
		Else
			MsgAlert("Conexao estabelecida, mas o retorno JSON nao pode ser interpretado." + CRLF + cJsonRes, "Alerta")
		EndIf
	Else
		cMsg := "Falha na conexao com a Nuvemshop!" + CRLF + CRLF
		cMsg += "Status HTTP: " + cValToChar(oAcesso:nLastStatus) + CRLF
		cMsg += "Erro retornado: " + oAcesso:GetLastError() + CRLF + CRLF
		cMsg += "Checklist de Verificacao:" + CRLF
		cMsg += "1. O token em MV_NUVTOK esta correto e ativo na Nuvemshop?" + CRLF
		cMsg += "2. O Store ID confere com o ID da loja (padrao 8117213)?" + CRLF
		cMsg += "3. O servidor Protheus possui saida HTTPS para api.nuvemshop.com.br?"

		MsgStop(cMsg, "Falha de Conexao - Nuvemshop")
		ConOut("[TESTE NUVEMSHOP] Erro: " + oAcesso:GetLastError())
	EndIf

	FreeObj(oAcesso)
Return .T.
