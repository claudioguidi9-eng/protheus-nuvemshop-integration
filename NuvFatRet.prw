#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} NuvFatRet
Ponto de Retorno de Faturamento do Protheus para a Nuvemshop.
Acionado imediatamente apos a emissao/autorizacao da Nota Fiscal de Saida (SF2),
normalmente chamado a partir do ponto de entrada M460FIM.

Executa de forma segura:
1. Identifica se o pedido faturado originou-se da Nuvemshop (tabela VT1 / SC5).
2. Obtem a Chave de Acesso da NF-e (44 digitos) e numero do documento em SF2.
3. Envia a NF-e para a Nuvemshop via API REST (Metafields namespace 'nfe').
4. Verifica se ha informacao de despacho/rastreamento e notifica a loja.
5. Enfileira os produtos faturados (SD2) na tabela VTF para atualizacao imediata de saldo delta na Nuvemshop.
6. Atualiza o status do pedido na esteira VT1 para 'F' (Faturado) / '6'.

@author Claudio Guidi
@since 05/10/2026
@version 1.0
@project Integracao Nuvemshop - TOTVS Protheus Fortbras
/*/
User Function NuvFatRet(cFilSF2, cDoc, cSerie, cNumSC5)

	Local aAreaAnt     := FWGetArea()
	Local aAreaSF2     := SF2->(FWGetArea())
	Local aAreaSC5     := SC5->(FWGetArea())
	Local cOrderId     := ""
	Local cChvNFe      := ""
	Local oNuvPed      := Nil
	Local oNuvProd     := Nil
	Local lFatOk       := .F.
	Local cAliasQry    := ""
	Local cQuery       := ""
	Local cCodProd     := ""
	Local cTransp      := ""
	Local cRastreio    := ""
	Local cTrackURL    := ""

	Default cFilSF2    := xFilial("SF2")
	Default cDoc       := SF2->F2_DOC
	Default cSerie     := SF2->F2_SERIE
	Default cNumSC5    := SC5->C5_NUM

	cDoc    := AllTrim(cDoc)
	cSerie  := AllTrim(cSerie)
	cNumSC5 := AllTrim(cNumSC5)

	If Empty(cDoc) .Or. Empty(cNumSC5)
		aEval({aAreaSF2, aAreaSC5, aAreaAnt}, {|x| FWRestArea(x)})
		Return .F.
	EndIf

	ConOut("[NUVEMSHOP][FATURAMENTO] Analisando faturamento do Pedido Protheus: " + cNumSC5 + " | NF: " + cDoc + "-" + cSerie)

	//-------------------------------------------------------------------------
	// 1. Identifica se o pedido pertence a esteira da Nuvemshop na tabela VT1
	//-------------------------------------------------------------------------
	If ChkFile("VT1")
		DbSelectArea("VT1")

		// Tenta busca pelo Indice ou Query direta por VT1_NUMPED
		cAliasQry := GetNextAlias()
		cQuery := "SELECT VT1_ORDID, VT1_SEQUEN, VT1_API, VT1_STATUS, R_E_C_N_O_ AS REC_VT1 "
		cQuery += "  FROM " + RetSqlName("VT1") + " VT1 "
		cQuery += " WHERE VT1.D_E_L_E_T_ = ' ' "
		cQuery += "   AND VT1.VT1_NUMPED = '" + PADR(cNumSC5, TamSX3("VT1_NUMPED")[1]) + "' "
		cQuery += "   AND VT1.VT1_API    = 'NUVEMSHOP' "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

		If !(cAliasQry)->(Eof())
			cOrderId := AllTrim((cAliasQry)->VT1_ORDID)
		EndIf
		(cAliasQry)->(dbCloseArea())
	EndIf

	// Fallback: se nao achou por VT1_NUMPED, verifica campo C5_PEDCLI ou C5_ORIGEM
	If Empty(cOrderId) .And. SC5->(FieldPos("C5_ORIGEM")) > 0
		If Upper(AllTrim(SC5->C5_ORIGEM)) == "NUVEMSHOP" .And. !Empty(SC5->C5_PEDCLI)
			cOrderId := AllTrim(SC5->C5_PEDCLI)
		EndIf
	EndIf

	// Se o pedido nao for da Nuvemshop, encerra com sucesso sem intervir
	If Empty(cOrderId)
		ConOut("[NUVEMSHOP][FATURAMENTO] Pedido " + cNumSC5 + " nao e de origem Nuvemshop. Ignorando.")
		aEval({aAreaSF2, aAreaSC5, aAreaAnt}, {|x| FWRestArea(x)})
		Return .T.
	EndIf

	ConOut("[NUVEMSHOP][FATURAMENTO] Confirmado pedido Nuvemshop ID: " + cOrderId + " vinculado ao SC5: " + cNumSC5)

	//-------------------------------------------------------------------------
	// 2. Localiza a Chave da NF-e (44 digitos) em SF2
	//-------------------------------------------------------------------------
	SF2->(DbSetOrder(1)) // F2_FILIAL + F2_DOC + F2_SERIE + F2_CLIENTE + F2_LOJA
	If SF2->(DbSeek(cFilSF2 + PADR(cDoc, TamSX3("F2_DOC")[1]) + PADR(cSerie, TamSX3("F2_SERIE")[1])))
		If SF2->(FieldPos("F2_CHVNFE")) > 0
			cChvNFe := AllTrim(SF2->F2_CHVNFE)
		EndIf
		If SF2->(FieldPos("F2_TRANSP")) > 0 .And. !Empty(SF2->F2_TRANSP)
			cTransp := Posicione("SA4", 1, xFilial("SA4") + SF2->F2_TRANSP, "A4_NOME")
		EndIf
	EndIf

	// Se a chave ainda nao estiver em SF2 (ex: emissao assincrona), usa fallback seguro
	If Empty(cChvNFe)
		cChvNFe := "NFE-" + cDoc + "-" + cSerie
	EndIf

	//-------------------------------------------------------------------------
	// 3. Dispara o faturamento para a API da Nuvemshop (SetFaturar)
	//-------------------------------------------------------------------------
	oNuvPed := NuvemPedido():New()
	lFatOk  := oNuvPed:SetFaturar(cOrderId, cDoc, cSerie, cChvNFe)

	If lFatOk
		ConOut("[NUVEMSHOP][FATURAMENTO] Chave NF-e " + cChvNFe + " registrada com sucesso no pedido Nuvemshop " + cOrderId)

		// 3.1 Se houver informacoes de despacho em SF2, envia rastreio
		If !Empty(cTransp)
			// Procura codigo de rastreio customizado caso exista
			If SF2->(FieldPos("F2_RASTREI")) > 0 .And. !Empty(SF2->F2_RASTREI)
				cRastreio := AllTrim(SF2->F2_RASTREI)
			ElseIf SF2->(FieldPos("F2_VLMNTNF")) > 0 .And. !Empty(SF2->F2_VLMNTNF)
				cRastreio := AllTrim(SF2->F2_VLMNTNF)
			EndIf

			If !Empty(cRastreio)
				oNuvPed:SetEnviar(cOrderId, cRastreio, cTransp, cTrackURL)
			EndIf
		EndIf

		// 3.2 Atualiza status na esteira VT1 para '6' (Faturado Total)
		If ChkFile("VT1")
			DbSelectArea("VT1")
			VT1->(DbSetOrder(1))
			If VT1->(DbSeek(xFilial("VT1") + PADR(cOrderId, TamSX3("VT1_ORDID")[1])))
				RecLock("VT1", .F.)
				If VT1->(FieldPos("VT1_STATUS")) > 0
					VT1->VT1_STATUS := "6" // 6 = Faturado
				EndIf
				If VT1->(FieldPos("VT1_OBS")) > 0
					VT1->VT1_OBS := "FATURADO VIA NF " + cDoc + "-" + cSerie + " CHAVE: " + cChvNFe
				EndIf
				If VT1->(FieldPos("VT1_DATAUL")) > 0
					VT1->VT1_DATAUL := dDataBase
				EndIf
				If VT1->(FieldPos("VT1_HORAUL")) > 0
					VT1->VT1_HORAUL := Time()
				EndIf
				VT1->(MsUnlock())
			EndIf
		EndIf
	Else
		ConOut("[NUVEMSHOP][FATURAMENTO][ERRO] Falha ao enviar NF-e para a Nuvemshop: " + oNuvPed:GetLastError())
	EndIf

	FreeObj(oNuvPed)

	//-------------------------------------------------------------------------
	// 4. Enfileira os produtos na Fila VTF para atualizacao de estoque delta
	//-------------------------------------------------------------------------
	If ChkFile("SD2")
		DbSelectArea("SD2")
		SD2->(DbSetOrder(3)) // D2_FILIAL + D2_DOC + D2_SERIE + D2_CLIENTE + D2_LOJA
		If SD2->(DbSeek(cFilSF2 + PADR(cDoc, TamSX3("D2_DOC")[1]) + PADR(cSerie, TamSX3("D2_SERIE")[1])))
			While !SD2->(Eof()) .And. SD2->D2_FILIAL == cFilSF2 .And. ;
			      SD2->D2_DOC == PADR(cDoc, TamSX3("D2_DOC")[1]) .And. ;
			      SD2->D2_SERIE == PADR(cSerie, TamSX3("D2_SERIE")[1])

				cCodProd := AllTrim(SD2->D2_COD)
				If !Empty(cCodProd)
					// Grava na fila assincrona VTF
					If ChkFile("VTF")
						DbSelectArea("VTF")
						RecLock("VTF", .T.)
						If VTF->(FieldPos("VTF_FILIAL")) > 0
							VTF->VTF_FILIAL := xFilial("VTF")
						EndIf
						If VTF->(FieldPos("VTF_PRODUT")) > 0
							VTF->VTF_PRODUT := PADR(cCodProd, TamSX3("VTF_PRODUT")[1])
						EndIf
						If VTF->(FieldPos("VTF_API")) > 0
							VTF->VTF_API := "NUVEMSHOP"
						EndIf
						If VTF->(FieldPos("VTF_ATUWEB")) > 0
							VTF->VTF_ATUWEB := "S" // S = Pendente de envio
						EndIf
						If VTF->(FieldPos("VTF_DATA")) > 0
							VTF->VTF_DATA := dDataBase
						EndIf
						If VTF->(FieldPos("VTF_HORA")) > 0
							VTF->VTF_HORA := Time()
						EndIf
						VTF->(MsUnlock())
						ConOut("[NUVEMSHOP][DELTA] Produto " + cCodProd + " enfileirado na VTF apos faturamento da NF " + cDoc)
					EndIf
				EndIf

				SD2->(DbSkip())
			EndDo
		EndIf
	EndIf

	aEval({aAreaSF2, aAreaSC5, aAreaAnt}, {|x| FWRestArea(x)})

Return lFatOk
