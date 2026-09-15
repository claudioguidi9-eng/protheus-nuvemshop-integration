#INCLUDE "TOTVS.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} NuvemProduto
Classe de sincronizacao de Catalogo, Produtos, Variantes, Custom Fields,
Precos e Estoques entre Protheus Fortbras e a plataforma Nuvemshop.

Consome dados do ERP:
- SB1 (Cadastro de Produtos / Fabricante)
- SB5 (Dados Adicionais / Dimensoes / Peso / Descricao)
- SZ1 (Dados Complementares de E-Commerce)
- Z08 (Produto x Aplicacao: Montadora, Modelo, Ano, Motor, Aplicacao)
- Z09 (Produto x Codigo Original: Numero de Peca)
- ECOMMERCE_PRODWEB (View SQL de Saldo Disponivel e Preco de Venda)
- VT8, VT9, VTD, VTF (Esteira padrao de integracao E-commerce Fortbras)

API Nuvemshop: versao unstable com Custom Fields e Custom Objects com namespace demofortbras.

@author Claudio Guidi
@since 10/09/2026
@version 2.0
@project Integracao Nuvemshop - TOTVS Protheus
/*/
CLASS NuvemProduto FROM NuvemAcesso

	DATA nBatchSize   AS NUMERIC
	DATA cNamespace   AS CHARACTER

	METHOD New() CONSTRUCTOR
	METHOD UpdtAtuWeb()
	METHOD SendBatch(aLote)
	METHOD GetVariantId(cCodProd)
	METHOD GetProductId(cCodProd)
	METHOD CheckSku(cSku)
	METHOD CreateProduct(cJsonPayload)
	METHOD UpdateProduct(nProdId, cJsonPayload)
	METHOD UpdateVariant(nProdId, nVariantId, cJsonPayload)
	METHOD SendImages(nProdId, aImages)
	METHOD SetCustomFields(nVariantId, aCustomFields)
	METHOD GetDadosProd(cCodProd)
	METHOD GetOrCreateCategory(cCatName)
	METHOD ExportProduct(cCodProd, lForce)
	METHOD ExportAllB2C(cFilialP, bProgress)
	METHOD GravaIdWEB(cCodProd, cProdId, cVarId)

ENDCLASS

/*/{Protheus.doc} New
Construtor da classe NuvemProduto.
/*/
METHOD New() CLASS NuvemProduto
	_Super:New()
	::nBatchSize := SuperGetMV("MV_NUVLOTE", .F., 50)
	If ValType(::nBatchSize) == "C"
		::nBatchSize := Val(::nBatchSize)
	EndIf
	If ValType(::nBatchSize) != "N" .Or. ::nBatchSize <= 0
		::nBatchSize := 50
	EndIf
	::cNamespace := AllTrim(cValToChar(SuperGetMV("MV_NUVNSPC", .F., "demofortbras")))
Return Self

/*/{Protheus.doc} CheckSku
Consulta se o SKU ja existe na Nuvemshop para garantir idempotencia.
Endpoint: GET /products/sku/{sku}
Retorna o objeto JsonObject do produto se existir, ou Nil se 404 (novo).
/*/
METHOD CheckSku(cSku) CLASS NuvemProduto
	Local oJsonProd := Nil
	Local lSuccess  := .F.
	Local cPath     := "/products/sku/" + AllTrim(cSku)

	lSuccess := ::Get(cPath)

	If lSuccess .And. ::nLastStatus == 200
		oJsonProd := JsonObject():New()
		If oJsonProd:FromJson(::cLastResult) != Nil
			FreeObj(oJsonProd)
			oJsonProd := Nil
		EndIf
	EndIf
Return oJsonProd

/*/{Protheus.doc} CreateProduct
Cria o produto na Nuvemshop juntamente com a primeira variante via POST /products.
/*/
METHOD CreateProduct(cJsonPayload) CLASS NuvemProduto
	Local oJsonRet := Nil
	Local lSuccess := .F.

	lSuccess := ::Post("/products", cJsonPayload)

	If lSuccess .And. (::nLastStatus == 200 .Or. ::nLastStatus == 201)
		oJsonRet := JsonObject():New()
		If oJsonRet:FromJson(::cLastResult) != Nil
			FreeObj(oJsonRet)
			oJsonRet := Nil
		EndIf
	Else
		ConOut("[NUVEMSHOP][ERRO] Falha ao criar produto: " + ::GetLastError())
	EndIf
Return oJsonRet

/*/{Protheus.doc} UpdateProduct
Atualiza os dados de um produto existente via PUT /products/{id}.
/*/
METHOD UpdateProduct(nProdId, cJsonPayload) CLASS NuvemProduto
	Local oJsonRet := Nil
	Local lSuccess := .F.
	Local cPath    := "/products/" + cValToChar(nProdId)

	lSuccess := ::Put(cPath, cJsonPayload)

	If lSuccess .And. (::nLastStatus >= 200 .And. ::nLastStatus < 300)
		oJsonRet := JsonObject():New()
		If oJsonRet:FromJson(::cLastResult) != Nil
			FreeObj(oJsonRet)
			oJsonRet := Nil
		EndIf
	Else
		ConOut("[NUVEMSHOP][ERRO] Falha ao atualizar produto ID " + cValToChar(nProdId) + ": " + ::GetLastError())
	EndIf
Return oJsonRet

/*/{Protheus.doc} UpdateVariant
Atualiza dados comerciais da variante (preco, estoque, peso, dimensoes) via PUT /products/{id}/variants/{variant_id}.
/*/
METHOD UpdateVariant(nProdId, nVariantId, cJsonPayload) CLASS NuvemProduto
	Local oJsonRet := Nil
	Local lSuccess := .F.
	Local cPath    := "/products/" + cValToChar(nProdId) + "/variants/" + cValToChar(nVariantId)

	lSuccess := ::Put(cPath, cJsonPayload)

	If lSuccess .And. (::nLastStatus >= 200 .And. ::nLastStatus < 300)
		oJsonRet := JsonObject():New()
		If oJsonRet:FromJson(::cLastResult) != Nil
			FreeObj(oJsonRet)
			oJsonRet := Nil
		EndIf
		ConOut("[NUVEMSHOP] Variante ID " + cValToChar(nVariantId) + " atualizada com sucesso (Preco/Peso/Estoque/Dimensoes).")
	Else
		ConOut("[NUVEMSHOP][ERRO] Falha ao atualizar variante ID " + cValToChar(nVariantId) + ": " + ::GetLastError())
	EndIf
Return oJsonRet

/*/{Protheus.doc} SendImages
Envia imagens do produto para o endpoint POST /products/{id}/images.
A Nuvemshop exige obrigatoriamente uma URL publica acessivel (parametro "src").
Localiza URLs configuradas em MV_NUVIMG, ZZ_VX3995 ou padrao Fortbras B2B.
/*/
METHOD SendImages(nProdId, aImages) CLASS NuvemProduto
	Local nI          := 0
	Local cPath       := "/products/" + cValToChar(nProdId) + "/images"
	Local cBody       := ""
	Local lSuccess    := .T.
	Local cImg        := ""
	Local cUrlBaseImg := ""

	cUrlBaseImg := AllTrim(cValToChar(SuperGetMV("MV_NUVIMG", .F., SuperGetMV("ZZ_VX3995", .F., "https://b2b.fortbras.com.br/imagens/"))))
	If !Empty(cUrlBaseImg) .And. Right(cUrlBaseImg, 1) != "/"
		cUrlBaseImg += "/"
	EndIf

	For nI := 1 To Len(aImages)
		cImg := AllTrim(aImages[nI])
		If Empty(cImg)
			Loop
		EndIf

		If Lower(SubStr(cImg, 1, 4)) != "http"
			If !Empty(cUrlBaseImg)
				If Lower(Right(cImg, 4)) $ ".jpg|.png|.gif|.webp"
					cImg := cUrlBaseImg + cImg
				Else
					cImg := cUrlBaseImg + cImg + ".jpg"
				EndIf
			EndIf
		EndIf

		If Lower(SubStr(cImg, 1, 4)) == "http"
			cBody := '{"src": "' + cImg + '"}'
			ConOut("[NUVEMSHOP] Enviando imagem " + cValToChar(nI) + " (" + cImg + ") para o produto ID " + cValToChar(nProdId))
			If !::Post(cPath, cBody)
				ConOut("[NUVEMSHOP][AVISO] Nuvemshop nao conseguiu carregar imagem da URL (" + cImg + "): " + ::GetLastError())
				lSuccess := .F.
			Else
				ConOut("[NUVEMSHOP] Imagem " + cValToChar(nI) + " vinculada com sucesso ao produto ID " + cValToChar(nProdId))
			EndIf

			// Pausa entre imagens para a Nuvemshop processar o download/redimensionamento e evitar 429 Rate Limit
			If nI < Len(aImages)
				Sleep(1000)
			EndIf
		Else
			ConOut("[NUVEMSHOP][AVISO] Imagem ignorada pois a Nuvemshop exige URL publica (src): " + cImg)
		EndIf
	Next nI
Return lSuccess

/*/{Protheus.doc} GetOrCreateCategory
Localiza o ID da categoria na Nuvemshop pelo nome (GET /categories)
ou cria a categoria automaticamente caso nao exista (POST /categories).
/*/
METHOD GetOrCreateCategory(cCatName) CLASS NuvemProduto
	Local nCatId   := 0
	Local cPath    := "/categories"
	Local oCats    := Nil
	Local nI       := 0
	Local cBody    := ""
	Local oNewCat  := Nil
	Local cNameLim := AllTrim(cCatName)
	Local cCatNome := ""

	If Empty(cNameLim)
		Return 0
	EndIf

	cCatNome := StrTran(cNameLim, "\", "\\")
	cCatNome := StrTran(cCatNome, '"', '\"')

	// 1. Busca categorias existentes na loja
	If ::Get(cPath) .And. ::nLastStatus == 200
		oCats := JsonObject():New()
		If oCats:FromJson(::cLastResult) == Nil
			If ValType(oCats) == "A"
				For nI := 1 To Len(oCats)
					If Upper(AllTrim(cValToChar(oCats[nI]["name"]["pt"]))) == Upper(cNameLim)
						nCatId := oCats[nI]["id"]
						Exit
					EndIf
				Next nI
			EndIf
		EndIf
		FreeObj(oCats)
	EndIf

	// 2. Se nao encontrou, cria a categoria na Nuvemshop
	If nCatId == 0
		cBody := '{"name": {"pt": "' + cCatNome + '"}}'
		If ::Post(cPath, cBody) .And. (::nLastStatus == 200 .Or. ::nLastStatus == 201)
			oNewCat := JsonObject():New()
			If oNewCat:FromJson(::cLastResult) == Nil
				nCatId := oNewCat["id"]
				ConOut("[NUVEMSHOP] Categoria '" + cNameLim + "' criada com sucesso. ID: " + cValToChar(nCatId))
			EndIf
			FreeObj(oNewCat)
		Else
			ConOut("[NUVEMSHOP][AVISO] Nao foi possivel criar categoria '" + cNameLim + "': " + ::GetLastError())
		EndIf
	EndIf
Return nCatId


/*/{Protheus.doc} SetCustomFields
Grava valores de Custom Fields na variante (PUT /products/variants/{vid}/custom-fields/values).
aCustomFields = { {"montadora", "FIAT"}, {"modelo", "Palio"}, {"ano", "2001 a 2016"}, ... }
/*/
METHOD SetCustomFields(nVariantId, aCustomFields) CLASS NuvemProduto
	Local cPath    := "/products/variants/" + cValToChar(nVariantId) + "/custom-fields/values"
	Local cBody    := ""
	Local nI       := 0
	Local nJ       := 0
	Local cChave   := ""
	Local cValor   := ""
	Local cRef     := ""
	Local cSlugVal := ""
	Local lSuccess := .F.

	If Len(aCustomFields) == 0
		Return .T.
	EndIf

	// Auto-cadastro defensivo de Custom Objects referenciados para prevenir erro REF_NOT_FOUND
	For nI := 1 To Len(aCustomFields)
		If AllTrim(aCustomFields[nI][1]) == "montadoras" .And. ValType(aCustomFields[nI][2]) == "A"
			For nJ := 1 To Len(aCustomFields[nI][2])
				cRef := aCustomFields[nI][2][nJ]
				cSlugVal := SubStr(cRef, RAt("/", cRef) + 1)
				::Post("/custom-objects/" + ::cNamespace + "/montadora/entries", '{"name": "' + Capital(StrTran(cSlugVal, "-", " ")) + '", "slug": "' + cSlugVal + '", "value": {"montadora": "' + Capital(StrTran(cSlugVal, "-", " ")) + '"}}')
			Next nJ
		ElseIf AllTrim(aCustomFields[nI][1]) == "modelos" .And. ValType(aCustomFields[nI][2]) == "A"
			For nJ := 1 To Len(aCustomFields[nI][2])
				cRef := aCustomFields[nI][2][nJ]
				cSlugVal := SubStr(cRef, RAt("/", cRef) + 1)
				::Post("/custom-objects/" + ::cNamespace + "/modelo/entries", '{"name": "' + Capital(StrTran(cSlugVal, "-", " ")) + '", "slug": "' + cSlugVal + '", "value": {"modelo": "' + Capital(StrTran(cSlugVal, "-", " ")) + '"}}')
			Next nJ
		EndIf
	Next nI

	cBody := '{"values": ['
	For nI := 1 To Len(aCustomFields)
		cChave := ::cNamespace + "/" + AllTrim(aCustomFields[nI][1])

		cBody += '{"key": "' + cChave + '", "value": '
		If ValType(aCustomFields[nI][2]) == "A"
			cBody += '['
			For nJ := 1 To Len(aCustomFields[nI][2])
				cValor := AllTrim(aCustomFields[nI][2][nJ])
				cBody += '"' + cValor + '"'
				If nJ < Len(aCustomFields[nI][2])
					cBody += ','
				EndIf
			Next nJ
			cBody += ']}'
		Else
			cValor := AllTrim(cValToChar(aCustomFields[nI][2]))
			cValor := StrTran(cValor, "\", "\\")
			cValor := StrTran(cValor, '"', '\"')
			cValor := StrTran(cValor, Chr(13), "")
			cValor := StrTran(cValor, Chr(10), " ")
			cBody += '"' + cValor + '"}'
		EndIf

		If nI < Len(aCustomFields)
			cBody += ','
		EndIf
	Next nI
	cBody += ']}'

	lSuccess := ::Put(cPath, cBody)
	If !lSuccess
		ConOut("[NUVEMSHOP][ERRO] Falha ao gravar Custom Fields da variante " + cValToChar(nVariantId) + ": " + ::GetLastError())
	EndIf
Return lSuccess


/*/{Protheus.doc} GetDadosProd
Coleta todos os dados necessarios do produto nas tabelas do Protheus.
Retorna objeto com informacoes cadastrais, precos, estoque e atributos de compatibilidade.
/*/
METHOD GetDadosProd(cCodProd) CLASS NuvemProduto
	Local oData       := Nil
	Local cQuery      := ""
	Local cAlias      := ""
	Local aCustomFlds := {}
	Local aImagens    := {}
	Local cNome       := ""
	Local cDesc       := ""
	Local cRefId      := ""
	Local cFabric     := ""
	Local cCategoria  := ""
	Local cCodGrupo   := ""
	Local nPreco      := 0.00
	Local nEstoque    := 0
	Local nPeso       := 0.000
	Local nAltura     := 0.00
	Local nLargura    := 0.00
	Local nComp       := 0.00
	Local cMontadora  := ""
	Local cModelo     := ""
	Local cAnoDe      := ""
	Local cAnoAte     := ""
	Local cFaixaAno   := ""
	Local cVersao     := ""
	Local cAplica     := ""
	Local cNumPeca    := ""
	Local cBitMap     := ""
	Local cUrlBaseImg := ""
	Local cCodPad     := ""
	Local cFilEcom    := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "0315")))
	Local cAliasSB2   := ""
	Local cQrySB2     := ""
	Local cAliasDA1   := ""
	Local cQryDA1     := ""

	// 1. Dados Basicos (SB1, SB5, SZ1, SBM)
	DbSelectArea("SB1")
	SB1->(DbSetOrder(1))
	If !SB1->(DbSeek(xFilial("SB1") + cCodProd))
		If !SB1->(DbSeek(cFilEcom + cCodProd))
			If !SB1->(DbSeek(cCodProd))
				Return Nil
			EndIf
		EndIf
	EndIf

	cNome    := AllTrim(SB1->B1_DESC)
	If SB1->(FieldPos("B1_FABRIC")) > 0
		cFabric  := AllTrim(SB1->B1_FABRIC)
	EndIf

	// Leitura de Categoria / Grupo do Produto (SB1->B1_GRUPO e SBM)
	If SB1->(FieldPos("B1_GRUPO")) > 0 .And. !Empty(SB1->B1_GRUPO)
		cCodGrupo := AllTrim(SB1->B1_GRUPO)
		If ChkFile("SBM")
			cCategoria := AllTrim(Posicione("SBM", 1, xFilial("SBM") + cCodGrupo, "BM_DESC"))
			If Empty(cCategoria) .And. Len(cCodGrupo) >= 2
				cCategoria := AllTrim(Posicione("SBM", 1, xFilial("SBM") + SubStr(cCodGrupo, 1, 2), "BM_DESC"))
			EndIf
		EndIf
	EndIf
	If Empty(cCategoria) .And. SB1->(FieldPos("B1_TIPO")) > 0
		cCategoria := AllTrim(SB1->B1_TIPO)
	EndIf

	// Leitura de Peso com fallback (Bruto -> Liquido)
	If SB1->(FieldPos("B1_PESBRU")) > 0 .And. SB1->B1_PESBRU > 0
		nPeso := SB1->B1_PESBRU
	ElseIf SB1->(FieldPos("B1_PESO")) > 0 .And. SB1->B1_PESO > 0
		nPeso := SB1->B1_PESO
	EndIf
	cRefId   := AllTrim(SB1->B1_COD)

	DbSelectArea("SB5")
	SB5->(DbSetOrder(1))
	If !SB5->(DbSeek(cFilEcom + cCodProd))
		SB5->(DbSeek(xFilial("SB5") + cCodProd))
	EndIf
	If SB5->(Found())
		If SB5->(FieldPos("B5_CEME")) > 0 .And. !Empty(SB5->B5_CEME)
			cDesc := AllTrim(SB5->B5_CEME)
		EndIf
		If nPeso <= 0 .And. SB5->(FieldPos("B5_PESO")) > 0 .And. SB5->B5_PESO > 0
			nPeso := SB5->B5_PESO
		EndIf
		If SB5->(FieldPos("B5_ALTURLC")) > 0 .And. SB5->B5_ALTURLC > 0
			nAltura  := SB5->B5_ALTURLC
		ElseIf SB5->(FieldPos("B5_ALTURA")) > 0 .And. SB5->B5_ALTURA > 0
			nAltura  := SB5->B5_ALTURA
		EndIf

		If SB5->(FieldPos("B5_LARGLC")) > 0 .And. SB5->B5_LARGLC > 0
			nLargura := SB5->B5_LARGLC
		ElseIf SB5->(FieldPos("B5_LARG")) > 0 .And. SB5->B5_LARG > 0
			nLargura := SB5->B5_LARG
		EndIf

		If SB5->(FieldPos("B5_COMPRLC")) > 0 .And. SB5->B5_COMPRLC > 0
			nComp    := SB5->B5_COMPRLC
		ElseIf SB5->(FieldPos("B5_COMPR")) > 0 .And. SB5->B5_COMPR > 0
			nComp    := SB5->B5_COMPR
		EndIf
	EndIf

	If Empty(cDesc)
		cDesc := cNome
	EndIf

	// Sanitizacao rigorosa para garantir JSON valido sem quebras de linha ou aspas soltas
	cNome := StrTran(cNome, "\", "\\")
	cNome := StrTran(cNome, '"', '\"')
	cNome := StrTran(cNome, Chr(13), "")
	cNome := StrTran(cNome, Chr(10), " ")

	cDesc := StrTran(cDesc, "\", "\\")
	cDesc := StrTran(cDesc, '"', '\"')
	cDesc := StrTran(cDesc, Chr(13), "")
	cDesc := StrTran(cDesc, Chr(10), " ")

	// 2. Preco e Saldo Consolidado da View ECOMMERCE_PRODWEB
	cCodPad := AvKey(cCodProd, "B1_COD")
	cAlias  := GetNextAlias()

	// Tentativa 1: Filial de e-commerce especifica (padrao '0315' ou configurada em MV_NUVFIL)
	cQuery  := "SELECT TOP 1 PRECO, ESTOQUE FROM ECOMMERCE_PRODWEB "
	cQuery  += " WHERE (PRODUTO = '" + cCodProd + "' OR RTRIM(PRODUTO) = '" + cCodProd + "' OR PRODUTO = '" + cCodPad + "') "
	cQuery  += "   AND FILIAL = '" + cFilEcom + "' "
	cQuery  := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAlias, .F., .T.)
	If !(cAlias)->(Eof())
		nPreco   := (cAlias)->PRECO
		nEstoque := (cAlias)->ESTOQUE
	EndIf
	(cAlias)->(dbCloseArea())

	// Tentativa 2: Caso a filial logada nao tenha preco/saldo, busca na filial B2C com PRECO > 0
	If nPreco <= 0
		cAlias := GetNextAlias()
		cQuery := "SELECT TOP 1 PRECO, ESTOQUE FROM ECOMMERCE_PRODWEB "
		cQuery += " WHERE (PRODUTO = '" + cCodProd + "' OR RTRIM(PRODUTO) = '" + cCodProd + "' OR PRODUTO = '" + cCodPad + "') "
		cQuery += "   AND B2C = 'S' "
		cQuery += "   AND PRECO > 0 "
		cQuery += " ORDER BY PRECO DESC "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAlias, .F., .T.)
		If !(cAlias)->(Eof())
			nPreco   := (cAlias)->PRECO
			If nEstoque <= 0
				nEstoque := (cAlias)->ESTOQUE
			EndIf
		EndIf
		(cAlias)->(dbCloseArea())
	EndIf

	// Tentativa 3: Se ainda zerado, busca em qualquer filial da view com PRECO > 0
	If nPreco <= 0
		cAlias := GetNextAlias()
		cQuery := "SELECT TOP 1 PRECO, ESTOQUE FROM ECOMMERCE_PRODWEB "
		cQuery += " WHERE (PRODUTO = '" + cCodProd + "' OR RTRIM(PRODUTO) = '" + cCodProd + "' OR PRODUTO = '" + cCodPad + "') "
		cQuery += "   AND PRECO > 0 "
		cQuery += " ORDER BY PRECO DESC "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAlias, .F., .T.)
		If !(cAlias)->(Eof())
			nPreco   := (cAlias)->PRECO
			If nEstoque <= 0
				nEstoque := (cAlias)->ESTOQUE
			EndIf
		EndIf
		(cAlias)->(dbCloseArea())
	EndIf

	// Consolidacao de Estoque: Se o estoque da filial veio 0, soma o estoque B2C de todas as filiais
	If nEstoque <= 0
		cAlias := GetNextAlias()
		cQuery := "SELECT SUM(ESTOQUE) AS SALDO_TOTAL FROM ECOMMERCE_PRODWEB "
		cQuery += " WHERE (PRODUTO = '" + cCodProd + "' OR RTRIM(PRODUTO) = '" + cCodProd + "' OR PRODUTO = '" + cCodPad + "') "
		cQuery += "   AND B2C = 'S' "
		cQuery := ChangeQuery(cQuery)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAlias, .F., .T.)
		If !(cAlias)->(Eof()) .And. !Empty((cAlias)->SALDO_TOTAL)
			nEstoque := Max(0, Int((cAlias)->SALDO_TOTAL))
		EndIf
		(cAlias)->(dbCloseArea())
	EndIf

	// Fallback 1 de Estoque: Saldo Disponivel na tabela SB2 caso continue zerado
	If nEstoque <= 0 .And. ChkFile("SB2")
		cAliasSB2 := GetNextAlias()
		cQrySB2 := "SELECT SUM(B2_QATU - B2_RESERVA) AS SALDO "
		cQrySB2 += " FROM " + RetSqlName("SB2") + " SB2 "
		cQrySB2 += " WHERE SB2.D_E_L_E_T_ = ' ' "
		cQrySB2 += "   AND (SB2.B2_COD = '" + cCodProd + "' OR SB2.B2_COD = '" + cCodPad + "') "
		cQrySB2 += "   AND (SB2.B2_FILIAL = '" + cFilEcom + "' OR SB2.B2_FILIAL = '" + cFilAnt + "' OR SB2.B2_FILIAL = '" + xFilial("SB2") + "') "
		cQrySB2 := ChangeQuery(cQrySB2)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQrySB2), cAliasSB2, .F., .T.)
		If !(cAliasSB2)->(Eof()) .And. !Empty((cAliasSB2)->SALDO)
			nEstoque := Max(0, Int((cAliasSB2)->SALDO))
		EndIf
		(cAliasSB2)->(dbCloseArea())
	EndIf

	// Fallback 1 de Preco: Leitura da Tabela de Precos DA1 caso venha zerado
	If nPreco <= 0 .And. ChkFile("DA1")
		cAliasDA1 := GetNextAlias()
		cQryDA1 := "SELECT DA1_PRCVEN "
		cQryDA1 += " FROM " + RetSqlName("DA1") + " DA1 "
		cQryDA1 += " WHERE DA1.D_E_L_E_T_ = ' ' "
		cQryDA1 += "   AND (DA1.DA1_CODPRO = '" + cCodProd + "' OR DA1.DA1_CODPRO = '" + cCodPad + "') "
		cQryDA1 += "   AND (DA1.DA1_FILIAL = '" + cFilEcom + "' OR DA1.DA1_FILIAL = '" + cFilAnt + "' OR DA1.DA1_FILIAL = '" + xFilial("DA1") + "') "
		cQryDA1 += "   AND DA1.DA1_PRCVEN > 0 "
		cQryDA1 := ChangeQuery(cQryDA1)
		dbUseArea(.T., "TOPCONN", TcGenQry(,, cQryDA1), cAliasDA1, .F., .T.)
		If !(cAliasDA1)->(Eof())
			nPreco := (cAliasDA1)->DA1_PRCVEN
		EndIf
		(cAliasDA1)->(dbCloseArea())
	EndIf

	// Fallback 2 de Preco: Campo B1_PRV1 na SB1
	If nPreco <= 0 .And. SB1->(FieldPos("B1_PRV1")) > 0 .And. SB1->B1_PRV1 > 0
		nPreco := SB1->B1_PRV1
	EndIf

	// 3. Atributos Veiculares de Compatibilidade (Tabela Z08 - Produto x Aplicacao)
	If ChkFile("Z08")
		DbSelectArea("Z08")
		Z08->(DbSetOrder(1)) // Z08_FILIAL + Z08_COD + Z08_MARCA + Z08_MODELO + ...
		If !Z08->(DbSeek(cFilEcom + cCodProd))
			Z08->(DbSeek(xFilial("Z08") + cCodProd))
		EndIf
		If Z08->(Found())
			cMontadora := AllTrim(Z08->Z08_MARCA)
			cModelo    := AllTrim(Z08->Z08_MODELO)
			cAnoDe     := AllTrim(Z08->Z08_ANODE)
			cAnoAte    := AllTrim(Z08->Z08_ANOATE)
			cVersao    := AllTrim(Z08->Z08_MOTOR)
			cAplica    := AllTrim(Z08->Z08_APLICA)

			If !Empty(cAnoDe) .And. !Empty(cAnoAte)
				cFaixaAno := cAnoDe + " a " + cAnoAte
			ElseIf !Empty(cAnoDe)
				cFaixaAno := cAnoDe
			EndIf
		EndIf
	EndIf

	// 4. Numero de Peca / Codigo Original (Tabela Z09)
	If ChkFile("Z09")
		DbSelectArea("Z09")
		Z09->(DbSetOrder(1)) // Z09_FILIAL + Z09_COD + Z09_CODORI
		If !Z09->(DbSeek(cFilEcom + cCodProd))
			Z09->(DbSeek(xFilial("Z09") + cCodProd))
		EndIf
		If Z09->(Found())
			cNumPeca := AllTrim(Z09->Z09_CODORI)
		EndIf
	EndIf
	If Empty(cNumPeca) .And. SB1->(FieldPos("B1_CODFAB")) > 0 .And. !Empty(SB1->B1_CODFAB)
		cNumPeca := AllTrim(SB1->B1_CODFAB)
	EndIf

	// Monta a lista de Custom Fields para a Nuvemshop alinhado aos slugs oficiais cadastrados
	AAdd(aCustomFlds, {"codigo-fortbras", cCodProd})

	If !Empty(cAnoDe)
		AAdd(aCustomFlds, {"ano-inicial", cAnoDe})
	EndIf
	If !Empty(cAnoAte)
		AAdd(aCustomFlds, {"ano-final", cAnoAte})
	EndIf
	If !Empty(cAplica)
		AAdd(aCustomFlds, {"aplicacao", cAplica})
	Else
		AAdd(aCustomFlds, {"aplicacao", cDesc})
	EndIf
	If !Empty(cMontadora)
		AAdd(aCustomFlds, {"montadoras", {"demofortbras/montadora/" + Lower(StrTran(AllTrim(cMontadora), " ", "-"))}})
	EndIf
	If !Empty(cModelo)
		AAdd(aCustomFlds, {"modelos", {"demofortbras/modelo/" + Lower(StrTran(AllTrim(cModelo), " ", "-"))}})
	EndIf
	If !Empty(cNumPeca)
		AAdd(aCustomFlds, {"terminal-de-direcao", cNumPeca})
	EndIf

	// 5. Coleta de Imagens do Produto (SB1->B1_BITMAP, MV_NUVIMG, ZZ_VX3995 e SZ1)
	cUrlBaseImg := AllTrim(cValToChar(SuperGetMV("MV_NUVIMG", .F., SuperGetMV("ZZ_VX3995", .F., "https://b2b.fortbras.com.br/imagens/"))))
	If !Empty(cUrlBaseImg) .And. Right(cUrlBaseImg, 1) != "/"
		cUrlBaseImg += "/"
	EndIf

	If SB1->(FieldPos("B1_BITMAP")) > 0 .And. !Empty(SB1->B1_BITMAP)
		cBitMap := AllTrim(SB1->B1_BITMAP)
		If Lower(SubStr(cBitMap, 1, 4)) == "http"
			AAdd(aImagens, cBitMap)
		Else
			If !Empty(cUrlBaseImg)
				If Lower(Right(cBitMap, 4)) $ ".jpg|.png|.gif|.webp"
					AAdd(aImagens, cUrlBaseImg + cBitMap)
				Else
					AAdd(aImagens, cUrlBaseImg + cBitMap + ".jpg")
				EndIf
			Else
				AAdd(aImagens, cBitMap)
			EndIf
		EndIf
	EndIf

	// Adiciona tambem a foto padrao pelo codigo do produto caso nao exista na lista
	If !Empty(cUrlBaseImg)
		AAdd(aImagens, cUrlBaseImg + cCodProd + "_01.jpg")
	EndIf

	If ChkFile("SZ1")
		DbSelectArea("SZ1")
		SZ1->(DbSetOrder(1))
		If SZ1->(DbSeek(xFilial("SZ1") + cCodProd))
			If SZ1->(FieldPos("Z1_URLIMG")) > 0 .And. !Empty(SZ1->Z1_URLIMG)
				AAdd(aImagens, AllTrim(SZ1->Z1_URLIMG))
			EndIf
			If SZ1->(FieldPos("Z1_FOTO")) > 0 .And. !Empty(SZ1->Z1_FOTO)
				AAdd(aImagens, AllTrim(SZ1->Z1_FOTO))
			EndIf
		EndIf
	EndIf

	// Retorna objeto estruturado
	oData := JsonObject():New()
	oData["codigo"]       := cCodProd
	oData["ref_id"]       := cRefId
	oData["nome"]         := cNome
	oData["descricao"]    := cDesc
	oData["marca"]        := cFabric
	oData["categoria"]    := cCategoria
	oData["grupo"]        := cCodGrupo
	oData["preco"]        := nPreco
	oData["estoque"]      := Int(Max(0, nEstoque))
	oData["peso"]         := nPeso
	oData["altura"]       := nAltura
	oData["largura"]      := nLargura
	oData["comprimento"]  := nComp
	oData["custom_fields"]:= aCustomFlds
	oData["imagens"]      := aImagens

Return oData

/*/{Protheus.doc} ExportProduct
Orquestra o cadastro completo do produto na Nuvemshop:
1. Coleta dados do Protheus
2. Verifica se o SKU ja existe na Nuvemshop (idempotencia)
3. Cria ou Atualiza o Produto
4. Envia os Custom Fields na variante
/*/{Protheus.doc} ExportProduct
Orquestra o cadastro completo do produto na Nuvemshop:
1. Valida elegibilidade B2C (SBZ->BZ_YB2C == 'S') salvo se lForce == .T.
2. Coleta dados do Protheus
3. Verifica se o SKU ja existe na Nuvemshop (idempotencia)
4. Cria ou Atualiza o Produto
5. Envia os Custom Fields na variante
6. Grava os IDs Web na tabela de de-para VT9 / VTD
@param cCodProd, character, Codigo do produto no Protheus
@param lForce, logical, Se .T., forca a exportacao sem validar SBZ->BZ_YB2C (padrao .T. para testes pontuais)
/*/
METHOD ExportProduct(cCodProd, lForce) CLASS NuvemProduto
	Local oProdData     := Nil
	Local oCheckSku     := Nil
	Local oResp         := Nil
	Local cBody         := ""
	Local cBodyVar      := ""
	Local nProdId       := 0
	Local nVariantId    := 0
	Local cSku          := ""
	Local aCustomFields := {}
	Local aImagens      := {}
	Local cPrecoStr     := ""
	Local cPesoStr      := ""
	Local nCatId        := 0
	Local cCatJson      := ""
	Local lSuccess      := .F.
	Local cFilEcom      := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
	Local lIsB2C        := .F.

	Default lForce := .T.

	// Se nao for envio forcado, valida se o item esta aprovado para B2C
	If !lForce .And. ChkFile("SBZ")
		DbSelectArea("SBZ")
		SBZ->(DbSetOrder(1)) // BZ_FILIAL + BZ_COD
		If SBZ->(DbSeek(cFilEcom + cCodProd)) .Or. ;
		   SBZ->(DbSeek(SubStr(cFilEcom, 1, 4) + cCodProd)) .Or. ;
		   SBZ->(DbSeek(xFilial("SBZ") + cCodProd))
			If SBZ->(FieldPos("BZ_YB2C")) > 0
				lIsB2C := (Upper(AllTrim(SBZ->BZ_YB2C)) == "S")
			EndIf
		EndIf
		If !lIsB2C
			ConOut("[NUVEMSHOP][IGNORADO] Produto " + cCodProd + " desconsiderado por nao estar marcado como B2C (SBZ->BZ_YB2C != 'S').")
			Return .F.
		EndIf
	EndIf

	oProdData := ::GetDadosProd(cCodProd)

	If oProdData == Nil
		ConOut("[NUVEMSHOP][ERRO] Produto " + cCodProd + " nao encontrado no Protheus.")
		Return .F.
	EndIf

	cSku          := oProdData["ref_id"]
	aCustomFields := oProdData["custom_fields"]
	aImagens      := oProdData["imagens"]

	cPrecoStr     := AllTrim(Str(oProdData["preco"], 12, 2))
	cPesoStr      := AllTrim(Str(oProdData["peso"], 10, 3))

	// Resolve Categoria na Nuvemshop
	If !Empty(oProdData["categoria"])
		nCatId := ::GetOrCreateCategory(oProdData["categoria"])
	EndIf
	If nCatId > 0
		cCatJson := '  "categories": [' + cValToChar(nCatId) + '],'
	EndIf

	// Verifica se ja existe na Nuvemshop pelo SKU
	oCheckSku := ::CheckSku(cSku)

	If oCheckSku != Nil
		// Produto ja existe na Nuvemshop -> Atualiza Produto e Variante
		nProdId := oCheckSku["id"]
		If ValType(oCheckSku["variants"]) == "A" .And. Len(oCheckSku["variants"]) > 0
			nVariantId := oCheckSku["variants"][1]["id"]
		EndIf
		If nVariantId == 0
			nVariantId := Val(::GetVariantId(cCodProd))
		EndIf

		cBody := '{'
		cBody += '  "name": {"pt": "' + oProdData["nome"] + '"},'
		cBody += '  "description": {"pt": "' + oProdData["descricao"] + '"},'
		cBody += '  "brand": "' + oProdData["marca"] + '"'
		If !Empty(cCatJson)
			cBody += ',' + cCatJson
		EndIf
		cBody += '}'

		oResp := ::UpdateProduct(nProdId, cBody)
		If oResp != Nil
			lSuccess := .T.
			ConOut("[NUVEMSHOP] Produto SKU " + cSku + " atualizado com sucesso. ID: " + cValToChar(nProdId))
		EndIf

		// Atualiza obrigatoriamente a variante com Preco, Peso, Estoque e Dimensoes
		If nVariantId > 0
			cBodyVar := '{'
			cBodyVar += '  "price": "' + cPrecoStr + '",'
			cBodyVar += '  "stock": ' + cValToChar(oProdData["estoque"]) + ','
			cBodyVar += '  "weight": "' + cPesoStr + '",'
			cBodyVar += '  "height": "' + AllTrim(Str(oProdData["altura"], 10, 2)) + '",'
			cBodyVar += '  "width": "' + AllTrim(Str(oProdData["largura"], 10, 2)) + '",'
			cBodyVar += '  "depth": "' + AllTrim(Str(oProdData["comprimento"], 10, 2)) + '"'
			cBodyVar += '}'

			::UpdateVariant(nProdId, nVariantId, cBodyVar)
		EndIf
	Else
		// Produto novo -> Cria via POST /products com a primeira variante completa
		cBody := '{'
		cBody += '  "name": {"pt": "' + oProdData["nome"] + '"},'
		cBody += '  "description": {"pt": "' + oProdData["descricao"] + '"},'
		cBody += '  "brand": "' + oProdData["marca"] + '",'
		cBody += '  "visibility": "visible",'
		If !Empty(cCatJson)
			cBody += cCatJson
		EndIf
		cBody += '  "variants": [{'
		cBody += '    "sku": "' + cSku + '",'
		cBody += '    "price": "' + cPrecoStr + '",'
		cBody += '    "stock": ' + cValToChar(oProdData["estoque"]) + ','
		cBody += '    "weight": "' + cPesoStr + '",'
		cBody += '    "height": "' + AllTrim(Str(oProdData["altura"], 10, 2)) + '",'
		cBody += '    "width": "' + AllTrim(Str(oProdData["largura"], 10, 2)) + '",'
		cBody += '    "depth": "' + AllTrim(Str(oProdData["comprimento"], 10, 2)) + '"'
		cBody += '  }]'
		cBody += '}'

		oResp := ::CreateProduct(cBody)
		If oResp != Nil
			lSuccess   := .T.
			nProdId    := oResp["id"]
			If ValType(oResp["variants"]) == "A" .And. Len(oResp["variants"]) > 0
				nVariantId := oResp["variants"][1]["id"]
			EndIf
			ConOut("[NUVEMSHOP] Produto SKU " + cSku + " criado com sucesso. ID: " + cValToChar(nProdId) + " / VarID: " + cValToChar(nVariantId))
		EndIf
	EndIf

	// Se o produto foi criado/atualizado com sucesso
	If lSuccess .And. nProdId > 0
		// 1. Grava o vinculo no de-para do Protheus (VT9 e VTD)
		::GravaIdWEB(cCodProd, cValToChar(nProdId), cValToChar(nVariantId))

		// 2. Grava os Custom Fields (Montadora, Modelo, Ano, etc.) na Variante
		If nVariantId > 0 .And. Len(aCustomFields) > 0
			::SetCustomFields(nVariantId, aCustomFields)
		EndIf

		// 3. Envia fotos do produto (se houver)
		If Len(aImagens) > 0
			::SendImages(nProdId, aImagens)
		EndIf
	EndIf

	FreeObj(oProdData)
	If oCheckSku != Nil
		FreeObj(oCheckSku)
	EndIf
	If oResp != Nil
		FreeObj(oResp)
	EndIf

