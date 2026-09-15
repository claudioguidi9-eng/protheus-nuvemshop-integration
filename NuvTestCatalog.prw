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
	Local oBtn7     := Nil
	Local oBtn8     := Nil
	Local oBtn9     := Nil
	Local oBtnSair  := Nil
	Local nI        := 0
	Local nJ        := 0
	Local cValField := ""
	Local cUrlMon   := ""
	Local oRes      := Nil
	Local cMsgPrompt:= ""
	Local cFilEcom  := ""
	Local cFlagB2C  := ""

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

	DEFINE MSDIALOG oDlg TITLE "Testes Nuvemshop - Fortbras" FROM 0, 0 TO 450, 500 PIXEL

	@ 010, 015 SAY "Selecione o teste de integracao Nuvemshop desejado:" SIZE 230, 10 PIXEL OF oDlg

	@ 025, 015 BUTTON oBtn1 PROMPT "1. Consultar SKU na Nuvemshop (GET /products/sku)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 1, oDlg:End())
	@ 043, 015 BUTTON oBtn2 PROMPT "2. Visualizar Dados Protheus Coletados (SB1, SB5, Z08, SBZ)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 2, oDlg:End())
	@ 061, 015 BUTTON oBtn3 PROMPT "3. Exportar Produto Piloto (Carga Completa Protheus)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 3, oDlg:End())
	@ 079, 015 BUTTON oBtn4 PROMPT "4. Executar Sincronizacao Fila VTF (Auto-bind por SKU)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 4, oDlg:End())
	@ 097, 015 BUTTON oBtn5 PROMPT "5. Enfileirar Produto na VTF (Simular Mudanca de Saldo)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 5, oDlg:End())
	@ 115, 015 BUTTON oBtn6 PROMPT "6. Disparar Evento ao Painel de Monitoramento (MV_XURLMON)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 6, oDlg:End())
	@ 133, 015 BUTTON oBtn7 PROMPT "7. Carga Total de Catalogo B2C (SBZ->BZ_YB2C = 'S')" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 7, oDlg:End())
	@ 151, 015 BUTTON oBtn8 PROMPT "8. Sincronizar Estoque/Preco por SKU (Match VTEX)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 8, oDlg:End())
	@ 169, 015 BUTTON oBtn9 PROMPT "9. Sincronizacao em Lote Estoque/Preco B2C (Match VTEX)" SIZE 225, 15 PIXEL OF oDlg ACTION (nOpcao := 9, oDlg:End())

	@ 194, 175 BUTTON oBtnSair PROMPT "Cancelar / Fechar" SIZE 65, 14 PIXEL OF oDlg ACTION (nOpcao := 0, oDlg:End())

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

		// Verifica flag B2C na SBZ
		cFilEcom := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
		cFlagB2C := "N"
		If ChkFile("SBZ")
			DbSelectArea("SBZ")
			SBZ->(DbSetOrder(1))
			If SBZ->(DbSeek(cFilEcom + cCodProd)) .Or. ;
			   SBZ->(DbSeek(SubStr(cFilEcom, 1, 4) + cCodProd)) .Or. ;
			   SBZ->(DbSeek(xFilial("SBZ") + cCodProd))
				If SBZ->(FieldPos("BZ_YB2C")) > 0
					cFlagB2C := Upper(AllTrim(SBZ->BZ_YB2C))
				EndIf
			EndIf
		EndIf

		oData := oProd:GetDadosProd(AllTrim(cCodProd))
		If oData != Nil
			cMsg := "DADOS COLETADOS NO PROTHEUS:" + CRLF + CRLF
			cMsg += "Codigo: " + cValToChar(oData["codigo"]) + CRLF
			cMsg += "Aprovado B2C (SBZ->BZ_YB2C): " + cFlagB2C + IIf(cFlagB2C == "S", " (SIM - Elegivel Nuvemshop)", " (NAO - Bloqueado p/ B2C)") + CRLF
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

		// Valida BZ_YB2C
		cFilEcom := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
		cFlagB2C := "N"
		If ChkFile("SBZ")
			DbSelectArea("SBZ")
			SBZ->(DbSetOrder(1))
			If SBZ->(DbSeek(cFilEcom + cCodProd)) .Or. ;
			   SBZ->(DbSeek(SubStr(cFilEcom, 1, 4) + cCodProd)) .Or. ;
			   SBZ->(DbSeek(xFilial("SBZ") + cCodProd))
				If SBZ->(FieldPos("BZ_YB2C")) > 0
					cFlagB2C := Upper(AllTrim(SBZ->BZ_YB2C))
				EndIf
			EndIf
		EndIf

		If cFlagB2C != "S"
			If !MsgYesNo("AVISO: O produto [" + AllTrim(cCodProd) + "] esta com BZ_YB2C = '" + cFlagB2C + "' na filial " + cFilEcom + "." + CRLF + CRLF + ;
			             "Pela regra de negocio, apenas produtos com BZ_YB2C = 'S' sobem para a Nuvemshop." + CRLF + CRLF + ;
			             "Deseja exportar mesmo assim para este teste piloto?", "Validacao B2C (SBZ->BZ_YB2C)")
				FreeObj(oProd)
				Return .F.
			EndIf
		EndIf

		If MsgYesNo("Deseja realmente exportar o produto [" + AllTrim(cCodProd) + "] para a loja Nuvemshop " + oProd:cStoreId + "?", "Confirmacao de Exportacao")
			ConOut("[NUVEMSHOP TESTE] Exportando produto: " + AllTrim(cCodProd))
			lOk := oProd:ExportProduct(AllTrim(cCodProd), .T.)
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

	Case nOpcao == 7
		// 7. Carga Total de Produtos B2C (SBZ->BZ_YB2C = 'S')
		cFilEcom := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
		cFilEcom := AllTrim(FWInputBox("Informe a Filial de Estoque/Preco (SBZ):", cFilEcom))
		If Empty(cFilEcom)
			cFilEcom := "03150001"
		EndIf

		cMsgPrompt := "CONFIRMACAO DE CARGA EM LOTE B2C" + CRLF + CRLF
		cMsgPrompt += "Filial selecionada: " + cFilEcom + CRLF
		cMsgPrompt += "Regra de Filtro: SBZ.BZ_YB2C = 'S' e SB1.B1_MSBLQL != '1'" + CRLF
		cMsgPrompt += "Loja Nuvemshop: " + oProd:cStoreId + CRLF + CRLF
		cMsgPrompt += "Esta operacao ira consultar todos os produtos homologados B2C da filial," + CRLF
		cMsgPrompt += "enviar precos, saldos, fotos e atributos veiculares a Nuvemshop." + CRLF + CRLF
		cMsgPrompt += "Deseja iniciar a carga agora?"

		If MsgYesNo(cMsgPrompt, "Carga Total de Catalogo Nuvemshop")
			oRes := Nil
			Processa({|lEnd| ;
				oRes := oProd:ExportAllB2C(cFilEcom, {|nAtual, nTotal, cCod, lOkProd, cErr| ;
					ProcRegua(nTotal), ;
					IncProc("Processando " + cValToChar(nAtual) + "/" + cValToChar(nTotal) + ": Produto " + cCod) ;
				}) ;
			}, "Carga Total B2C Nuvemshop", "Localizando e enviando produtos...", .F.)

			If oRes != Nil
				cMsg := "CARGA TOTAL B2C FINALIZADA!" + CRLF + CRLF
				cMsg += "Filial: " + cFilEcom + CRLF
				cMsg += "Total de produtos B2C identificados: " + cValToChar(oRes["total"]) + CRLF
				cMsg += "Sucesso (Cadastrados/Atualizados): " + cValToChar(oRes["sucessos"]) + CRLF
				cMsg += "Erros / Falhas: " + cValToChar(oRes["erros"]) + CRLF

				If oRes["erros"] > 0 .And. ValType(oRes["falhas"]) == "A" .And. Len(oRes["falhas"]) > 0
					cMsg += CRLF + "Primeiras falhas encontradas:" + CRLF
					For nI := 1 To Min(5, Len(oRes["falhas"]))
						cMsg += " - Produto " + oRes["falhas"][nI][1] + ": " + oRes["falhas"][nI][2] + CRLF
					Next nI
					If Len(oRes["falhas"]) > 5
						cMsg += " ... e mais " + cValToChar(Len(oRes["falhas"]) - 5) + " produto(s). Verifique o console." + CRLF
					EndIf
					MsgAlert(cMsg, "Carga B2C Finalizada com Alertas")
				Else
					MsgInfo(cMsg, "Carga B2C Nuvemshop com Sucesso")
				EndIf
				FreeObj(oRes)
			EndIf
		EndIf

	Case nOpcao == 8
		// 8. Sincronizar Estoque/Preco por SKU (Match Catalogo VTEX)
		cCodProd := AllTrim(FWInputBox("Informe o codigo do produto (SKU VTEX) para sincronizar:", "104319"))
		If Empty(cCodProd)
			cCodProd := "104319"
		EndIf

		ConOut("[NUVEMSHOP TESTE] Sincronizando estoque e preco por SKU: " + AllTrim(cCodProd))
		lOk := oProd:SyncStockPrice(AllTrim(cCodProd))

		If lOk
			oData := oProd:GetDadosProd(AllTrim(cCodProd))
			cMsg := "ESTOQUE E PRECO SINCRONIZADOS COM SUCESSO!" + CRLF + CRLF
			cMsg += "Codigo SKU / Protheus: " + AllTrim(cCodProd) + CRLF
			cMsg += "ID Nuvemshop: " + oProd:GetProductId(AllTrim(cCodProd)) + CRLF
			cMsg += "Variante ID: " + oProd:GetVariantId(AllTrim(cCodProd)) + CRLF + CRLF
			If oData != Nil
				cMsg += "Preco Atualizado: R$ " + Transform(oData["preco"], "@E 999,999.99") + CRLF
				cMsg += "Estoque Disponivel: " + cValToChar(oData["estoque"]) + " un" + CRLF
				FreeObj(oData)
			EndIf
			cMsg += CRLF + "Vinculo gravado com sucesso no de-para (VT9 e VTD)."
			MsgInfo(cMsg, "Sucesso Sincronizacao VTEX Match")
		Else
			If oProd:nLastStatus == 404
				MsgAlert("O produto SKU [" + AllTrim(cCodProd) + "] ainda NAO existe na Nuvemshop (HTTP 404)." + CRLF + CRLF + ;
				         "Isso significa que a VTEX ainda nao realizou a publicacao do catalogo deste produto." + CRLF + ;
				         "Assim que a VTEX subir o item, o Protheus fara o vinculo e atualizara estoque/preco automaticamente.", "Aguardando Publicacao VTEX")
			Else
				MsgStop("Falha ao sincronizar produto: " + oProd:GetLastError(), "Erro de Sincronizacao")
			EndIf
		EndIf

	Case nOpcao == 9
		// 9. Sincronizacao em Lote Estoque/Preco B2C (Match Catalogo VTEX)
		cFilEcom := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
		cFilEcom := AllTrim(FWInputBox("Informe a Filial de Estoque/Preco (SBZ):", cFilEcom))
		If Empty(cFilEcom)
			cFilEcom := "03150001"
		EndIf

		cMsgPrompt := "SINCRONIZACAO DE ESTOQUE E PRECO B2C (MATCH VTEX)" + CRLF + CRLF
		cMsgPrompt += "Filial selecionada: " + cFilEcom + CRLF
		cMsgPrompt += "Regra de Filtro: SBZ.BZ_YB2C = 'S' e SB1.B1_MSBLQL != '1'" + CRLF
		cMsgPrompt += "Estrategia: Busca por SKU criado pela VTEX + Injecao de Saldo/Preco Protheus" + CRLF + CRLF
		cMsgPrompt += "Deseja iniciar a sincronizacao agora?"

		If MsgYesNo(cMsgPrompt, "Sincronizacao de Estoque/Preco B2C")
			oRes := Nil
			Processa({|lEnd| ;
				oRes := oProd:SyncAllStockPriceB2C(cFilEcom, {|nAtual, nTotal, cCod, lOkProd, cErr| ;
					ProcRegua(nTotal), ;
					IncProc("Sincronizando " + cValToChar(nAtual) + "/" + cValToChar(nTotal) + ": SKU " + cCod) ;
				}) ;
			}, "Sincronizacao B2C Nuvemshop", "Localizando SKUs e atualizando precos/saldos...", .F.)

			If oRes != Nil
				cMsg := "SINCRONIZACAO B2C FINALIZADA!" + CRLF + CRLF
				cMsg += "Filial: " + cFilEcom + CRLF
				cMsg += "Total de produtos B2C no Protheus: " + cValToChar(oRes["total"]) + CRLF
				cMsg += "Sincronizados com Sucesso: " + cValToChar(oRes["sucessos"]) + CRLF
				cMsg += "Aguardando Cadastro na VTEX (404): " + cValToChar(oRes["aguardando_vtex"]) + CRLF
				cMsg += "Erros / Falhas de Comunicacao: " + cValToChar(oRes["erros"]) + CRLF

				If oRes["erros"] > 0 .And. ValType(oRes["falhas"]) == "A" .And. Len(oRes["falhas"]) > 0
					cMsg += CRLF + "Primeiras falhas de comunicacao:" + CRLF
					For nI := 1 To Min(5, Len(oRes["falhas"]))
						cMsg += " - SKU " + oRes["falhas"][nI][1] + ": " + oRes["falhas"][nI][2] + CRLF
					Next nI
					MsgAlert(cMsg, "Sincronizacao Finalizada com Alertas")
				Else
					MsgInfo(cMsg, "Sincronizacao Nuvemshop x VTEX Concluida")
				EndIf
				FreeObj(oRes)
			EndIf
		EndIf
	EndCase

	FreeObj(oProd)
Return .T.
