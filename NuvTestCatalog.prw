#INCLUDE "TOTVS.CH"

/*/{Protheus.doc} NuvTestCatalog
Funcao executavel via SmartClient (U_NuvTestCatalog) para testes e homologacao
da esteira de catalogo e produtos Nuvemshop no Protheus da Fortbras.

Testes disponiveis:
1. Consulta de SKU existente na Nuvemshop (Idempotencia via GET /products/sku/{sku})
2. Visualizacao dos dados Protheus coletados para integracao (SB1, SB5, Z08, ECOMMERCE_PRODWEB)
3. Exportacao pontual de um produto para a Nuvemshop (POST/PUT + Custom Fields)
4. Sincronizacao de lote de Estoque/Preco via fila VTF (PATCH /products/stock-price)
5. Enfileirar produto de teste na fila VTF (Simula evento de alteracao)

@author Claudio Guidi
@since 10/09/2026
@version 1.0
@project Integracao Nuvemshop - TOTVS Protheus
/*/
User Function NuvTestCatalog()
	Local oProd     := Nil
	Local nOpcao    := 0
	Local cSku      := "340684"
	Local cCodProd  := "104319"
	Local oJsonSku  := Nil
	Local oData     := Nil
	Local cMsg      := ""
	Local lOk       := .F.
	Local oDlg      := Nil
	Local oBtn1     := Nil
	Local oBtn2     := Nil
	Local oBtn3     := Nil
	Local oBtn4     := Nil
	Local oBtn5     := Nil
	Local oBtn6     := Nil
	Local oBtnSair  := Nil
	Local nI        := 0
	Local nJ        := 0
	Local cValField := ""
	Local cUrlMon   := ""

	// Inicializa a classe de produtos Nuvemshop
	oProd := NuvemProduto():New()

	// Valida credenciais minimas
	If Empty(oProd:cStoreId) .Or. Empty(oProd:cAccessToken)
		cMsg := "Credenciais nao configuradas no Protheus!" + CRLF + CRLF
		cMsg += "Store ID (VT8_CGC ou MV_NUVSTOR): " + IIf(Empty(oProd:cStoreId), "VAZIO", oProd:cStoreId) + CRLF
		cMsg += "Token (MV_NUVTOK): " + IIf(Empty(oProd:cAccessToken), "VAZIO (configure no SX6)", "CONFIGURADO") + CRLF
		cMsg += "User-Agent: " + oProd:cUserAgent + CRLF
		cMsg += "Base URL: " + oProd:cURLBase
		MsgStop(cMsg, "Teste Catalogo Nuvemshop - Configuracao")
		FreeObj(oProd)
		Return .F.
	EndIf

	DEFINE MSDIALOG oDlg TITLE "Testes Nuvemshop - Fortbras" FROM 0, 0 TO 350, 460 PIXEL

	@ 010, 015 SAY "Selecione o teste de catalogo Nuvemshop desejado:" SIZE 200, 10 PIXEL OF oDlg

	@ 025, 015 BUTTON oBtn1 PROMPT "1. Consultar SKU na Nuvemshop (GET /products/sku)" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 1, oDlg:End())
	@ 048, 015 BUTTON oBtn2 PROMPT "2. Visualizar Dados Protheus Coletados (SB1, SB5, Z08)" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 2, oDlg:End())
	@ 071, 015 BUTTON oBtn3 PROMPT "3. Exportar Produto Piloto para Nuvemshop" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 3, oDlg:End())
	@ 094, 015 BUTTON oBtn4 PROMPT "4. Executar Sincronizacao de Estoque/Preco (Fila VTF)" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 4, oDlg:End())
	@ 117, 015 BUTTON oBtn5 PROMPT "5. Enfileirar Produto na VTF (Simular Mudanca de Saldo)" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 5, oDlg:End())
	@ 140, 015 BUTTON oBtn6 PROMPT "6. Disparar Evento ao Painel de Monitoramento (MV_XURLMON)" SIZE 200, 18 PIXEL OF oDlg ACTION (nOpcao := 6, oDlg:End())

	@ 165, 150 BUTTON oBtnSair PROMPT "Cancelar / Fechar" SIZE 65, 13 PIXEL OF oDlg ACTION (nOpcao := 0, oDlg:End())

	ACTIVATE MSDIALOG oDlg CENTERED

	If nOpcao == 0
		FreeObj(oProd)
		Return .F.
	EndIf

	Do Case
	Case nOpcao == 1
		// 1. Consulta SKU na Nuvemshop
		cSku := AllTrim(FWInputBox("Informe o SKU para consulta na Nuvemshop:", "340684"))
		If Empty(cSku)
			cSku := "340684"
		EndIf

		ConOut("[NUVEMSHOP TESTE] Consultando SKU: " + AllTrim(cSku))
		oJsonSku := oProd:CheckSku(AllTrim(cSku))

		If oJsonSku != Nil
			cMsg := "SKU ENCONTRADO NA NUVEMSHOP!" + CRLF + CRLF
			cMsg += "Produto ID: " + cValToChar(oJsonSku["id"]) + CRLF
			If ValType(oJsonSku["name"]) == "J"
				cMsg += "Nome: " + cValToChar(oJsonSku["name"]["pt"]) + CRLF
			Else
				cMsg += "Nome: " + cValToChar(oJsonSku["name"]) + CRLF
			EndIf
			If ValType(oJsonSku["variants"]) == "A" .And. Len(oJsonSku["variants"]) > 0
				cMsg += "Variante ID: " + cValToChar(oJsonSku["variants"][1]["id"]) + CRLF
				cMsg += "Preco: R$ " + cValToChar(oJsonSku["variants"][1]["price"]) + CRLF
				cMsg += "Estoque: " + cValToChar(oJsonSku["variants"][1]["stock"]) + CRLF
			EndIf
			MsgInfo(cMsg, "Sucesso - SKU Existente")
			FreeObj(oJsonSku)
		Else
			If oProd:nLastStatus == 404
				MsgInfo("SKU [" + AllTrim(cSku) + "] NAO existe na Nuvemshop (HTTP 404)." + CRLF + "Pode ser criado via POST /products.", "SKU Inexistente")
			Else
				MsgAlert("Erro ao consultar SKU: [" + cValToChar(oProd:nLastStatus) + "] " + oProd:GetLastError(), "Alerta")
			EndIf
		EndIf

	Case nOpcao == 2
		// 2. Visualizar Dados Protheus
		cCodProd := AllTrim(FWInputBox("Informe o codigo do produto (SB1):", "104319"))
		If Empty(cCodProd)
			cCodProd := "104319"
		EndIf

		oData := oProd:GetDadosProd(AllTrim(cCodProd))
		If oData != Nil
			cMsg := "DADOS COLETADOS NO PROTHEUS:" + CRLF + CRLF
			cMsg += "Codigo: " + cValToChar(oData["codigo"]) + CRLF
			cMsg += "SKU / RefId: " + cValToChar(oData["ref_id"]) + CRLF
			cMsg += "Nome: " + cValToChar(oData["nome"]) + CRLF
			cMsg += "Categoria: " + cValToChar(oData["categoria"]) + " (Grupo: " + cValToChar(oData["grupo"]) + ")" + CRLF
			cMsg += "Marca: " + cValToChar(oData["marca"]) + CRLF
			cMsg += "Preco: R$ " + Transform(oData["preco"], "@E 999,999.99") + CRLF
			cMsg += "Estoque: " + cValToChar(oData["estoque"]) + CRLF
			cMsg += "Peso: " + Transform(oData["peso"], "@E 999.999") + " kg" + CRLF
			cMsg += "Dimensoes: " + cValToChar(oData["altura"]) + "x" + cValToChar(oData["largura"]) + "x" + cValToChar(oData["comprimento"]) + " cm" + CRLF
			cMsg += "Fotos encontradas: " + cValToChar(Len(oData["imagens"])) + CRLF
			If Len(oData["imagens"]) > 0
				For nI := 1 To Len(oData["imagens"])
					cMsg += "   -> Foto " + cValToChar(nI) + ": " + oData["imagens"][nI] + CRLF
				Next nI
			EndIf
			cMsg += CRLF
			cMsg += "Custom Fields (" + cValToChar(Len(oData["custom_fields"])) + " atributos veiculares/tecnicos):" + CRLF
			For nI := 1 To Len(oData["custom_fields"])
				cValField := ""
				If ValType(oData["custom_fields"][nI][2]) == "A"
					For nJ := 1 To Len(oData["custom_fields"][nI][2])
						cValField += cValToChar(oData["custom_fields"][nI][2][nJ]) + IIf(nJ < Len(oData["custom_fields"][nI][2]), ", ", "")
					Next nJ
				Else
					cValField := cValToChar(oData["custom_fields"][nI][2])
				EndIf
				cMsg += " - " + cValToChar(oData["custom_fields"][nI][1]) + ": " + cValField + CRLF
			Next nI
			MsgInfo(cMsg, "Dados Protheus - " + AllTrim(cCodProd))
			FreeObj(oData)
		Else
			MsgStop("Produto [" + AllTrim(cCodProd) + "] nao localizado na tabela SB1 do Protheus.", "Erro")
		EndIf

	Case nOpcao == 3
		// 3. Exportar Produto Piloto
		cCodProd := AllTrim(FWInputBox("Informe o codigo do produto para EXPORTAR:", "104319"))
		If Empty(cCodProd)
			cCodProd := "104319"
		EndIf

		If MsgYesNo("Deseja realmente exportar o produto [" + AllTrim(cCodProd) + "] para a loja Nuvemshop " + oProd:cStoreId + "?", "Confirmacao de Exportacao")
			ConOut("[NUVEMSHOP TESTE] Exportando produto: " + AllTrim(cCodProd))
			lOk := oProd:ExportProduct(AllTrim(cCodProd))
			If lOk
				oData := oProd:GetDadosProd(AllTrim(cCodProd))
				cMsg := "PRODUTO EXPORTADO COM SUCESSO!" + CRLF + CRLF
				cMsg += "Codigo Protheus: " + AllTrim(cCodProd) + CRLF
				cMsg += "ID Nuvemshop: " + oProd:GetProductId(AllTrim(cCodProd)) + CRLF
				cMsg += "Variante ID: " + oProd:GetVariantId(AllTrim(cCodProd)) + CRLF + CRLF
				If oData != Nil
					cMsg += "Nome: " + AllTrim(oData["nome"]) + CRLF
					cMsg += "Categoria: " + AllTrim(oData["categoria"]) + CRLF
					cMsg += "Preco enviado: R$ " + Transform(oData["preco"], "@E 999,999.99") + CRLF
					cMsg += "Estoque enviado: " + cValToChar(oData["estoque"]) + CRLF
					cMsg += "Peso enviado: " + Transform(oData["peso"], "@E 999.999") + " kg" + CRLF
					cMsg += "Fotos encontradas: " + cValToChar(Len(oData["imagens"])) + CRLF
					FreeObj(oData)
				EndIf
				cMsg += CRLF + "Vinculo gravado com sucesso nas tabelas VT9 e VTD do Protheus."
				MsgInfo(cMsg, "Sucesso Nuvemshop")
			Else
				MsgStop("Falha ao exportar produto: " + oProd:GetLastError(), "Erro de Exportacao")
			EndIf
		EndIf

	Case nOpcao == 4
		// 4. Sincronizar Fila VTF
		If MsgYesNo("Deseja executar a sincronizacao de precos e estoques pendentes da fila VTF?", "Sincronizacao VTF")
			lOk := oProd:UpdtAtuWeb()
			If lOk
				MsgInfo("Sincronizacao da fila VTF executada!" + CRLF + CRLF + "Dica: Para testar um produto nesta fila, utilize primeiro a Opcao 5 para enfileirar o produto e depois clique na Opcao 4.", "Sucesso Fila VTF")
			Else
				MsgAlert("Processamento finalizado com alertas. Verifique o console.", "Alerta")
			EndIf
		EndIf

	Case nOpcao == 5
		// 5. Enfileirar Produto na VTF para teste
		cCodProd := AllTrim(FWInputBox("Informe o codigo do produto para ENFILEIRAR na VTF:", "104319"))
		If Empty(cCodProd)
			cCodProd := "104319"
		EndIf

		DbSelectArea("VTF")
		RecLock("VTF", .T.)
		VTF->VTF_FILIAL := xFilial("VTF")
		VTF->VTF_PRODUT := cCodProd
		VTF->VTF_API    := "NUVEMSHOP"
		VTF->VTF_ATUWEB := "S"
		If VTF->(FieldPos("VTF_CODVT8")) > 0
			VTF->VTF_CODVT8 := AvKey("NUVEMSHOP", "VTF_CODVT8")
		EndIf
		If VTF->(FieldPos("VTF_CODVTN")) > 0
			VTF->VTF_CODVTN := AvKey("DEFAULT", "VTF_CODVTN")
		EndIf
		VTF->(MsUnlock())

		MsgInfo("Produto [" + AllTrim(cCodProd) + "] enfileirado na VTF com sucesso!" + CRLF + CRLF + "Status: VTF_ATUWEB = 'S'" + CRLF + "Destino: VTF_API = 'NUVEMSHOP'" + CRLF + CRLF + "Agora clique na Opcao 4 para sincronizar!", "Fila VTF Atualizada")

	Case nOpcao == 6
		// 6. Teste de Notificacao ao Painel de Monitoramento (Torre de Controle)
		cUrlMon := SuperGetMv("MV_XURLMON", .F., "https://toat-fortbras.vercel.app/api/events")
		cUrlMon := AllTrim(FWInputBox("Informe o endpoint da Torre de Controle (Monitor Web):", cUrlMon))
		If !Empty(cUrlMon)
			ConOut("[NUVEMSHOP TESTE] Disparando evento de teste para o monitor: " + cUrlMon)
			oProd:SendMonitor("POST", "/products/ping-test", 200, '{"ping": true, "sku": "1043190"}', '{"status": "SUCCESS", "message": "Ping do Protheus recebido"}')
			MsgInfo("Evento de teste enviado com sucesso para o Painel Web!" + CRLF + CRLF + "Endpoint: " + cUrlMon + CRLF + "Acesse https://toat-fortbras.vercel.app no navegador para ver o feed de eventos em tempo real.", "Monitor Web Notificado")
		EndIf
	EndCase

	FreeObj(oProd)
Return .T.