Return lSuccess

/*/{Protheus.doc} GravaIdWEB
Persiste o vinculo de IDs externos nas tabelas de de-para VT9 e VTD do Protheus.
/*/
METHOD GravaIdWEB(cCodProd, cProdId, cVarId) CLASS NuvemProduto
	Local cKeyVT9 := ""
	Local cKeyVTD := ""

	DbSelectArea("VT9")
	VT9->(DbSetOrder(3)) // VT9_FILIAL, VT9_CODVT8, VT9_CODVTN, VT9_PRODUT
	cKeyVT9 := xFilial("VT9") + AvKey("NUVEMSHOP", "VT9_CODVT8") + AvKey("DEFAULT", "VT9_CODVTN") + AvKey(cCodProd, "VT9_PRODUT")

	If VT9->(DbSeek(cKeyVT9))
		RecLock("VT9", .F.)
		VT9->VT9_IDWEB := cProdId
		If VT9->(FieldPos("VT9_API")) > 0
			VT9->VT9_API := "NUVEMSHOP"
		EndIf
		VT9->(MsUnlock())
	Else
		RecLock("VT9", .T.)
		VT9->VT9_FILIAL := xFilial("VT9")
		VT9->VT9_PRODUT := cCodProd
		VT9->VT9_IDWEB  := cProdId
		If VT9->(FieldPos("VT9_API")) > 0
			VT9->VT9_API    := "NUVEMSHOP"
		EndIf
		VT9->VT9_CODVT8 := AvKey("NUVEMSHOP", "VT9_CODVT8")
		VT9->VT9_CODVTN := AvKey("DEFAULT", "VT9_CODVTN")
		VT9->(MsUnlock())
	EndIf

	DbSelectArea("VTD")
	VTD->(DbSetOrder(2)) // VTD_FILIAL, VTD_CODVT8, VTD_CODVTN, VTD_PRODUT, VTD_IDSKU
	cKeyVTD := xFilial("VTD") + AvKey("NUVEMSHOP", "VTD_CODVT8") + AvKey("DEFAULT", "VTD_CODVTN") + AvKey(cCodProd, "VTD_PRODUT")

	If VTD->(DbSeek(cKeyVTD))
		RecLock("VTD", .F.)
		VTD->VTD_IDWEB := cProdId
		VTD->VTD_IDSKU := cVarId
		VTD->(MsUnlock())
	Else
		RecLock("VTD", .T.)
		VTD->VTD_FILIAL := xFilial("VTD")
		VTD->VTD_PRODUT := cCodProd
		VTD->VTD_IDWEB  := cProdId
		VTD->VTD_IDSKU  := cVarId
		VTD->VTD_CODVT8 := AvKey("NUVEMSHOP", "VTD_CODVT8")
		VTD->VTD_CODVTN := AvKey("DEFAULT", "VTD_CODVTN")
		VTD->(MsUnlock())
	EndIf
