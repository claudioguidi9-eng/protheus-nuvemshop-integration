#INCLUDE "PROTHEUS.CH"
#INCLUDE "FWMVCDEF.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} NuvPainelPedidos
Painel de Gestao, Monitoramento e Reprocessamento de Pedidos Nuvemshop.

Permite a equipe de E-Commerce e TI da Fortbras:
1. Visualizar todos os pedidos integrados entre a Nuvemshop e o Protheus.
2. Identificar com legenda de cores o status de cada pedido (Pendente, Gerado no ERP, Faturado, Erro).
3. Ver o motivo exato de qualquer erro ou rejeicao de integracao.
4. Reprocessar pedidos com erro com 1 clique (revalidando estoque e gerando SC5/SC6).
5. Consultar o status em tempo real na API da Nuvemshop.
6. Forcar o reenvio da Chave da NF-e e dados de rastreio para a loja.

@author Claudio Guidi
@since 05/10/2026
@version 1.1
@project Integracao Nuvemshop - TOTVS Protheus Fortbras
/*/
User Function NuvPainelPedidos()

	Local oBrowse := Nil

	// Protecao de escopo para colunas virtuais legadas do dicionario SX3 da VT1
	Private cFilTIMS := SuperGetMv("MV_YFILATC", .F., "04160001")

	// Verifica se a tabela VT1 existe no dicionario
	If !ChkFile("VT1")
		MsgStop("A tabela VT1 (Pedidos de E-Commerce) nao esta criada no dicionario de dados.", "Nuvemshop - Atencao")
		Return
	EndIf

	DbSelectArea("VT1")
	VT1->(DbSetOrder(1)) // VT1_FILIAL + VT1_ORDID

	oBrowse := FWMBrowse():New()
	oBrowse:SetAlias("VT1")
	oBrowse:SetDescription("Painel de Pedidos Nuvemshop - Fortbras")

	// Isola estritamente os campos necessarios do dicionario VT1,
	// evitando a execucao de inicializadores legados do SX3 (ex: WPNFTims)
	oBrowse:SetOnlyFields({"VT1_FILIAL", "VT1_ORDID", "VT1_SEQUEN", "VT1_NUMPED", "VT1_DATAIN", "VT1_HORAIN", "VT1_VALOR", "VT1_VALFRE", "VT1_STATUS", "VT1_OBS", "VT1_API"})

	// Filtra exclusivamente pedidos originados pela API Nuvemshop
	oBrowse:SetFilterDefault("VT1->VT1_API == 'NUVEMSHOP'")

	//-------------------------------------------------------------------------
	// Legenda Visual por Cores de Status
	//-------------------------------------------------------------------------
	oBrowse:AddLegend("Empty(VT1->VT1_STATUS) .Or. VT1->VT1_STATUS == ' '", "YELLOW", "Pendente na Fila de Ingestao")
	oBrowse:AddLegend("VT1->VT1_STATUS $ 'A|P|1|2|3'", "GREEN",  "Pedido Protheus Gerado (SC5/SC6)")
	oBrowse:AddLegend("VT1->VT1_STATUS == '4'", "ORANGE", "Em Separacao / Manuseio")
	oBrowse:AddLegend("VT1->VT1_STATUS $ '5|6|7|8|F'", "BLUE",   "Faturado com NF-e Emitida")
	oBrowse:AddLegend("VT1->VT1_STATUS $ 'E|R|X'", "RED",    "Erro no Processamento / Rejeitado")
	oBrowse:AddLegend("VT1->VT1_STATUS $ 'C|Z'", "GRAY",   "Cancelado")

	// Colunas do Browse
	oBrowse:SetColumns(NuvPedColumns())

	// Botoes e Acoes do Menu
	oBrowse:SetMenuDef("NuvPainelPedidos")

	oBrowse:Activate()

Return

/*/{Protheus.doc} MenuDef
Definicao do Menu de Acoes do Painel de Pedidos.
/*/
Static Function MenuDef()

	Local aRotina := {}

	ADD OPTION aRotina TITLE "Visualizar Detalhes"  ACTION "U_NuvVerDetalhes"  OPERATION 2 ACCESS 0
	ADD OPTION aRotina TITLE "Reprocessar Pedido"   ACTION "U_NuvReprocPed"    OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Consultar Nuvemshop"  ACTION "U_NuvConsOnline"   OPERATION 2 ACCESS 0
	ADD OPTION aRotina TITLE "Reenviar NF-e"        ACTION "U_NuvReenvNFe"     OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Informar Rastreio"    ACTION "U_NuvInfRastreio"  OPERATION 4 ACCESS 0
	ADD OPTION aRotina TITLE "Ver JSON / Log"       ACTION "U_NuvVerJson"      OPERATION 2 ACCESS 0

Return aRotina

/*/{Protheus.doc} NuvPedColumns
Monta as colunas visuais exibidas na grade do Painel.
/*/
Static Function NuvPedColumns()

	Local aColumns := {}
	Local oCol     := Nil

	// Coluna: Legenda Visual (Semaforo de Status)
	oCol := FWBrwColumn():New()
	oCol:SetData({|| NuvStatusBmp(VT1->VT1_STATUS)})
	oCol:SetTitle(" ")
	oCol:SetPicture("@BMP")
	oCol:SetSize(4)
	AAdd(aColumns, oCol)

	// Coluna: ID Nuvemshop
	oCol := FWBrwColumn():New()
	oCol:SetData({|| VT1->VT1_ORDID})
	oCol:SetTitle("ID Nuvemshop")
	oCol:SetSize(14)
	AAdd(aColumns, oCol)

	// Coluna: Num Loja (#)
	If VT1->(FieldPos("VT1_SEQUEN")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| VT1->VT1_SEQUEN})
		oCol:SetTitle("Numero Loja")
		oCol:SetSize(8)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Pedido Protheus (SC5)
	If VT1->(FieldPos("VT1_NUMPED")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| VT1->VT1_NUMPED})
		oCol:SetTitle("Pedido ERP (SC5)")
		oCol:SetSize(12)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Data de Entrada
	If VT1->(FieldPos("VT1_DATAIN")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| DtoC(VT1->VT1_DATAIN)})
		oCol:SetTitle("Data")
		oCol:SetSize(10)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Hora
	If VT1->(FieldPos("VT1_HORAIN")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| VT1->VT1_HORAIN})
		oCol:SetTitle("Hora")
		oCol:SetSize(8)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Valor Total
	If VT1->(FieldPos("VT1_VALOR")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| Transform(VT1->VT1_VALOR, "@E 999,999.92")})
		oCol:SetTitle("Total (R$)")
		oCol:SetSize(12)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Frete
	If VT1->(FieldPos("VT1_VALFRE")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| Transform(VT1->VT1_VALFRE, "@E 99,999.92")})
		oCol:SetTitle("Frete (R$)")
		oCol:SetSize(10)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Status da Esteira
	If VT1->(FieldPos("VT1_STATUS")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| NuvStatusDesc(VT1->VT1_STATUS)})
		oCol:SetTitle("Status Esteira")
		oCol:SetSize(18)
		AAdd(aColumns, oCol)
	EndIf

	// Coluna: Mensagem de Log / Erro
	If VT1->(FieldPos("VT1_OBS")) > 0
		oCol := FWBrwColumn():New()
		oCol:SetData({|| SubStr(AllTrim(VT1->VT1_OBS), 1, 60)})
		oCol:SetTitle("Historico / Mensagem de Erro")
		oCol:SetSize(35)
		AAdd(aColumns, oCol)
	EndIf

Return aColumns

/*/{Protheus.doc} NuvStatusDesc
Descricao textual amigavel do status da esteira VT1.
/*/
Static Function NuvStatusDesc(cStatus)

	Local cDesc := ""

	Do Case
	Case Empty(cStatus) .Or. cStatus == " "
		cDesc := "Pendente na Fila"
	Case cStatus $ "A|P|1|2|3"
		cDesc := "Gerado no ERP (SC5)"
	Case cStatus == "4"
		cDesc := "Em Separacao"
	Case cStatus $ "5|6|7|8|F"
		cDesc := "Faturado (NF-e OK)"
	Case cStatus $ "E|R|X"
		cDesc := "ERRO / REJEITADO"
	Case cStatus $ "C|Z"
		cDesc := "Cancelado"
	OtherWise
		cDesc := "Status: " + cStatus
	EndCase

Return cDesc

/*/{Protheus.doc} NuvStatusBmp
Retorna o recurso visual de bitmap correspondente ao status da esteira.
/*/
Static Function NuvStatusBmp(cStatus)

	Local cBmp := "BR_AMARELO"

	Do Case
	Case Empty(cStatus) .Or. cStatus == " "
		cBmp := "BR_AMARELO"
	Case cStatus $ "A|P|1|2|3"
		cBmp := "BR_VERDE"
	Case cStatus == "4"
		cBmp := "BR_LARANJA"
	Case cStatus $ "5|6|7|8|F"
		cBmp := "BR_AZUL"
	Case cStatus $ "E|R|X"
		cBmp := "BR_VERMELHO"
	Case cStatus $ "C|Z"
		cBmp := "BR_CINZA"
	OtherWise
		cBmp := "BR_BRANCO"
	EndCase

Return cBmp

/*/{Protheus.doc} U_NuvReprocPed
Acao de Reprocessamento do Pedido Selecionado.
Reseta o status de erro e forca a revalidacao e geracao no ERP.
/*/
User Function NuvReprocPed()

	Local cOrderId := AllTrim(VT1->VT1_ORDID)
	Local cFilVT1  := VT1->VT1_FILIAL
	Local cSeq     := ""
	Local oNuvPed  := Nil
	Local lOk      := .F.

	If VT1->(FieldPos("VT1_SEQUEN")) > 0
		cSeq := AllTrim(VT1->VT1_SEQUEN)
	EndIf

	If !MsgYesNo("Deseja reprocessar o Pedido Nuvemshop ID: " + cOrderId + " (Numero " + cSeq + ")?" + Chr(13) + Chr(10) + ;
			"O status sera resetado para fila de execucao e o Protheus tentara gerar o Pedido de Venda (SC5).", "Confirmar Reprocessamento")
		Return
	EndIf

	// 1. Reseta o status na VT1
	RecLock("VT1", .F.)
	If VT1->(FieldPos("VT1_STATUS")) > 0
		VT1->VT1_STATUS := " " // Pendente
	EndIf
	If VT1->(FieldPos("VT1_OBS")) > 0
		VT1->VT1_OBS := "Reprocessamento manual solicitado pelo operador em " + DtoC(dDataBase) + " as " + Time()
	EndIf
	VT1->(MsUnlock())

	// 2. Tenta reprocessar via NuvemPedido:SetIncPedido
	oNuvPed := NuvemPedido():New()
	lOk := oNuvPed:SetIncPedido(cOrderId)
	FreeObj(oNuvPed)

	If lOk
		MsgInfo("Pedido " + cOrderId + " reprocessado com sucesso na esteira VT1!" + Chr(13) + Chr(10) + ;
			"O Job ECPEDIDO ira gerar o Pedido de Venda SC5.", "Nuvemshop - Sucesso")
	Else
		MsgAlert("O reprocessamento inicial foi registrado, mas o conector retornou aviso." + Chr(13) + Chr(10) + ;
			"Verifique os detalhes na coluna de Historico/Erro.", "Nuvemshop - Aviso")
	EndIf

Return

/*/{Protheus.doc} U_NuvConsOnline
Consulta os dados do pedido em tempo real diretamente na API da Nuvemshop.
/*/
User Function NuvConsOnline()

	Local cOrderId := AllTrim(VT1->VT1_ORDID)
	Local oNuvPed  := NuvemPedido():New()
	Local oJson    := JsonObject():New()
	Local jOrder   := Nil
	Local cMsg     := ""

	If oNuvPed:ExecuteRest("/orders/" + cOrderId, "GET")
		If oJson:FromJson(oNuvPed:cLastResult) == Nil
			jOrder := oJson

			cMsg := "DADOS EM TEMPO REAL NA NUVEMSHOP:" + Chr(13) + Chr(10) + Chr(13) + Chr(10)
			cMsg += "- ID Pedido: " + cOrderId + Chr(13) + Chr(10)
			cMsg += "- Numero Loja: " + cValToChar(jOrder["number"]) + Chr(13) + Chr(10)
			cMsg += "- Status Geral: " + Upper(cValToChar(jOrder["status"])) + Chr(13) + Chr(10)
			cMsg += "- Status Pagamento: " + Upper(cValToChar(jOrder["payment_status"])) + Chr(13) + Chr(10)
			cMsg += "- Data Criacao: " + cValToChar(jOrder["created_at"]) + Chr(13) + Chr(10)
			cMsg += "- Valor Total: R$ " + cValToChar(jOrder["total"]) + Chr(13) + Chr(10)
			cMsg += "- Frete: R$ " + cValToChar(jOrder["shipping_cost_customer"]) + Chr(13) + Chr(10)

			If jOrder:HasProperty("customer") .And. ValType(jOrder["customer"]) == "J"
				cMsg += "- Cliente: " + cValToChar(jOrder["customer"]["name"]) + Chr(13) + Chr(10)
				cMsg += "- CPF/CNPJ: " + cValToChar(jOrder["customer"]["identification"]) + Chr(13) + Chr(10)
				cMsg += "- E-mail: " + cValToChar(jOrder["customer"]["email"]) + Chr(13) + Chr(10)
			EndIf

			Aviso("Consulta Online Nuvemshop", cMsg, {"Fechar"}, 3)
		Else
			MsgAlert("Falha ao interpretar resposta JSON da Nuvemshop.", "Erro")
		EndIf
	Else
		MsgStop("Falha ao comunicar com a Nuvemshop: " + oNuvPed:GetLastError(), "Erro de Conexao")
	EndIf

	FreeObj(oJson)
	FreeObj(oNuvPed)

Return

/*/{Protheus.doc} U_NuvReenvNFe
Forca o reenvio da Chave da NF-e para o pedido selecionado na Nuvemshop.
/*/
User Function NuvReenvNFe()

	Local cOrderId := AllTrim(VT1->VT1_ORDID)
	Local cNumSC5  := ""
	Local cDoc     := ""
	Local cSerie   := ""
	Local cChvNFe  := ""
	Local oNuvPed  := Nil

	If VT1->(FieldPos("VT1_NUMPED")) > 0
		cNumSC5 := AllTrim(VT1->VT1_NUMPED)
	EndIf

	If Empty(cNumSC5)
		MsgStop("Este pedido ainda nao possui Pedido de Venda (SC5) associado.", "Atencao")
		Return
	EndIf

	// Localiza em SF2 pelo pedido SC5
	cDoc   := Posicione("SC5", 1, xFilial("SC5") + cNumSC5, "C5_NOTA")
	cSerie := Posicione("SC5", 1, xFilial("SC5") + cNumSC5, "C5_SERIE")

	If Empty(cDoc)
		// Busca na SF2 por D2_PEDIDO
		cDoc := Posicione("SD2", 1, xFilial("SD2") + cNumSC5, "D2_DOC")
		cSerie := Posicione("SD2", 1, xFilial("SD2") + cNumSC5, "D2_SERIE")
	EndIf

	If Empty(cDoc)
		MsgStop("Nota fiscal nao localizada no ERP para o pedido SC5 " + cNumSC5, "Atencao")
		Return
	EndIf

	cChvNFe := Posicione("SF2", 1, xFilial("SF2") + cDoc + cSerie, "F2_CHVNFE")
	If Empty(cChvNFe)
		cChvNFe := "NFE-" + cDoc + "-" + cSerie
	EndIf

	If !MsgYesNo("Deseja reenviar a NF-e " + cDoc + "-" + cSerie + " (Chave: " + cChvNFe + ") para o Pedido Nuvemshop " + cOrderId + "?", "Reenviar NF-e")
		Return
	EndIf

	oNuvPed := NuvemPedido():New()
	If oNuvPed:SetFaturar(cOrderId, cDoc, cSerie, cChvNFe)
		MsgInfo("Chave da NF-e reenviada com sucesso para a Nuvemshop!", "Sucesso")
	Else
		MsgStop("Falha ao reenviar NF-e: " + oNuvPed:GetLastError(), "Erro")
	EndIf
	FreeObj(oNuvPed)

Return

/*/{Protheus.doc} U_NuvInfRastreio
Abre interface para digitar codigo de rastreamento e transportadora e enviar a Nuvemshop.
/*/
User Function NuvInfRastreio()

	Local cOrderId  := AllTrim(VT1->VT1_ORDID)
	Local cRastreio := Space(30)
	Local cTransp   := Space(40)
	Local cURL      := Space(100)
	Local oDlg      := Nil
	Local oNuvPed   := Nil

	DEFINE MSDIALOG oDlg TITLE "Informar Despacho e Rastreio Nuvemshop" FROM 0,0 TO 220, 480 PIXEL

	@ 10, 10 SAY "Pedido Nuvemshop:" OF oDlg PIXEL
	@ 10, 70 SAY cOrderId COLOR CLR_HBLUE OF oDlg PIXEL

	@ 25, 10 SAY "Cod. Rastreamento:" OF oDlg PIXEL
	@ 23, 70 MSGET cRastreio SIZE 120, 10 OF oDlg PIXEL

	@ 45, 10 SAY "Transportadora:" OF oDlg PIXEL
	@ 43, 70 MSGET cTransp SIZE 150, 10 OF oDlg PIXEL

	@ 65, 10 SAY "Link de Tracking:" OF oDlg PIXEL
	@ 63, 70 MSGET cURL SIZE 160, 10 OF oDlg PIXEL

	@ 85, 80 BUTTON "Confirmar Envio" SIZE 60, 15 OF oDlg PIXEL ACTION {|| ;
		cRastreio := AllTrim(cRastreio), ;
		cTransp := AllTrim(cTransp), ;
		cURL := AllTrim(cURL), ;
		If(Empty(cRastreio), MsgAlert("Informe o codigo de rastreamento!", "Atencao"), ;
			(oNuvPed := NuvemPedido():New(), ;
			If(oNuvPed:SetEnviar(cOrderId, cRastreio, cTransp, cURL), ;
				(MsgInfo("Despacho e rastreio informados com sucesso a Nuvemshop!", "Sucesso"), oDlg:End()), ;
				MsgStop("Falha ao registrar despacho: " + oNuvPed:GetLastError(), "Erro")), ;
				FreeObj(oNuvPed))) ;
				}

			@ 85, 150 BUTTON "Cancelar" SIZE 50, 15 OF oDlg PIXEL ACTION {|| oDlg:End()}

			ACTIVATE MSDIALOG oDlg CENTERED

			Return

/*/{Protheus.doc} U_NuvVerJson
Exibe o conteudo completo do JSON original ou Log Tecnico gravado na VT1.
/*/
User Function NuvVerJson()

	Local cOrderId := AllTrim(VT1->VT1_ORDID)
	Local cJson    := ""
	Local oDlg     := Nil
	Local oGet     := Nil

	If VT1->(FieldPos("VT1_JSON")) > 0 .And. !Empty(VT1->VT1_JSON)
		cJson := VT1->VT1_JSON
	ElseIf VT1->(FieldPos("VT1_OBS")) > 0
		cJson := VT1->VT1_OBS
	Else
		cJson := "Nenhum log ou JSON bruto armazenado para este pedido."
	EndIf

	DEFINE MSDIALOG oDlg TITLE ("Auditoria de JSON/Log do Pedido " + cOrderId) FROM 0,0 TO 450, 700 PIXEL
	@ 10, 10 GET oGet VAR cJson MEMO SIZE 330, 180 OF oDlg PIXEL READONLY
	@ 200, 140 BUTTON "Fechar" SIZE 60, 15 OF oDlg PIXEL ACTION {|| oDlg:End()}
	ACTIVATE MSDIALOG oDlg CENTERED

Return

/*/{Protheus.doc} U_NuvVerDetalhes
Visualizacao dos dados cadastrais e itens do pedido da esteira VT1.
/*/
User Function NuvVerDetalhes()

	Local cOrderId := AllTrim(VT1->VT1_ORDID)
	Local cDetalhe := ""
	Local oDlg     := Nil
	Local oGet     := Nil

	cDetalhe := "DETALHES DO PEDIDO NA ESTEIRA VT1:" + Chr(13) + Chr(10) + Chr(13) + Chr(10)
	cDetalhe += "- ID Nuvemshop: " + cOrderId + Chr(13) + Chr(10)

	If VT1->(FieldPos("VT1_SEQUEN")) > 0
		cDetalhe += "- Numero da Loja: " + AllTrim(VT1->VT1_SEQUEN) + Chr(13) + Chr(10)
	EndIf
	If VT1->(FieldPos("VT1_NUMPED")) > 0
		cDetalhe += "- Pedido Protheus (SC5): " + AllTrim(VT1->VT1_NUMPED) + Chr(13) + Chr(10)
	EndIf
	If VT1->(FieldPos("VT1_STATUS")) > 0
		cDetalhe += "- Status Esteira: " + NuvStatusDesc(VT1->VT1_STATUS) + Chr(13) + Chr(10)
	EndIf
	If VT1->(FieldPos("VT1_VALOR")) > 0
		cDetalhe += "- Valor dos Produtos: R$ " + Transform(VT1->VT1_VALOR, "@E 999,999.92") + Chr(13) + Chr(10)
	EndIf
	If VT1->(FieldPos("VT1_VALFRE")) > 0
		cDetalhe += "- Valor do Frete: R$ " + Transform(VT1->VT1_VALFRE, "@E 99,999.92") + Chr(13) + Chr(10)
	EndIf
	If VT1->(FieldPos("VT1_OBS")) > 0
		cDetalhe += Chr(13) + Chr(10) + "HISTORICO / MOTIVO DO ULTIMO STATUS:" + Chr(13) + Chr(10)
		cDetalhe += AllTrim(VT1->VT1_OBS) + Chr(13) + Chr(10)
	EndIf

	DEFINE MSDIALOG oDlg TITLE ("Detalhes do Pedido " + cOrderId) FROM 0,0 TO 380, 550 PIXEL
	@ 10, 10 GET oGet VAR cDetalhe MEMO SIZE 255, 150 OF oDlg PIXEL READONLY
	@ 165, 110 BUTTON "Fechar" SIZE 50, 15 OF oDlg PIXEL ACTION {|| oDlg:End()}
	ACTIVATE MSDIALOG oDlg CENTERED

Return