Return .T.

/*/{Protheus.doc} UpdtAtuWeb
Sincroniza estoques e precos com a Nuvemshop para os itens pendentes na fila VTF.
/*/
METHOD UpdtAtuWeb() CLASS NuvemProduto
	Local cQuery    := ""
	Local cAliasVTF := GetNextAlias()
	Local nCont     := 0
	Local cProduto  := ""
	Local nRecVTF   := 0
	Local cVarId    := ""
	Local cProdId   := ""
	Local nPreco    := 0
	Local nEstoque  := 0
	Local cBodyVar  := ""
	Local oData     := Nil
	Local oRespVar  := Nil
	Local cFilEcom  := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))

	cQuery := "SELECT VTF.R_E_C_N_O_ AS RECVTF, VTF.VTF_PRODUT, VTF.VTF_TABELA "
	cQuery += " FROM " + RetSqlName("VTF") + " VTF "
	cQuery += " WHERE VTF.D_E_L_E_T_ = ' ' "
	cQuery += "   AND VTF.VTF_API = 'NUVEMSHOP' "
	cQuery += "   AND VTF.VTF_ATUWEB = 'S' "

	cQuery := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasVTF, .F., .T.)

	While !(cAliasVTF)->(Eof())
		cProduto := AllTrim((cAliasVTF)->VTF_PRODUT)
		nRecVTF  := (cAliasVTF)->RECVTF
		cVarId   := ::GetVariantId(cProduto)
		cProdId  := ::GetProductId(cProduto)

		If !Empty(cVarId) .And. !Empty(cProdId)
			// Coleta dados comerciais completos com fallbacks de preco e saldo disponivel
			oData := ::GetDadosProd(cProduto)
			If oData != Nil
				nPreco   := oData["preco"]
				nEstoque := oData["estoque"]
				FreeObj(oData)
			EndIf

			cBodyVar := '{'
			cBodyVar += '  "price": "' + AllTrim(Str(nPreco, 12, 2)) + '",'
			cBodyVar += '  "stock": ' + cValToChar(nEstoque)
			cBodyVar += '}'

			oRespVar := ::UpdateVariant(Val(cProdId), Val(cVarId), cBodyVar)
			If oRespVar != Nil
				dbSelectArea("VTF")
				VTF->(dbGoTo(nRecVTF))
				RecLock("VTF", .F.)
				VTF->VTF_ATUWEB := "N"
				VTF->(MsUnLock())
				nCont++
				ConOut("[NUVEMSHOP] Fila VTF: Produto " + cProduto + " atualizado na Nuvemshop (Preco R$ " + AllTrim(Str(nPreco, 12, 2)) + " / Est " + cValToChar(nEstoque) + ")")
				FreeObj(oRespVar)
			Else
				ConOut("[NUVEMSHOP][ERRO] Fila VTF: Falha ao atualizar variante " + cVarId + " do produto " + cProduto)
			EndIf
		Else
			// Sem vinculo na Nuvemshop -> verifica se eh produto B2C para cadastrar automaticamente
			If ChkFile("SBZ")
				DbSelectArea("SBZ")
				SBZ->(DbSetOrder(1))
				If (SBZ->(DbSeek(cFilEcom + cProduto)) .Or. ;
				    SBZ->(DbSeek(SubStr(cFilEcom, 1, 4) + cProduto)) .Or. ;
				    SBZ->(DbSeek(xFilial("SBZ") + cProduto))) .And. ;
				   SBZ->(FieldPos("BZ_YB2C")) > 0 .And. Upper(AllTrim(SBZ->BZ_YB2C)) == "S"
					ConOut("[NUVEMSHOP] Fila VTF: Produto B2C " + cProduto + " sem vinculo. Realizando primeiro cadastro na Nuvemshop...")
					If ::ExportProduct(cProduto, .T.)
						nCont++
					EndIf
				Else
					ConOut("[NUVEMSHOP][AVISO] Fila VTF: Produto " + cProduto + " sem vinculo e nao marcado como B2C (SBZ->BZ_YB2C). Baixando da fila.")
				EndIf
			Else
				ConOut("[NUVEMSHOP][AVISO] Fila VTF: Produto " + cProduto + " sem vinculo nas tabelas VT9/VTD. Baixando da fila.")
			EndIf

			dbSelectArea("VTF")
			VTF->(dbGoTo(nRecVTF))
			RecLock("VTF", .F.)
			VTF->VTF_ATUWEB := "N"
			VTF->(MsUnLock())
		EndIf

		(cAliasVTF)->(dbSkip())
	EndDo
	(cAliasVTF)->(dbCloseArea())

	ConOut("[NUVEMSHOP] Processamento da fila VTF concluido. Total de itens atualizados: " + cValToChar(nCont))
Return .T.

/*/{Protheus.doc} SendBatch
Mantido para compatibilidade com chamadas legado de atualizacao em lote.
/*/
METHOD SendBatch(aLote) CLASS NuvemProduto
Return .T.

/*/{Protheus.doc} GetVariantId
Recupera o ID da variante na Nuvemshop consultando a tabela de de-para VT9 / VTD.
/*/
METHOD GetVariantId(cCodProd) CLASS NuvemProduto
	Local cVariantId := ""
	Local cQuery     := ""
	Local cAliasVTD  := GetNextAlias()

	cQuery := "SELECT VTD.VTD_IDSKU, VTD.VTD_IDWEB "
	cQuery += " FROM " + RetSqlName("VTD") + " VTD "
	cQuery += " WHERE VTD.D_E_L_E_T_ = ' ' "
	cQuery += "   AND VTD.VTD_CODVT8 = '" + AvKey("NUVEMSHOP", "VTD_CODVT8") + "' "
	cQuery += "   AND VTD.VTD_PRODUT = '" + cCodProd + "' "

	cQuery := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasVTD, .F., .T.)

	If !(cAliasVTD)->(Eof())
		cVariantId := AllTrim((cAliasVTD)->VTD_IDSKU)
		If Empty(cVariantId)
			cVariantId := AllTrim((cAliasVTD)->VTD_IDWEB)
		EndIf
	EndIf
	(cAliasVTD)->(dbCloseArea())

	If Empty(cVariantId)
		cVariantId := ::GetProductId(cCodProd)
	EndIf

Return cVariantId

/*/{Protheus.doc} GetProductId
Recupera o ID do produto na Nuvemshop consultando a tabela de de-para VT9.
/*/
METHOD GetProductId(cCodProd) CLASS NuvemProduto
	Local cProdId   := ""
	Local cQuery    := ""
	Local cAliasVT9 := GetNextAlias()

	cQuery := "SELECT VT9_IDWEB "
	cQuery += " FROM " + RetSqlName("VT9") + " VT9 "
	cQuery += " WHERE VT9.D_E_L_E_T_ = ' ' "
	cQuery += "   AND VT9.VT9_API = 'NUVEMSHOP' "
	cQuery += "   AND VT9.VT9_PRODUT = '" + cCodProd + "' "

	cQuery := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasVT9, .F., .T.)

	If !(cAliasVT9)->(Eof())
		cProdId := AllTrim((cAliasVT9)->VT9_IDWEB)
	EndIf
	(cAliasVT9)->(dbCloseArea())

Return cProdId

/*/{Protheus.doc} ExportAllB2C
Realiza a carga e sincronizacao em lote de todos os produtos homologados para o
canal B2C da Fortbras na Nuvemshop, filtrando os registros onde SBZ->BZ_YB2C == 'S'
e o cadastro de produto nao esteja bloqueado (SB1->B1_MSBLQL != '1').

@param cFilialP, character, Filial de estoque/preco a considerar (opcional, padrao MV_NUVFIL)
@param bProgress, block, Bloco de codigo opcional para callback de progresso:
                  Eval(bProgress, nAtual, nTotal, cCodProd, lOk, cMsg)
@return oResult, JsonObject, Objeto com estatisticas: total, sucessos, erros, falhas
/*/
METHOD ExportAllB2C(cFilialP, bProgress) CLASS NuvemProduto
	Local cFilEcom   := ""
	Local cQuery     := ""
	Local cAliasQry  := GetNextAlias()
	Local aProdutos  := {}
	Local aFalhas    := {}
	Local nTotal     := 0
	Local nSucessos  := 0
	Local nErros     := 0
	Local nI         := 0
	Local cCodProd   := ""
	Local lOk        := .F.
	Local oResult    := JsonObject():New()
	Local cMsgErr    := ""

	Default cFilialP := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))
	cFilEcom := cFilialP
	If Empty(cFilEcom)
		cFilEcom := cFilAnt
	EndIf

	ConOut("[NUVEMSHOP][CARGA TOTAL B2C] Iniciando levantamento de produtos B2C para a filial: " + cFilEcom)

	// Valida se a tabela SBZ e o campo BZ_YB2C existem no dicionario
	If !ChkFile("SBZ")
		ConOut("[NUVEMSHOP][ERRO] Tabela SBZ (Indicadores de Produto) nao encontrada.")
		oResult["total"]    := 0
		oResult["sucessos"] := 0
		oResult["erros"]    := 1
		oResult["falhas"]   := {{"SBZ", "Tabela SBZ nao encontrada no ambiente"}}
		Return oResult
	EndIf

	DbSelectArea("SBZ")
	If SBZ->(FieldPos("BZ_YB2C")) == 0
		ConOut("[NUVEMSHOP][ERRO] Campo BZ_YB2C nao encontrado na tabela SBZ.")
		oResult["total"]    := 0
		oResult["sucessos"] := 0
		oResult["erros"]    := 1
		oResult["falhas"]   := {{"SBZ", "Campo BZ_YB2C nao existe na SBZ"}}
		Return oResult
	EndIf

	// Montagem da query de selecao de produtos B2C
	cQuery := "SELECT DISTINCT SB1.B1_COD "
	cQuery += " FROM " + RetSqlName("SB1") + " SB1 "
	cQuery += " INNER JOIN " + RetSqlName("SBZ") + " SBZ "
	cQuery += "    ON SBZ.BZ_COD = SB1.B1_COD "
	cQuery += "   AND (SBZ.BZ_FILIAL = '" + cFilEcom + "' OR SBZ.BZ_FILIAL = '" + SubStr(cFilEcom, 1, 4) + "' OR SBZ.BZ_FILIAL = '" + xFilial("SBZ") + "' OR SBZ.BZ_FILIAL = ' ') "
	cQuery += "   AND (SBZ.BZ_YB2C = 'S' OR SBZ.BZ_YB2C = 's') "
	cQuery += "   AND SBZ.D_E_L_E_T_ = ' ' "
	cQuery += " WHERE SB1.D_E_L_E_T_ = ' ' "
	cQuery += "   AND (SB1.B1_FILIAL = '" + xFilial("SB1") + "' OR SB1.B1_FILIAL = '" + cFilEcom + "' OR SB1.B1_FILIAL = '" + SubStr(cFilEcom, 1, 4) + "' OR SB1.B1_FILIAL = ' ') "
	cQuery += "   AND (SB1.B1_MSBLQL <> '1' OR SB1.B1_MSBLQL = ' ' OR SB1.B1_MSBLQL IS NULL) "
	cQuery += " ORDER BY SB1.B1_COD "

	cQuery := ChangeQuery(cQuery)
	dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasQry, .F., .T.)

	While !(cAliasQry)->(Eof())
		AAdd(aProdutos, AllTrim((cAliasQry)->B1_COD))
		(cAliasQry)->(dbSkip())
	EndDo
	(cAliasQry)->(dbCloseArea())

	nTotal := Len(aProdutos)
	ConOut("[NUVEMSHOP][CARGA TOTAL B2C] Total de produtos B2C identificados na filial " + cFilEcom + ": " + cValToChar(nTotal))

	If nTotal == 0
		oResult["total"]    := 0
		oResult["sucessos"] := 0
		oResult["erros"]    := 0
		oResult["falhas"]   := {}
		Return oResult
	EndIf

	// Processa cada produto da lista
	For nI := 1 To nTotal
		cCodProd := aProdutos[nI]

		// Exporta o produto (forcar = .T. pois a query ja garantiu BZ_YB2C = 'S')
		lOk := ::ExportProduct(cCodProd, .T.)

		If lOk
			nSucessos++
			cMsgErr := "OK"
		Else
			nErros++
			cMsgErr := ::GetLastError()
			AAdd(aFalhas, {cCodProd, cMsgErr})
			ConOut("[NUVEMSHOP][FALHA EXPORTACAO] Produto: " + cCodProd + " Erro: " + cMsgErr)
		EndIf

		// Notifica o callback de progresso se fornecido
		If bProgress != Nil
			Eval(bProgress, nI, nTotal, cCodProd, lOk, cMsgErr)
		EndIf

		// Intervalo de protecao contra rate limit da Nuvemshop (1 req/s)
		Sleep(500)
	Next nI

	ConOut("[NUVEMSHOP][CARGA TOTAL B2C] Finalizado! Total: " + cValToChar(nTotal) + " Sucessos: " + cValToChar(nSucessos) + " Erros: " + cValToChar(nErros))

	oResult["total"]    := nTotal
	oResult["sucessos"] := nSucessos
	oResult["erros"]    := nErros
	oResult["falhas"]   := aFalhas

Return oResult
