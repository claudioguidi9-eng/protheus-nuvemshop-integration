#INCLUDE "PROTHEUS.CH"
#Include "aarray.ch"
#Include 'FWMVCDef.ch'
#INCLUDE "TBICONN.CH"
#INCLUDE "TOPCONN.CH"

//===================================================================

Class ECPEDIDO From SchedAcesso

	Data cEmpCli
	Data cFilCli

	Data aNotaFiscal
	Data lPedFatTot

	Data cCodVT8
	Data cCodVTR
	Data cCodSA3
	Data cCodVTQ
	Data cCodVTP
	Data cCodA1U
	Data cCodVTN
	Data cCodTipPed
	Data cPednum

	Data cTipo
	Data cApi
	Data cOrderID
	Data cSequence
	Data cStatus
	Data nValFrete
	Data nTotalPedido
	Data nTotalPedLiq
	Data dDtIntegracao
	Data cHrIntegracao
	Data dDtPagamento
	Data cHrPagamento

	Data dDtIntHUB
	Data cHrIntHUB
	Data dDtPGHUB
	Data cHrPGHUB
	Data dDtPGERP
	Data cHrPGERP
	Data cIdHub

	Data cObservacao
	Data cNumPedido
	Data cStatusAnterior
	Data dDtUltAlteracao
	Data cHrUltAlteracao
	Data cModalidadeFrete
	Data cIdCarrinho
	Data cJson
	Data cCodCliente
	Data cLojaCliente
	Data cMunicipio
	Data cTransp
	Data cNewStatus
	Data lContinua
	Data cTipoFrete
	Data nPercDesc
	Data dDtWeb
	Data cHoraWeb
	Data dDataEntrega
	Data cTipoExpedicao
	Data dDtVirada
	Data cCodPag
	Data cOperador

	Data aPedItens

	Data nVlrCustoFrete As Numeric
	Data cIdCotacao As Character


	Method New() CONSTRUCTOR

	/*===================================================
		Get - busca
		Start - prepara
		Upd - Atualiza
		Create - Cria
	===================================================*/

	//Métodos de busca de informações
	Method GetVendedor()
	Method GetTransp()
	Method GetProduto()
	Method GetModFrete()
	Method GetDataEntrega()
	Method GetIsFatERP()
	Method GetIsFatWEB()
	Method GetIsForCanc()
	Method GetNotaFiscal()
	Method GetCondicao()
	Method GetOperador()

	//Método de inserção de registros
	Method CreateSC5Ped()
	Method CreateSL1Ped()
	Method CreateSUAPed()
	Method CreatePedWeb()

	//Methods para processamento dos pedidos
	Method StartPedAny()
	Method StartPedCock()
	Method StartPedVTEX()
	Method StartPedMagento()
	Method StartPed00K()
	Method StartPedCWS()
	Method StartPedNuvem()

	Method StartPedido()
	Method StartModFrete()

	// Cancelamentos dos pedidos
	Method StartERPCanc()
	Method StartWEBCanc()
	Method StartFORCanc()
	Method StartSL1Canc()
	Method StartSC5Canc()
	Method StartSUACanc()

	Method VldPedTroca()

	// Informações de Cancelamentos
	Method StartResiduoSC5()

	// Method para realizar o estorno
	Method StartOpenPed()

	//Métodos de atualização de registros
	Method UpdVT1()
	
	// Método para posicionar registro da VT1
	Method SetVT1()

	// Reserva de estoque para pedidos
	Method CreateReserva()
	Method CreateResSUA()

EndClass

//===================================================================

Method NEW() Class ECPEDIDO

	//Inicializa Metodos New da Classe RestAcesso
	_Super:New()

	::cEmpCli			:= cEmpAnt
	::cFilCli			:= cFilAnt
	::aNotaFiscal 		:= {}
	::lPedFatTot 		:= .f.

	::cCodVT8      		:= ""
	::cCodVTR      		:= ""
	::cCodSA3     		:= ""
	::cCodVTQ     		:= ""
	::cCodVTP     		:= ""
	::cCodA1U 			:= ""
	::cCodVTN 			:= ""	
	::cCodTipPed       	:= ""
	::cCodPag			:= ""
	::cPednum			:= ""
	::cTipo				:= "B2C"
	::cApi				:= ""
	::cOrderID			:= ""
	::cSequence			:= ""
	::cStatus			:= ""
	::nValFrete			:= 0
	::nTotalPedido		:= 0
	::nTotalPedLiq		:= 0
	::dDtIntegracao		:= CTOD("")
	::cHrIntegracao		:= ""
	::dDtPagamento		:= CTOD("")
	::cHrPagamento		:= ""
	::cObservacao		:= ""
	::cNumPedido		:= ""
	::cStatusAnterior	:= ""
	::dDtUltAlteracao	:= CTOD("")
	::cHrUltAlteracao	:= ""
	::dDtIntHUB			:= CTOD("")
	::cHrIntHUB			:= ""
	::dDtPGHUB			:= CTOD("")
	::cHrPGHUB			:= ""
	::dDtPGERP			:= CTOD("")
	::cHrPGERP			:= ""
	::cModalidadeFrete	:= ""
	::cIdCarrinho		:= ""
	::cJson				:= ""
	::cCodCliente		:= ""
	::cLojaCliente		:= ""
	::cMunicipio		:= ""
	::aPedItens			:= {}
	::cTransp			:= ''
	::cNewStatus		:= ''
	::lContinua			:= .T.
	::cTipoFrete		:= "C"
	::nPercDesc			:= 0
	::dDtWeb			:= CTOD("")
	::cHoraWeb			:= ""
	::dDataEntrega		:= CTOD("")
	::dDtVirada			:= STOD(SuperGetMv("FB_DTERPHP",.F.,"20240912"))

	::cCodTipPed		:= "SC5" // 1 - SC5, 2- SL1
	::cTipoExpedicao	:= "1" // 1 - LOJA ENTREGA, 2 - CLIENTE RETIRA

	::nVlrCustoFrete 	:= 0
	::cIdCotacao 		:= ""

Return

//===================================================================

Method CreatePedWeb() Class ECPEDIDO

	::cOrderID 	:= PADR(::cOrderID	,TamSx3("VT1_ORDID")[1])
	::cAPI 	   	:= PADR(::cAPI		,TamSx3("VT1_API")[1])
 
	If ::lContinua 
	
 		If !::SetVt1()

			RecLock("VT1", .T.)
				
				VT1->VT1_FILIAL	:= xFilial("VT1")
				VT1->VT1_API	:= ::cAPI
				VT1->VT1_ORDID	:= ::cOrderID
				VT1->VT1_SEQUEN	:= ::cSequence
				VT1->VT1_IDCART := ::cIdCarrinho
				VT1->VT1_NUMPED	:= ::cPednum
				VT1->VT1_CODCLI := ::cCodCliente
				VT1->VT1_LOJCLI := ::cLojaCliente
				VT1->VT1_MUN	:= ::cMunicipio
				VT1->VT1_FRETE  := ::nValFrete
				VT1->VT1_MODFRE	:= ::cModalidadeFrete
				VT1->VT1_JSON   := ::cJson
				VT1->VT1_HORAIN	:= Time()
				VT1->VT1_DATAIN	:= dDataBase
				VT1->VT1_DATAUL := dDataBase
				VT1->VT1_HORAUL := Time()
				VT1->VT1_DATAPG	:= ::dDtPagamento
				VT1->VT1_HORAPG	:= ::cHrPagamento
				VT1->VT1_STATUS	:= ::cStatus
				VT1->VT1_DTWEB	:= ::dDtWeb
				VT1->VT1_HRWEB	:= ::cHoraWeb
				VT1->VT1_DTCHUB := ::dDtIntHUB
				VT1->VT1_HRCHUB := ::cHrIntHUB
				VT1->VT1_DTPHUB := ::dDtPGHUB
				VT1->VT1_HRPHUB := ::cHrPGHUB	
				VT1->VT1_DTPGRE := ::dDtPGERP
				VT1->VT1_HRPGRE := ::cHrPGERP
				VT1->VT1_OBS	:= IIF(!Empty(::cObservacao),::cObservacao,VT1->VT1_OBS)
				VT1->VT1_CODVTR := ::cCODVTR
				VT1->VT1_CODVTQ := ::cCODVTQ
				VT1->VT1_CODVT8 := ::cCODVT8
				VT1->VT1_CODVTP := ::cCODVTP
				VT1->VT1_CODSA3 := ::cCODSA3
				VT1->VT1_TIPPED := ::cCodTipPed
				VT1->VT1_CODA1U := ::cCODA1U
				VT1->VT1_CODVTN := ::cCODVTN
				VT1->VT1_TPENTR := ::cTipoExpedicao				
				VT1->VT1_CFRETE := ::nVlrCustoFrete
				VT1->VT1_IDCOTA := ::cIdCotacao

			VT1->(msUnlock())

			::lContinua := .T.  
		Else

			If VT1->(SimpleLock())
				VT1->VT1_FRETE  := ::nValFrete
				VT1->VT1_MODFRE	:= ::cModalidadeFrete
				VT1->VT1_JSON   := ::cJson
				VT1->VT1_DATAUL := dDataBase
				VT1->VT1_HORAUL := Time()
				VT1->VT1_DATAPG	:= ::dDtPagamento
				VT1->VT1_HORAPG	:= ::cHrPagamento
				VT1->VT1_DTPHUB := ::dDtPGHUB
				VT1->VT1_HRPHUB := ::cHrPGHUB	
				VT1->VT1_DTPGRE := ::dDtPGERP
				VT1->VT1_HRPGRE := ::cHrPGERP
				VT1->VT1_STATUS	:= IIF(!Empty(::cStatus),::cStatus,VT1->VT1_STATUS)
				VT1->VT1_OBS	:= IIF(!Empty(::cObservacao),::cObservacao,VT1->VT1_OBS)
				VT1->VT1_CODVTR := ::cCODVTR
				VT1->VT1_CODVTQ := ::cCODVTQ
				VT1->VT1_CODVT8 := ::cCODVT8
				VT1->VT1_CODVTP := ::cCODVTP
				VT1->VT1_CODSA3 := ::cCODSA3
				VT1->VT1_TIPPED := ::cCodTipPed
				VT1->VT1_CODA1U := ::cCODA1U
				VT1->VT1_CODVTN := ::cCODVTN
				VT1->VT1_TPENTR := ::cTipoExpedicao
				VT1->VT1_CFRETE := ::nVlrCustoFrete
				VT1->VT1_IDCOTA := ::cIdCotacao

				VT1->(msUnlock())
			Else
				::lContinua		:= .F.
			EndIf
		EndIf

	EndIf 

Return
Method StartWEBCanc() Class ECPEDIDO

	Local lRet := .t. 

	::cOrderID := PADR(::cOrderID ,TamSX3("VT1_ORDID")[1])
	::cAPI     := PADR(::cAPI     ,TamSX3("VT1_API")[1])
	::cSequence:= PADR(::cSequence,TamSX3("VT1_SEQUEN")[1])

 	If ::SetVT1() 
		
		Do Case 
		Case Alltrim(VT1->VT1_API) == "LINKAPI"

			oVtexPed := VTEXOrder():New()
			lRet := oVtexPed:StartCancel(VT1->VT1_ORDID)

		Case Alltrim(VT1->VT1_API) == "ANYMARKET"

			oAnyPed	:= AnyPedido():New(VT1->VT1_ORDID)
			lRet := oAnyPed:SetCancelar(VT1->VT1_ORDID,"Pedido Cancelado pela Hipervarejo")

		Case Alltrim(VT1->VT1_API) == "COCKPIT"

			oCockPed	:= CockPedido():New(VT1->VT1_ORDID)
			lRet := oCockPed:SetCancelar(VT1->VT1_ORDID,"Pedido Cancelado pela Hipervarejo")

		End Case
	End if 

Return lRet

Method StartPedido() Class ECPEDIDO

	Local cLockName := ""
	Local lLocked   := .F.

	::cOrderID := PADR(::cOrderID ,TamSX3("VT1_ORDID")[1])
	::cAPI     := PADR(::cAPI     ,TamSX3("VT1_API")[1])
	::cSequence:= PADR(::cSequence,TamSX3("VT1_SEQUEN")[1])

	cLockName := "StartPedido" + xFilial("VT1") + "|" + AllTrim(::cOrderID) + "|" + AllTrim(::cAPI)

	If !(lLocked := LockByName(cLockName, .T., .T., .T.))
		FWLogMsg("INFO", , "INFO", , , , "Rotina StartPedido esta sendo executada por outra instancia. PEDIDO WEB: " + AllTrim(::cOrderID) + " API: " + AllTrim(::cAPI), , , )
		Return()
	EndIf
 
 	If ::SetVT1()
	
	 	If VT1->(SimpleLock())

			// Regra Nuvemshop: Garante preenchimento de VT1_DTWEB e VT1_HRWEB caso venham vazios
			If AllTrim(::cAPI) == "NUVEMSHOP" .And. (Empty(VT1->VT1_DTWEB) .Or. VT1->VT1_DTWEB <= ::dDtVirada)
				VT1->VT1_DTWEB := IIf(!Empty(VT1->VT1_DATAIN), VT1->VT1_DATAIN, dDataBase)
				VT1->VT1_HRWEB := IIf(!Empty(VT1->VT1_HORAIN), VT1->VT1_HORAIN, Time())
			EndIf

			// Seguranca para nao processar pedidos antigos e mandar duas vezes ao cliente na virada do sistema Projeto GOL
			If (Empty(VT1->VT1_DTWEB) .or. VT1->VT1_DTWEB <= ::dDtVirada) .And. AllTrim(::cAPI) <> "NUVEMSHOP"

				aAdd(::aMsgErro, "O Pedido se encontra com data WEB (VT1_DTWEB) menor ou igual a data de corte (FB_DTERPHP), desta forma nao sera processado.")

				::lContinua  := .F.
				::cNewStatus := "P"

			Else  

				::UpdVT1() //atualiza para em processamento

				Do Case
	
					Case ALLTRIM(::cAPI) == "LINKAPI"
						::StartPedVTEX()

					Case ALLTRIM(::cAPI) == "ANYMARKET"
						::StartPedAny()

					Case ALLTRIM(::cAPI) == "COCKPIT"
						::StartPedCock()

					Case ALLTRIM(::cAPI) == "CWS"
						::StartPedCWS()
				
					Case ALLTRIM(::cAPI) == "NUVEMSHOP"
						::StartPedNuvem()

				End Case
			EndIf

			::UpdVT1()

			VT1->(MsUnlock())

		EndIf 
	
	EndIf

	If lLocked
		UnLockByName(cLockName, .T., .T., .T.)
	EndIf

Return()


Method StartOpenPed() Class ECPEDIDO

	Local lRet 		:= .t. 
	Local cUpdate	:= ""
 	Local cALiasVT4 := GetNextAlias()

	::cOrderID := PADR(::cOrderID ,TamSX3("VT1_ORDID")[1])
	::cAPI     := PADR(::cAPI     ,TamSX3("VT1_API")[1])
	::cSequence:= PADR(::cSequence,TamSX3("VT1_SEQUEN")[1])

	Begin Transaction

 	If ::SetVT1()

		::cNumPedido := VT1->VT1_NUMPED

		BeginSQL Alias cAliasVT4 

			%NoParser%

			SELECT VT4_EMPFOR,VT4_FILFOR,VT4_NUMPED FROM %Table:VT4% VT4 

			WHERE VT4.D_E_L_E_T_ =''
			AND VT4.VT4_FILIAL = %xFilial:VT4%
			AND VT4.VT4_ORDID = %Exp:VT1->VT1_ORDID%
			AND VT4.VT4_API = %Exp:VT1->VT1_API%
			AND VT4.VT4_SEQUEN = %Exp:VT1->VT1_SEQUEN%

			UNION 
			SELECT %Exp:cEmpAnt%, %Exp:cFilAnt%, %Exp:VT1->VT1_NUMPED%
		EndSQL 

		While (cAliasVT4)->(!EOF())

			cUpdate := " UPDATE " + RetFullName("SC5",(cAliasVT4)->VT4_EMPFOR) + " SET C5_YPEDWEB ='', C5_YAPI ='' " + CRLF
			cUpdate += " WHERE C5_FILIAL = '" + (cAliasVT4)->VT4_FILFOR + "' AND C5_YPEDWEB ='" + VT1->VT1_ORDID + "' AND C5_YAPI ='" + VT1->VT1_API + "'"

			cUpdate := U_MontaUpd(cUpdate)
			nRet 	:= TcSqlExec(cUpdate)

			If nRet < 0 
				lRet := .f. 
				Exit
			End if 

			(cAliasVT4)->(DbSkip())
		Enddo

		If lRet 

			VT4->(DbSetOrder(1)) //VT4_FILIAL, VT4_API, VT4_ORDID, VT4_SEQUEN, VT4_EMPFOR, VT4_FILFOR, R_E_C_N_O_, D_E_L_E_T_
			If VT4->(DbSeek(xFilial('VT4')+VT1->(VT1_API+VT1_ORDID+VT1_SEQUEN)))

				While VT4->(!EOF()) .AND. VT4->(VT4_FILIAL+VT4_API+VT4_ORDID+VT4_SEQUEN) == VT1->(VT1_FILIAL+VT1_API+VT1_ORDID+VT1_SEQUEN)

					Reclock("VT4",.F.)
						VT4->(DbDelete())
					VT4->(MsUnLock())

					VT4->(dbSkip())
				EndDo
			End if 

			Reclock("VT1",.F.)
			VT1->VT1_OBS	:= ""
 			VT1->VT1_STATUS	:= ""
			VT1->VT1_STATAN	:= ""
			VT1->VT1_NUMPED	:= ""
			VT1->(MsUnLock())

		Else 
			DisarmTransaction()
		End if 
	Else 
		lRet := .F. 
	End if 

	(cALiasVT4)->(DbCloseArea())

 	End Transaction
Return lRet
 
Method StartERPCanc(dDtCancel,cHrCancel,lCancJob) Class ECPEDIDO

	Local lRet 		 	:= .T.
	Local lCancela 		:= .F. 

	Default lCancJob 	:= .f. 
	Default dDtCancel	:= DDATABASE
	Default cHrCancel	:= time()

	::cOrderID := PADR(::cOrderID ,TamSX3("VT1_ORDID")[1])
	::cAPI     := PADR(::cAPI     ,TamSX3("VT1_API")[1])
	::cSequence:= PADR(::cSequence,TamSX3("VT1_SEQUEN")[1])

 	VTR->(DbSetOrder(2)) 	//VTR_FILIAL, VTR_ERPGRP, VTR_ERPFIL, R_E_C_N_O_, D_E_L_E_T_

	If ::SetVT1()

		::cNumPedido := VT1->VT1_NUMPED
		
		// Verifica se o pedido se encontra já como CANCELADO ou EXCLUIDO
		// nos status finais do cancelamento
		If Alltrim(UPPER(VT1->VT1_STATUS)) $ "E/C"
			::lContinua := .T. 
			Return ::lContinua 
		End if 

		If VT1->(SimpleLock())

			// Verifica se o pedido se encontra faturado
			If ::GetIsFatWEB()

				cObs := "Pedido informado está Aguardando Devolução por:" + chr(13) + chr(10)
				cObs += "API......: " + Alltrim(VT1->VT1_API) + chr(13) + chr(10)
				cObs += "Data Env.: " + DTOC(DDATABASE) + " " + TIME()  + chr(13) + chr(10)
				cObs += "Data Can.: " + DTOC(dDtCancel) + " " + cHrCancel  + chr(13) + chr(10)
				cObs += chr(13) + chr(10)
				cObs += "OBS:...... " +  "Foi solicitado Cancelamento do Pedido. Porém, o ERP identificou que possui nota fiscal valida emitida. Desta forma, o pedido se encontra aguardando o processo de devolução. Espere a Logistica emitir a NFD para realizar o cancelamento da integração no ERP."
				cObs += chr(13) + chr(10)
				lRet := .T. 

				// Aguardando Nota Fiscal de Devolução
				Reclock("VT1",.F.)
					VT1->VT1_STATUS := "T"
					VT1->VT1_OBS	:= cObs
				VT1->(MsUnLock())

				::lContinua := .T. 

			Else

				// Verifica se existe pedido ERP
				If !Empty(::cNumPedido)

					// Verifica se o cancelamento acontece via JOB (ECJOB_X)
					If lCancJob

						Reclock("VT1",.F.)
							VT1->VT1_STATUS := "X"
							VT1->VT1_OBS	:= "Aguardando cancelamentos dos pedidos (Cliente e Fornecedores)"
						VT1->(MsUnLock())

					Else 

						// Efetua o cancelamento no ERP
						If Alltrim(::cCodTipPed) == "SL1"		// SL1 - Venda Assistida

							lCancela := ::StartSL1Canc()

						Elseif Alltrim(::cCodTipPed) == "SC5"	// SC5 - Pedido de Venda

							lCancela := ::StartSC5Canc()

						Elseif Alltrim(::cCodTipPed) == "SUA"	// SUA - Call Center

							lCancela := ::StartSUACanc()

						Endif

					EndIf

				Else 
					
					lCancela := .T. 

				EndIf

			EndIf

			// Cancela o pedido no E-Commerce se os fornecedores
			// também conseguiram cancelar seus pedidos de vendas
			If lCancela .AND. ::GetIsForCanc()

				RecLock("VT1",.f.)
				VT1->VT1_STATUS	:= "C"
				VT1->VT1_STATAN	:= ""
				VT1->VT1_OBS	:= "Pedido Cancelado com Sucesso!!"
				VT1->(msUnlock())

				::lContinua := .T.
			End if


			VT1->(MsUnlock())
		Else
			::lContinua := .f.
		Endif

	Else
		::lContinua := .f.
	Endif

Return ::lContinua 
 
Method StartSC5Canc() Class ECPEDIDO

	::cOrderID := PADR(::cOrderID ,TamSX3("VT1_ORDID")[1])
	::cAPI     := PADR(::cAPI     ,TamSX3("VT1_API")[1])
	::cSequence:= PADR(::cSequence,TamSX3("VT1_SEQUEN")[1])

 	If ::SetVT1()

		If VT1->(SimpleLock())

			// Atualiza para em processamento
			::UpdVT1() 

			// Elimina Residuo do proprio E-Commerce
			::StartResiduoSC5()

			// Verifica se conseguiu realizar a eliminação de residuo 
			If ::lContinua

				// Verifica se os pedidos dos fornecedores já estão cancelados
				If !::GetIsForCanc()

					// Solicita os cancelamentos dos pedidos do seus fornecedores via THREAD
					// após o cancelamento o job vai buscar esse mesmo pedido e ira cair no GetIsForCanc()
					::StartFORCanc()

				End if 
			End if 
		End if 
	End if 

Return ::lContinua

Method GetIsForCanc() Class ECPEDIDO

	Local lRet		:= .F. 
	Local cTabVT4   := RetFullName("VT4" ,::cEmpCli)
 	Local cFilVT4   := U_GetModoFil("VT4",::cEmpCli,::cFilCli)
   	Local cAliasFor := GetNextAlias()

	cTabVT4 := "%" + cTabVT4 + "%"

	BeginSQL Alias cAliasFor

		SELECT VT4_STATUS,VT4_NUMPED,VT4_EMPFOR,VT4_FILFOR FROM %Exp:cTabVT4% VT4 

		WHERE VT4.D_E_L_E_T_ ='' 
		AND VT4.VT4_FILIAL = %Exp:cFilVT4%
		AND VT4.VT4_ORDID = %Exp:self:cOrderID%
		AND VT4.VT4_SEQUEN = %Exp:self:cSequence%
		AND VT4.VT4_API = %Exp:self:cAPI%
		AND VT4.VT4_STATUS <> 'C'
		GROUP BY VT4_STATUS,VT4_NUMPED,VT4_EMPFOR,VT4_FILFOR

	EndSQL 

	If (cAliasFor)->(EOF())
		lRet := .T. 
	Else 
		lRet := .F. 
	End if 

	(cAliasFor)->(DbCloseArea())

Return lRet

Method StartFORCanc() Class ECPEDIDO

	Local cTabVT4   		:= RetFullName("VT4" ,::cEmpCli)
 	Local cFilVT4   		:= U_GetModoFil("VT4",::cEmpCli,::cFilCli)
	Local cTabVT1   		:= RetFullName("VT1" ,::cEmpCli)
 	Local cALiasVT4 		:= GetNextAlias()
	Local cJobName			:= "THREAD_"
	Local nI				:= 0
	Local lIniciouThread	:= .F.
	Local lEnvCanc			:= .f. 

	cTabVT4X := "%" + cTabVT4 + "%"
	cTabVT1 := "%" + cTabVT1 + "%"

	BeginSQL Alias cALiasVT4

		SELECT VT1.VT1_ORDID,VT1.VT1_SEQUEN,VT1.VT1_API,VT4_NUMPED,VT4_EMPFOR,VT4_FILFOR,SM0.M0_CGC,SM0.M0_CODIGO,SM0.M0_CODFIL FROM %Exp:cTabVT4X% VT4 

		JOIN %Exp:cTabVT1% VT1 ON VT1.VT1_FILIAL = VT4.VT4_FILIAL
		AND VT1.VT1_ORDID = VT4.VT4_ORDID
		AND VT1.VT1_SEQUEN = VT4.VT4_SEQUEN
		AND VT1.VT1_API = VT4.VT4_API
		AND VT1.D_E_L_E_T_ =''

        JOIN ZZSIGAMA SM0 ON SM0.M0_CODIGO = %Exp:cEmpAnt%
        AND SM0.M0_CODFIL = VT4.VT4_FILIAL
        AND SM0.D_E_L_E_T_ =''

		WHERE VT4.D_E_L_E_T_ ='' 
		AND VT4.VT4_FILIAL = %Exp:cFilVT4%
		AND VT4.VT4_ORDID = %Exp:self:cOrderID%
		AND VT4.VT4_SEQUEN = %Exp:self:cSequence%
		AND VT4.VT4_API = %Exp:self:cAPI%
		AND VT4.VT4_CANCEL <> 'T'
		GROUP BY VT1.VT1_ORDID,VT1.VT1_SEQUEN,VT1.VT1_API,VT4_NUMPED,VT4_EMPFOR,VT4_FILFOR, SM0.M0_CGC,SM0.M0_CODIGO,SM0.M0_CODFIL
	EndSQL 

	While (cALiasVT4)->(!EOF())

		//Tenta obter uma thread para a geração da nota fiscal
		nI := 1
		lIniciouThread := .F.
		lEnvCanc	   := .t. 

		aParam := { (cALiasVT4)->VT1_ORDID,;
					(cALiasVT4)->VT1_SEQUEN,;
					(cALiasVT4)->VT1_API,;
					(cALiasVT4)->VT4_NUMPED,;
					(cALiasVT4)->VT4_EMPFOR,;
					(cALiasVT4)->VT4_FILFOR,;
					(cALiasVT4)->M0_CGC,;
					(cALiasVT4)->M0_CODIGO,;
					(cALiasVT4)->M0_CODFIL}

		// Verifica se existe pedido gerado para o fornecedor
		If Empty((cALiasVT4)->VT4_NUMPED)

			lEnvCanc := .f. 

			// Atualiza para cancelado, ja que esse fornecedor não gerou pedido
			cUpdate := "  UPDATE " + cTabVT4 + " SET VT4_CANCEL = 'T', VT4_STATUS = 'C' " + CRLF
			cUpdate += " WHERE VT4_FILIAL = '"+ cFilVT4  + "'" + CRLF
			cUpdate += " AND VT4_ORDID    = '"+ (cALiasVT4)->VT1_ORDID 	 + "'" + CRLF
			cUpdate += " AND VT4_API      = '"+ (cALiasVT4)->VT1_API	 + "'" + CRLF
			cUpdate += " AND VT4_SEQUEN   = '"+ (cALiasVT4)->VT1_SEQUEN	 + "'" + CRLF
			cUpdate += " AND VT4_NUMPED   = '"+ (cALiasVT4)->VT4_NUMPED	 + "'" + CRLF
			cUpdate += " AND VT4_EMPFOR   = '"+ (cALiasVT4)->VT4_EMPFOR	 + "'" + CRLF
			cUpdate += " AND VT4_FILFOR   = '"+ (cALiasVT4)->VT4_FILFOR	 + "'" + CRLF
			cUpdate += " AND D_E_L_E_T_   = ''"+ CRLF

			cUpdate := U_MontaUpd(cUpdate)
			nRet := TcSqlExec(cUpdate)

			If nRet < 0
				Conout('StartFORCanc (UpdVT4)'+ CRLF + TCSqlError())
 			EndIf

		End if 

		While lEnvCanc .and. !lIniciouThread .and. nI <= 10

			nI ++

			// Entrega a operação na thread disponivel
			lIniciouThread := IpcGo(cJobName+Alltrim((cALiasVT4)->VT4_EMPFOR) , "u_ECPEDCANC", aParam)

			If !lIniciouThread
				FWMonitorMsg('U_ECPEDCANC (' + Alltrim((cALiasVT4)->VT1_ORDID) + ') - Esperando 5 segundos para obter uma thread para a geração de pedidos')
				Sleep(5000)
			EndIf
		EndDo

		(cALiasVT4)->(DbSkip())
	EndDo 

	(cALiasVT4)->(DbCloseArea())
Return 

User Function ECPEDCANC(aParam)

    Local oPedFornece	:= Nil 

	Local cOrderId		:= aParam[1]
    Local cSequence		:= aParam[2]
	Local cAPI			:= aParam[3]
    Local cNumPed		:= aParam[4]
    Local cEmpFor		:= aParam[5]
    Local cFilFor		:= aParam[6]
	Local cCGCCli		:= aParam[7]
	Local cEmpCli		:= aParam[8]
	Local cFilCli 		:= aParam[9]
 
	// Mude a filial para o fornecedor
	If !Empty(cFilFor)
		cFilAnt := cFilFor
	End If

	// Após as 00:00h força a queda da thread para iniciar novamente com a database atualizada
	If dDataBase <> Date()
		KillApp(.T.)
	EndIf

	oPedFornece				:= ECPEDIDO():NEW()
    oPedFornece:cEmpCli		:= cEmpCli  // Empresa E-Commerce
    oPedFornece:cFilCli		:= cFilCli  // Filial  E-Commerce  
    oPedFornece:cApi		:= cAPI
	oPedFornece:cOrderID	:= cOrderId
	oPedFornece:cSequence	:= cSequence
    oPedFornece:StartResiduoSC5(cNumPed)

	FreeObj(oPedFornece)

Return 

Method GetIsFatWEB() Class ECPEDIDO

	Local lRet 	  := .t. 
	Local cTabPed := "SC5"

 	VTR->(dbSetOrder(2))

	If ::SetVT1()

		If VTR->(dbSeek(xFilial("VTR") + cEmpAnt + cFilAnt))

			::cNumPedido := VT1->VT1_NUMPED

			// Verifica se existe o pedido criado
			If !Empty(::cNumPedido)

				// Busca o tipo do pedido
				::cCodTipPed := VT1->VT1_TIPPED

				// Verifica se o pedido é pelo Venda Assistida
				If ::cCodTipPed == "SL1"
					cTabPed := "SL1"
				End if 

				// Verifica se o pedido se encontra faturado
				lRet := ::GetIsFatERP(cTabPed,::cNumPedido)

			Else 
				lRet := .f. 
			End if 
		End if 
	End if
Return lRet

Method GetIsFatERP(cAlias,cNumPed) Class ECPEDIDO

	Default cAlias  := "SC5"
	Default cNumPed := ::cNumPedido

	If !Empty(cNumPed)

		// Busca a nota fiscal do Pedido
		::GetNotaFiscal(cAlias,cNumPed)

		// Verifica se foi faturado
		::lContinua := Len(::aNotaFiscal) > 0 

	Else 
		::lContinua := .f. 
	End if 

Return ::lContinua

Method GetNotaFiscal(cAlias,cNumPed) Class ECPEDIDO

	Local lRet		:= .t. 

	Default cAlias  := "SC5"

	::aNotaFiscal	:= {}
	::lPedFatTot 	:= .F.

	If !Empty(cNumPed)

		Do Case 

		// Ship From Store
		Case Alltrim(cAlias) == "SL1"

			SL1->(dbSetOrder(1))
			If SL1->(Dbseek(xFilial("SL1") + cNumPed)) 

				If !Empty(SL1->L1_DOC)

					SF2->(dbsetorder(1))
					If SF2->(DbSeek(xFilial("SF2") + SL1->L1_DOC + SL1->L1_SERIE))
						AADD(::aNotaFiscal, {SL1->L1_DOC,SL1->L1_SERIE})
						::lPedFatTot := .T.
						lRet := .T. 
					End if 
				End if 
			Else 
				lRet := .T. 
			End if 

		// E-Commerce
		Case Alltrim(cAlias) == "SC5"

			SC5->(dbSetOrder(1))
			SC6->(dbSetOrder(1))
			SC9->(dbsetorder(1))

			If SC5->(Dbseek(xFilial("SC5") +cNumPed))

				// Para verificar as notas faturadas contra o pedido, tem que ser olhar a SC9, pois o mesmo
				// C6_ITEM pode ser faturado mais de uma vez no conceito do Protheus.

				If SC9->(Dbseek(xFilial("SC9") + SC5->C5_NUM))

					While SC9->(!EOF()) .AND. SC9->(C9_FILIAL + C9_PEDIDO) == xFilial("SC9") + SC5->C5_NUM

						// Localiza notas fiscais faturadas
						If !Empty(SC9->C9_NFISCAL)

							nPos := ASCAN(::aNotaFiscal,{|x| x[1] + x[2]  == SC9->C9_NFISCAL + SC9->C9_SERIENF})

							If nPos == 0
								AADD(::aNotaFiscal, {SC9->C9_NFISCAL,SC9->C9_SERIENF})
							EndIf

						EndIf

						SC9->(dbSkip())
					EndDo

					// Verifca se o pedido foi faturado na sua TOTALIDADE
					If SC6->(Dbseek(xFilial("SC6") + SC5->C5_NUM))

						While SC6->(!EOF()) .AND. SC6->(C6_FILIAL + C6_NUM) == SC5->(C5_FILIAL+ C5_NUM)

							// Verifica se existe produto a faturar que nao foi eliminado residuo
							If SC6->C6_QTDVEN <> SC6->C6_QTDENT .AND. Empty(SC6->C6_BLQ)

								// Se encontrar o primeiro produto que ainda nao foi faturado
								// sai fora e marcar como faturado parcial
								::lPedFatTot := .f.
								Exit
							Else
								::lPedFatTot := .T.
							End if

							SC6->(dbSkip())
						EndDo
					End if
				Else
					lRet := .F. 
				EndIf
			Else
				lRet := .F. 
			EndIf
		EndCase 
	End if 

Return lRet

Method StartResiduoSC5(cNumPed) Class ECPEDIDO

	Local aArea     := FWGetArea()
	LOcal aAreaSC5  := SC5->(FWGetArea())
	Local lNota		:= .f. 
	Local nCount	:= 0 
	Local cTabVT4   := RetFullName("VT4",::cEmpCli)
	Local cTabVT1   := RetFullName("VT1",::cEmpCli)
	Local cFilVT4   := U_GetModoFil("VT4",::cEmpCli,::cFilCli)
	Local cFilVT1   := U_GetModoFil("VT1",::cEmpCli,::cFilCli)
	Local cUpdate	:= ""
	Local cMsg		:= ""

	::lContinua := .t. 
	Default cNumPed := ::cNumPedido

	cNumPed := AvKey(cNumPed,"C5_NUM")

	// Verifica se o pedido esta preenchido.
	If !Empty(cNumPed)

		Begin Transaction

		SC5->(dbSetOrder(1))
		If SC5->(dbSeek(xFilial("SC5")+cNumPed))
			
			// Verifica se o pedido já tem nota fiscal
			lNota := ::GetIsFatERP("SC5",SC5->C5_NUM) 

			If lNota

				// Pausa o Pedido da empresa E-commerce informando que não foi possivel eliminar residuo
				::lContinua := .f. 
				::cNewStatus:= "P"

				cMsg := "CANCELAMENTO AUTOMÁTICO NÃO PERMITIDO"  + CRLF
				cMsg += "STATUS:........FATURADO"  + CRLF
				cMsg += "EMPRESA:......." + cEmpAnt + "/" + cFilAnt +  CRLF
				cMsg += "NOTA FISCAL:..." + ::aNotaFiscal[1][1]   + CRLF
				cMsg += "SOLUÇÃO........" + "Realizar cancelamento manualmente"
			
			// Verifica se tem produtos ainda a faturar (a eliminar residuo)
			Else 

				While nCount <= 3
					nCount ++
					// Executa apenas o PE M410VRES, pois ele executa internamente as funções DelResPed e EliResiduo
					::lContinua := U_M410VRES()

					If ::lContinua
						Exit
					End if 
				
					Sleep(2000)
				EndDo

				If !::lContinua 
					::cNewStatus:= "P"
					cMsg := "CANCELAMENTO AUTOMÁTICO NÃO PERMITIDO"
					cMsg += "STATUS:........ PEDIDO NÃO ELIMINADO RESIDUO" + chr(10)
					cMsg += "EMORESA:......." + cEmpAnt + "/" + cFilAnt + chr(10)
					cMsg += "SOLUÇÃO........" + "Realizar cancelamento manualmente"
				End if 
			End if 
			
			// Eliminação de residuo do proprio e-commerce não se atualiza a VT4
			If Alltrim(cEmpAnt)+Alltrim(cFilAnt) <> Alltrim(::cEmpCli)+Alltrim(::cFilCli)

				// Atualiza o E-commerce com o cancelamento
				cUpdate += "  UPDATE " + cTabVT4 + " SET VT4_CANCEL = 'T'"

				// Informa que pedido foi eliminado residuo com sucesso
				If ::lContinua
					cUpdate += " , VT4_STATUS = 'C' " + CRLF
				End if 

				cUpdate += " WHERE VT4_FILIAL = '"+ cFilVT4  + "'" + CRLF
				cUpdate += " AND VT4_ORDID    = '"+ ::cOrderID + "'" + CRLF
				cUpdate += " AND VT4_API      = '"+ ::cAPI	 + "'" + CRLF
				cUpdate += " AND VT4_SEQUEN   = '"+ ::cSequence+ "'" + CRLF
				cUpdate += " AND VT4_NUMPED   = '"+ cNumPed	 + "'" + CRLF
				cUpdate += " AND VT4_EMPFOR   = '"+ cEmpAnt	 + "'" + CRLF
				cUpdate += " AND VT4_FILFOR   = '"+ cFilAnt	 + "'" + CRLF
				cUpdate += " AND D_E_L_E_T_   = ''"+ CRLF
				cUpdate := U_MontaUpd(cUpdate)
				nRet := TcSqlExec(cUpdate)

				If nRet < 0
					Conout('StartResiduoSC5 (UpdVT4)'+ CRLF + TCSqlError())
					DisarmTransaction()
				EndIf
			End if 

			// Verifica se deu problema na eliminação de residuo e informa ao usuario
			If !::lContinua
				cUpdate := " UPDATE "+ cTabVT1 +" SET VT1_DATAUL = '"+ DTOS( dDataBase )+"'" + CRLF
				cUpdate += " , VT1_HORAUL = '"+  Time() +"'" 								 + CRLF
				cUpdate += " , VT1_STATUS = 'P' " 										     + CRLF
				cUpdate += " , VT1_OBS = CONVERT(VARBINARY(max), '" +cMsg+"')" 				 + CRLF
				cUpdate += " WHERE   VT1_FILIAL = '" + cFilVT1 + "' " 						 + CRLF
				cUpdate += " AND D_E_L_E_T_ = '' " 											 + CRLF
				cUpdate += " AND VT1_ORDID = '"+::cOrderID+"' " 							 + CRLF
				cUpdate += " AND VT1_API = '"+::cApi+"' " 									 + CRLF
				cUpdate += " AND VT1_SEQUEN = '"+::cSequence+"' " 							 + CRLF
				cUpdate := U_MontaUpd(cUpdate)
				nRet := TcSqlExec(cUpdate)
				If nRet < 0
					Conout('StartResiduoSC5 (UpdVT1)'+ CRLF + TCSqlError())
					DisarmTransaction()
				EndIf
			End if 
		End if 

		End Transaction
	End if 

	FwrestArea(aArea)
	FwrestArea(aAreaSC5)

Return ::lContinua

Method StartSL1Canc() Class ECPEDIDO

	Local lRet := .T.

	If ::SetVT1()

		SL1->(dbSetOrder(1))

		::cNumPedido := VT1->VT1_NUMPED

		If SL1->(Dbseek(xFilial("SL1") + ::cNumPedido))

			If Empty(SL1->L1_DOC)

				SL1->(RecLock("SL1",.F.))
					SL1->L1_YTPVND	:= "1" 	// 1=Orcamento;2=Pedido
					SL1->L1_XATIV	:= "N" 	// Desistencia
				SL1->(msUnlock())	

				//Executa o complemento do ID 113 - Exclusão da Reserva nas tabelas SC0 e P41
				U_F0111330(0)

				//GAP 114 - Desistencia -- se for central pdv vai enviar para retaguarda
				U_F0111450()

				//ID-115: WebService alterar Analise (Cancelado) e atualizar Credito Consumido
				U_F0111570(SL1->L1_FILIAL, SL1->L1_NUM, SL1->L1_CLIENTE, SL1->L1_LOJA, "4")	

			Else
				aAdd(::aMsgErro,"O Pedido se encontra já faturado, o cancelamento não sera realizado.")
				lRet := .f.
			End if
		End if
	Else
		lRet := .f.
	End if

Return lRet


Method StartPedMagento() Class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local nTotProd		:= 0
	Local nI            := 0
	Local oPedido		:= Nil
	Local cUnidNReg1 := Alltrim(SUPERGETMV( 'ES_ECPED01', .F., '' ))
	Private lMsErroAuto := .F.

	oPedido := ResPedCli():New(::cTipo)
	oPedido:GetPedido(::cOrderID)

	If oPedido == Nil
		aAdd(::aMsgErro,"Não foi possivel recuperar o pedido "+AllTrim(::cOrderID)+" na "+AllTrim(Capital(::cAPI))+" para integração inicial!")
		::lContinua := .F.
		::cNewStatus := "P"
	Else

		::cTransp		:= ''
		::cTipoFrete	:= "C"
		::nValFrete	    := Round(oPedido:nTaxaEnvio,TamSx3("C5_FRETE")[2])
		::nTotalPedido	:= oPedido:nBTotal

		::lContinua		:= oCliente:IncluiCliente(oPedido,oPedido,::cTipo)

		// Verifica se conseguiu locar o cliente, se nao, saia da rotina
		If !oCliente:lLockCliente
			Return 
		End if 

		If ! ::lContinua //Se não criou/alterou o cliente
			For nI := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro,oCliente:aMsgErro[nI])
			Next nI
		Else
			If Empty(oCliente:cCondPag)
				aAdd(::aMsgErro,'A Condição de pagamento "'+ oCliente:cCondPag +'" cadastrada no Web, não está vinculada a uma condição de pagamento do Protheus, favor cadastar na rotina Cond Pagto X Web.')
				::lContinua := .F.
				::cNewStatus := "P"
			EndIf
		EndIf

		If (::cTipo == 'B2B' .AND. AllTrim(FWUnitBusiness())  $ cUnidNReg1)
			::GetVendedor('B2B TIMS')
		ElseIf ! Empty(oPedido:cMarketPlace)
			::GetVendedor(oPedido:cMarketPlace)
		Else
			::GetVendedor('SITE')
		EndIF

		::GetTransp(oPedido)

		//obtem todos os produtos internos para começar a criação do pedido de venda
		If ::lContinua
			::aPedItens := {}
			::GetProduto(oPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
		EndIf

		//Atualiza tabela de integração
		If ::lContinua

			//CALCULA PERCENTUAL DE DESCONTO
			If oPedido:nDesconto > 0
				::nPercDesc	:= Round(oPedido:nDesconto/nTotProd*100,TamSx3("C5_DESC1")[2])
			Else
				::nPercDesc	:= 0
			EndIf

			If ::nPercDesc >= 100
				aAdd(::aMsgErro,"Não é permitido desconto acima de 100%!")
				::lContinua := .F.
				::cNewStatus := "P"
			EndIf

			If ::lContinua
				::GetModFrete( oPedido )
			EndIf

			If ::lContinua
				::CreateSC5Ped(oCliente)
			EndIf

		EndIf

	EndIf

	If !::lContinua
		::cNewStatus := 'P'
	Else
		::cNewStatus := 'A'	//PEDIDO GERADO NA ORIGEM
	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oPedido)

Return

Method StartPedAny() class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local jPedido		:= JsonObject():New()
	Local jCliente		:= JsonObject():New()
	Local jEndereco		:= JsonObject():New()
	Local nX			:= 0
 	Local lFreeFrete	:= SuperGetMV("MV_YFREEFRT",.F.,.T.)
	Local cMktFreeFrt   := SuperGetMv("MV_YMKTPED" ,.F.,"")
	Local _nValTotIt	:= 0
	Local _nDesGer		:= 0
	Local _ValFret		:= 0
	Local cMktPedido 	:= ""
	Local cNewStatus	:= ""
	Private oPedido		:= Nil
	
	jPedido:FromJson(VT1->VT1_JSON)

	::cTipoFrete		:= "C"

	//Verifica se o Cliente esta cadastrado
	jCliente		:= jPedido["buyer"]
	jEndereco		:= jPedido["shipping"]
	cMktPedido		:= Alltrim(UPPER(jPedido["marketPlace"]))
	cMktFreeFrt 	:= UPPER(Alltrim(cMktFreeFrt))

	If ::lContinua
		
		::lContinua		:= oCliente:IncluiCliente(jCliente,jEndereco,::cTipo)

		// Verifica se conseguiu locar o cliente, se nao, saia da rotina
		If !oCliente:lLockCliente
			Return 
		End if 

		If ! ::lContinua //Se não criou/alterou o cliente
					
			::cNewStatus := 'P'

			For nX := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro,oCliente:aMsgErro[nX])
			Next nX
		End if 
 	End if

	If ::lContinua
		::GetVendedor(cMktPedido)
	End if

	// Verifica se o pedido é do tipo troca e se pode seguir.
	If ::lContinua
		::VldPedTroca()
	End if 

	If ::lContinua
		::GetTransp(jPedido)
	End if

	If ::lContinua
		::StartModFrete()
	End if 

	//obtem todos os produtos internos para começar a criação do pedido de venda
	If ::lContinua
		::aPedItens := {}
		::GetProduto(jPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
	EndIf

	//Atualiza tabela de integração
	If ::lContinua

		// Recupera o desconto do pedido
		If jPedido:hasProperty("discount")  
			_nDesGer := jPedido["discount"]
		End if

		// Recupera o valor total dos itens
		If jPedido:hasProperty("gross")  
			_nValTotIt	:= jPedido["gross"]
		End if

		// Recupera o valor total do pedido
		If jPedido:hasProperty("total")   
			::nTotalPedido := jPedido["total"]
		End if

		// Recupera o valor frete
		If jPedido:hasProperty("freight")
			_ValFret := jPedido["freight"]
			
			// Verifica se zera o frete para o vendedor citado
			If lFreeFrete .AND. _ValFret > 0 .and. cMktPedido $ cMktFreeFrt

				// Retira o valor do Frete do valor total do pedido
				// Pedidos da SHOPEE deverão ter a memoria de calculo
				// (+) oPedido["payments"][nI]["value"]
				// (-) oPedido["freight"]
				// (+) oPedido["discount"]
				// (=) oPedido["gross"]
				::nTotalPedido := jPedido["gross"]
				_ValFret := 0 
				
			End if 
		End if

		::nValFrete		:= _ValFret

		//CALCULA PERCENTUAL DE DESCONTO
		::nPercDesc		:= Round(((_nDesGer * 100)/_nValTotIt),2)

		//VALOR PAGO NO PEDIDO
		_nValLiq		:= _nValTotIt - _nDesGer
		::nTotalPedLiq 	:= _nValLiq + _ValFret

		If ::nPercDesc >= 100
			aAdd(::aMsgErro,"Não é permitido desconto acima de 100%!")
			::lContinua := .F.
			::cNewStatus := "P"
		EndIf

	EndIf

	If ::lContinua 
		If AllTrim(::cCodTipPed) == 'SC5'
			::CreateSC5Ped(oCliente)
			cNewStatus := 'A'
		ElseIf AllTrim(::cCodTipPed) == 'SL1'
			::CreateSL1Ped(oCliente)
			cNewStatus := '1'
		Else 
			aAdd(::aMsgErro,"Tipo de pedido não identificado.")
			::lContinua := .F.
		EndIf 
	EndIf 

	If ::lContinua
		::cNewStatus := cNewStatus
	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(jPedido)
	FreeObj(jEndereco)
	FreeObj(jCliente)

Return

Method StartPedCock() class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local jPedido		:= JsonObject():New()
	Local jCliente		:= JsonObject():New()
	Local jEndereco		:= JsonObject():New()
	Local nX			:= 0
 	Local lFreeFrete	:= SuperGetMV("MV_YFREEFRT",.F.,.T.)
	Local cMktFreeFrt   := SuperGetMv("MV_YMKTPED" ,.F.,"")
	Local _nValTotIt	:= 0
	Local _nDesGer		:= 0
	Local _ValFret		:= 0
	Local cMktPedido 	:= ""
	Local cNewStatus	:= ""
	Private oPedido		:= Nil
	
	jPedido:FromJson(VT1->VT1_JSON)

	::cTipoFrete		:= "C"

	//Verifica se o Cliente esta cadastrado
	jCliente		:= jPedido["buyer"]
	jEndereco		:= jPedido["shipping"]
	cMktPedido		:= Alltrim(UPPER(jPedido["marketPlace"]))
	cMktFreeFrt 	:= UPPER(Alltrim(cMktFreeFrt))

	If ::lContinua
		
		::lContinua		:= oCliente:IncluiCliente(jCliente,jEndereco,::cTipo)

		// Verifica se conseguiu locar o cliente, se nao, saia da rotina
		If !oCliente:lLockCliente
			Return 
		End if 

		If ! ::lContinua //Se não criou/alterou o cliente
					
			::cNewStatus := 'P'

			For nX := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro,oCliente:aMsgErro[nX])
			Next nX
		End if 
 	End if

	If ::lContinua
		::GetVendedor(cMktPedido)
	End if

	// Verifica se o pedido é do tipo troca e se pode seguir.
	If ::lContinua
		::VldPedTroca()
	End if 

	If ::lContinua
		::GetTransp(jPedido)
	End if

	If ::lContinua
		::StartModFrete()
	End if 

	//obtem todos os produtos internos para começar a criação do pedido de venda
	If ::lContinua
		::aPedItens := {}
		::GetProduto(jPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
	EndIf

	//Atualiza tabela de integração
	If ::lContinua

		// Recupera o desconto do pedido
		If jPedido:hasProperty("discount")  
			_nDesGer := jPedido["discount"]
		End if

		// Recupera o valor total dos itens
		If jPedido:hasProperty("gross")  
			_nValTotIt	:= jPedido["gross"]
		End if

		// Recupera o valor total do pedido
		If jPedido:hasProperty("total")   
			::nTotalPedido := jPedido["total"]
		End if

		// Recupera o valor frete
		If jPedido:hasProperty("freight")
			_ValFret := jPedido["freight"]
			
			// Verifica se zera o frete para o vendedor citado
			If lFreeFrete .AND. _ValFret > 0 .and. cMktPedido $ cMktFreeFrt

				// Retira o valor do Frete do valor total do pedido
				// Pedidos da SHOPEE deverão ter a memoria de calculo
				// (+) oPedido["payments"][nI]["value"]
				// (-) oPedido["freight"]
				// (+) oPedido["discount"]
				// (=) oPedido["gross"]
				::nTotalPedido := jPedido["gross"]
				_ValFret := 0 
				
			End if 
		End if

		::nValFrete		:= _ValFret

		//CALCULA PERCENTUAL DE DESCONTO
		::nPercDesc		:= Round(((_nDesGer * 100)/_nValTotIt),2)

		//VALOR PAGO NO PEDIDO
		_nValLiq		:= _nValTotIt - _nDesGer
		::nTotalPedLiq 	:= _nValLiq + _ValFret

		If ::nPercDesc >= 100
			aAdd(::aMsgErro,"Não é permitido desconto acima de 100%!")
			::lContinua := .F.
			::cNewStatus := "P"
		EndIf

	EndIf

	If ::lContinua 
		If AllTrim(::cCodTipPed) == 'SC5'
			::CreateSC5Ped(oCliente)
			cNewStatus := 'A'
		ElseIf AllTrim(::cCodTipPed) == 'SL1'
			::CreateSL1Ped(oCliente)
			cNewStatus := '1'
		Else 
			aAdd(::aMsgErro,"Tipo de pedido não identificado.")
			::lContinua := .F.
		EndIf 
	EndIf 

	If ::lContinua
		::cNewStatus := cNewStatus
	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(jPedido)
	FreeObj(jEndereco)
	FreeObj(jCliente)

Return

Method StartPedCws() class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local jPedido		:= JsonObject():New()
	Local jCliente		:= JsonObject():New()
	Local jEndereco		:= JsonObject():New()
	Local nX			:= 0
	Local cNewStatus	:= ""
	Local cCnpjCWs		:= ""
		
	Private oPedido		:= Nil
	
	jPedido:FromJson(VT1->VT1_JSON)

	::cTipoFrete		:= "C"

	//Verifica se o Cliente esta cadastrado
	jCliente		:= jPedido["customer"] 
	jEndereco		:= jPedido["customer"]['registrationAddress'] 
	cCnpjCWs		:= jPedido["customer"]['document']
	cCnpjCWs 		:= Replace(Replace(Replace(cCnpjCWs, '/',''),'.',''),'-','')

	If GetNewPar("FT_ECPEDW",.F.) //Inclui cliente, caso não exista 
		
		If ::lContinua
			
			::lContinua		:= oCliente:IncluiCliente(jCliente,jEndereco,::cTipo)

			// Verifica se conseguiu locar o cliente, se nao, saia da rotina
			If !oCliente:lLockCliente
				Return 
			End if 

			If ! ::lContinua //Se não criou/alterou o cliente
						
				::cNewStatus := 'P'

				For nX := 1 to Len(oCliente:aMsgErro)
					aAdd(::aMsgErro,oCliente:aMsgErro[nX])
				Next nX
			End if 
		End if
	Else

		DbSelectArea("SA1")
		DbSetOrder(3)
		If DbSeek(xFilial("SA1") + cCnpjCWs)
			::lContinua 		 := .T.
			oCliente:cCliente 	 := SA1->A1_COD
			oCliente:cLoja 		 := SA1->A1_LOJA      
			oCliente:lClienteWEB := .T.
		Else
			::cNewStatus := 'P'

			For nX := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro,oCliente:aMsgErro[nX])
			Next nX
		EndIf 
	EndIf 

	// Valida se o Vendedor se encontra Valido
	If ::lContinua
		::GetVendedor(Nil,oCliente:cCliente,oCliente:cLoja)
	End if

	// Valida se existe operador valido
	If ::lContinua .and. Alltrim(::cCodTipPed) == "SUA"
		::GetOperador(::cCodSA3)
	EndIf

	// Valida se existe condicao valida
	If ::lContinua
		::GetCondicao(jPedido)
	End if 

	If ::lContinua
		::GetTransp(jPedido)
	End if

	If ::lContinua
		::StartModFrete()
	End if 

	//obtem todos os produtos internos para começar a criação do pedido de venda
	If ::lContinua
		::aPedItens := {}
		::GetProduto(jPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
	EndIf

	//Atualiza tabela de integração
	If ::lContinua

 		// Recupera o valor total do pedido
		If jPedido:hasProperty("total")   
			::nTotalPedido := jPedido["total"]
		End if

		// Recupera o valor frete
		If jPedido:hasProperty("freightTotal")
			::nValFrete := jPedido["freightTotal"]
		End if
 
 		If AllTrim(::cCodTipPed) == 'SC5'
			::CreateSC5Ped(oCliente)
			cNewStatus := 'A'

		ElseIf AllTrim(::cCodTipPed) == 'SL1'
			::CreateSL1Ped(oCliente)
			cNewStatus := '1'

		ElseIf AllTrim(::cCodTipPed) == 'SUA'
			::CreateSUAPed(oCliente)
			cNewStatus := 'Y'
		Else 
			aAdd(::aMsgErro,"Tipo de pedido não identificado.")
			::lContinua := .F.
		EndIf 
	EndIf 

	If ::lContinua

		::cNewStatus := cNewStatus

	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(jPedido)
	FreeObj(jEndereco)
	FreeObj(jCliente)

Return()



/*/{Protheus.doc} StartPedNuvem
Processamento de pedidos oriundos da Nuvemshop para geracao de SC5/SC6
@author Claudio Guidi
@since 30/09/2026
@version 1.0
/*/
Method StartPedNuvem() Class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local jPedido		:= JsonObject():New()
	Local jCliente		:= JsonObject():New()
	Local jEndereco		:= JsonObject():New()
	Local nX			:= 0
	Local cNewStatus	:= ""
	Local _nValTotIt	:= 0
	Local _nDesGer		:= 0
	Local _ValFret		:= 0
	Local _nValLiq		:= 0
	Private oPedido		:= Nil

	jPedido:FromJson(VT1->VT1_JSON)

	::cTipoFrete		:= "C"

	// Dados do Comprador e Endereco
	If jPedido:hasProperty("customer")
		jCliente := jPedido["customer"]
	EndIf
	If jPedido:hasProperty("shipping_address")
		jEndereco := jPedido["shipping_address"]
	ElseIf jPedido:hasProperty("billing_address")
		jEndereco := jPedido["billing_address"]
	EndIf

	If ::lContinua
		::lContinua := oCliente:IncluiCliente(jCliente, jEndereco, ::cTipo)

		// Verifica se conseguiu locar o cliente
		If !oCliente:lLockCliente
			Return
		EndIf

		If !::lContinua
			::cNewStatus := 'P'
			For nX := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro, oCliente:aMsgErro[nX])
			Next nX
		EndIf
	EndIf

	// Vendedor
	If ::lContinua
		::GetVendedor("NUVEMSHOP", oCliente:cCliente, oCliente:cLoja)
	EndIf

	// Transportadora
	If ::lContinua
		::GetTransp(jPedido)
	EndIf

	// Modalidade do Frete
	If ::lContinua
		::StartModFrete()
	EndIf

	// Produtos / Itens do Pedido
	If ::lContinua
		::aPedItens := {}
		::GetProduto(jPedido, oCliente)
	EndIf

	// Valores, Frete e Descontos
	If ::lContinua
		If jPedido:hasProperty("discount")
			_nDesGer := Val(cValToChar(jPedido["discount"]))
		EndIf

		If jPedido:hasProperty("subtotal")
			_nValTotIt := Val(cValToChar(jPedido["subtotal"]))
		EndIf

		If jPedido:hasProperty("total")
			::nTotalPedido := Val(cValToChar(jPedido["total"]))
		EndIf

		If jPedido:hasProperty("shipping_cost_customer")
			_ValFret := Val(cValToChar(jPedido["shipping_cost_customer"]))
		ElseIf jPedido:hasProperty("shipping_cost_owner")
			_ValFret := Val(cValToChar(jPedido["shipping_cost_owner"]))
		EndIf

		::nValFrete := _ValFret

		If _nValTotIt > 0
			::nPercDesc := Round(((_nDesGer * 100) / _nValTotIt), 2)
		EndIf

		_nValLiq := _nValTotIt - _nDesGer
		::nTotalPedLiq := _nValLiq + _ValFret

		If ::nPercDesc >= 100
			aAdd(::aMsgErro, "Nao e permitido desconto acima de 100%!")
			::lContinua := .F.
			::cNewStatus := "P"
		EndIf

		If ::lContinua
			If AllTrim(::cCodTipPed) == 'SL1'
				::CreateSL1Ped(oCliente)
				cNewStatus := '1'
			ElseIf AllTrim(::cCodTipPed) == 'SUA'
				::CreateSUAPed(oCliente)
				cNewStatus := 'Y'
			Else
				// Padrao Fortbras: SC5
				::CreateSC5Ped(oCliente)
				cNewStatus := 'A'
			EndIf
		EndIf
	EndIf

	If ::lContinua
		::cNewStatus := cNewStatus
	EndIf

	// Libera lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(jPedido)
	FreeObj(jEndereco)
	FreeObj(jCliente)

Return

Method StartPed00K() Class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local oDadosCli		:= Nil
	Local oEndCliente	:= Nil
	Local nX			:= 0
	Local _nValTotIt	:= 0
	Local _nDesGer		:= 0
	Local _ValFret		:= 0
	Private oPedido		:= Nil

	// –> Deserializa a string JSON
	FWJsonDeserialize(VT1->VT1_JSON, @oPedido)

	::cTipoFrete	:= "C"

	//Verifica se o Cliente esta cadastrado
	oDadosCli		:= oPedido:customer
	oEndCliente		:= oPedido:address

	If ::lContinua
		::lContinua		:= oCliente:IncluiCliente(oDadosCli,oEndCliente,::cTipo)

		// Verifica se conseguiu locar o cliente, se nao, saia da rotina
		If !oCliente:lLockCliente
			Return 
		End if 

		If ! ::lContinua //Se não criou/alterou o cliente
		
			::cNewStatus := 'P'

			For nX := 1 to Len(oCliente:aMsgErro)
				aAdd(::aMsgErro,oCliente:aMsgErro[nX])
			Next nX
		EndIf

	End if

	If ::lContinua
		::GetVendedor(oPedido:order:marketPlace)
	End if

	// Verifica se o pedido é do tipo troca e se pode seguir.
	If ::lContinua
		::VldPedTroca()
	End if 

	If ::lContinua
		::GetTransp(oPedido)
	End if

	//obtem todos os produtos internos para começar a criação do pedido de venda
	If ::lContinua
		::aPedItens := {}
		::GetProduto(oPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
	EndIf

	//Atualiza tabela de integração
	If ::lContinua

		// Recupera o desconto do pedido
		If AttIsMemberOf(oPedido,"order")  .and. AttIsMemberOf(oPedido:order,"discount")
			_nDesGer := oPedido:order:discount
		End if

		// Recupera o valor frete
		If AttIsMemberOf(oPedido,"freight") .and. AttIsMemberOf(oPedido:freight,"value")
			_ValFret := oPedido:freight:value
		End if

		// Recupera o valor total dos itens
		If AttIsMemberOf(oPedido,"productsTotal")
			_nValTotIt	:= oPedido:productsTotal
		End if

		// Recupera o valor total do pedido
		If AttIsMemberOf(oPedido,"order")  .and. AttIsMemberOf(oPedido:order,"total")
			::nTotalPedido := oPedido:order:total
		End if

		::nValFrete		:= _ValFret

		//CALCULA PERCENTUAL DE DESCONTO
		::nPercDesc		:= Round(((_nDesGer * 100)/_nValTotIt),2)

		//VALOR PAGO NO PEDIDO
		_nValLiq		:= _nValTotIt - _nDesGer
		::nTotalPedLiq 	:= _nValLiq + _ValFret

		If ::nPercDesc >= 100
			aAdd(::aMsgErro,"Não é permitido desconto acima de 100%!")
			::lContinua := .F.
			::cNewStatus := "P"
		EndIf

		// If ::lContinua
		// 	::GetModFrete( oPedido )
		// EndIf

		If ::lContinua
			::CreateSC5Ped(oCliente)
 		EndIf

	EndIf

	If ::lContinua
		::cNewStatus := 'A'	//PEDIDO GERADO NA ORIGEM
	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(oDadosCli)
	FreeObj(oEndCliente)

Return

//===================================================================

Method StartPedVTEX() Class ECPEDIDO

	Local oCliente 		:= SchedCliente():New(::cAPI)
	Local oPedido		:= Nil
	Local oDadosCli		:= Nil
	Local oEndCliente	:= Nil
	Local nX			:= 0
	Local _nValTotIt	:= 0
	Local _nDesGer		:= 0
	Local _ValFret		:= 0

	// –> Deserializa a string JSON
	FWJsonDeserialize(VT1->VT1_JSON, @oPedido)

	::cTipoFrete	:= "C"

	//Verifica se o Cliente esta cadastrado
	oDadosCli		:= oPedido:clientProfileData
	oEndCliente		:= oPedido:shippingData:address

	If AttIsMemberOf(oPedido,'INVOICEDATA') .and.  oPedido:invoiceData <> Nil
		If  AttIsMemberOf(oPedido:invoiceData,'address') .and. oPedido:invoiceData:address <> Nil
			oEndCliente	 := oPedido:invoiceData:address
		End if
	End if

	::lContinua		:= oCliente:IncluiCliente(oDadosCli,oEndCliente,::cTipo)
	
	// Verifica se conseguiu locar o cliente, se nao, saia da rotina
	If !oCliente:lLockCliente
		Return 
	End if 

	If ! ::lContinua //Se não criou/alterou o cliente
		For nX := 1 to Len(oCliente:aMsgErro)
			aAdd(::aMsgErro,oCliente:aMsgErro[nX])
		Next nX
	EndIf

	If ::lContinua
		::GetVendedor("SITE")
	End if

	If ::lContinua
		::GetTransp(oPedido)
	End if

	//obtem todos os produtos internos para começar a criação do pedido de venda
	If ::lContinua
		::aPedItens := {}
		::GetProduto(oPedido, oCliente) //se deu erro, atribui a propriedade ::lContinua como falso
	EndIf

	//Atualiza tabela de integração
	If ::lContinua

		//Verifica o Valor do Desconto a Ser aplicado no Pedido
		For nX:= 1 To Len(oPedido:totals)
			If oPedido:totals[nX]:id $( "Items/Discounts/Shipping")
				If oPedido:totals[nX]:id ==  "Items"
					_nValTotIt	:= (oPedido:totals[nX]:value / 100)
				Elseif  oPedido:totals[nX]:id ==  "Discounts"
					_nDesGer	:= ((oPedido:totals[nX]:value * (-1)) / 100)
				Elseif oPedido:totals[nX]:id ==  "Shipping"
					_ValFret	:= (oPedido:totals[nX]:value / 100)
				Endif
			Endif
		Next nX

		::nValFrete		:= _ValFret
		::nTotalPedido	:= (oPedido:value / 100)

		//CALCULA PERCENTUAL DE DESCONTO
		::nPercDesc		:= Round(((_nDesGer * 100)/_nValTotIt),2)
		//VALOR PAGO NO PEDIDO
		_nValLiq		:= _nValTotIt - _nDesGer
		::nTotalPedLiq 	:= _nValLiq + _ValFret

		If ::nPercDesc >= 100
			aAdd(::aMsgErro,"Não é permitido desconto acima de 100%!")
			::lContinua := .F.
			::cNewStatus := "P"
		EndIf

		If ::lContinua 
			If VT1->VT1_TIPPED == 'SC5'
				::CreateSC5Ped(oCliente)
				cNewStatus := 'A'
			ElseIf VT1->VT1_TIPPED == 'SL1'
				::CreateSL1Ped(oCliente)
				cNewStatus := '1'
			Else 
				aAdd(::aMsgErro,"Tipo de pedido não identificado.")
				::lContinua := .F.
			EndIf 
		EndIf 
	EndIf

	If ::lContinua
		::cNewStatus := cNewStatus
	Else 
		::cNewStatus := 'P'
	EndIf

	// Retire o lock do cliente
	oCliente:UnLockCliente()

	FreeObj(oCliente)
	FreeObj(oDadosCli)
	FreeObj(oEndCliente)

Return

Method CreateSC5Ped(oCliente) Class ECPEDIDO

	Local cProduto 		:= ""
	Local cTES	  		:= ""
	Local aCabec   		:= {}
	Local aItens   		:= {}
	Local aAuxItens		:= {}
	Local aRecSC6  		:= {}
	Local nPrecoVenda	:= 0
	Local nPrecoTab		:= 0
	Local nTotal        := 0
	Local nVolumes 		:= 0
	Local nPesoBrut		:= 0
	Local nPesoLiq 		:= 0
	Local cEspecie 		:= "VOLUME(S)"
	Local cEmpEst		:= ''
	Local cFilEst		:= ''
	Local aProdEst		:= {}
	Local aProdutos		:= {}
	Local cOper	   		:= SuperGetMv("FB_OPERVEN",.F.,"51")
	Local cCondPag 		:= SuperGetMv("VT_CONDPAG",.F.,"001")
	Local lChekRes      := SuperGetMV("MV_YRESPED",.F.,.T.)
	Local lDescDIFAL	:= SuperGetMv("MV_YDECDFL",.F.,.F.)
	Local lLibPedAut	:= SuperGetMv("MV_YLIBEST",.F.,.T.)
 	Local aItenAux		:= {}
	Local lVolAuto      := .F.
	Local nI, nX		:= 0
	Local aMults		:= {}
	Local lTravaSB2		:= .F.

	Private lMsErroAuto	:= .F. //Variavel que informa a ocorrência de erros no ExecAuto

	If !LockByName("CreateSC5Ped"+::cOrderID, .T., .T., .T.)
		FWLogMsg("INFO", , "INFO", , , , "Rotina CreateSC5Ped esta sendo executada por outra instancia. PEDIDO WEB: " + ::cOrderID, , , )
		::lContinua := .F.
		// Nao precisa alterar o Status "P" para a rotina executar novamente de forma automatica
		Return
	EndIf

	//-----------------------------------------------------------------------//
	// Trecho adicionado em 14/09 conforme estava no SchedPedido             //
	// Para ajuste do preço dos produtos que tem calculo do DIFAL por fora   //
	//-----------------------------------------------------------------------//
	If lDescDIFAL

		/*Para facilitar a utilização da rotina de recálculo transformo o array no
		seguinte padrão.
	    //_aPVItens[01] - CODIGO DE PRODUTO	
	    //_aPVItens[02] - QUANTIDADE VENDIDA
	    //_aPVItens[03] - PRECO PRATICADO
	    //_aPVItens[04] - FORNECEDOR DAS PECAS
	    //_aPVItens[05] - LOJA FORNECEDOR
	    //_aPVItens[06] - EMPRESA
	    //_aPVItens[07] - FILIAL
	    //_aPVItens[08] - INDICA QUE O PRODUTO FOI LOCALIZADO NA BASE
	    //_aPVItens[09] - PRECO TABELA
	    //_aPVItens[10] - VALOR TOTAL DO ITEM
	    //_aPVItens[11] - ID ORIGINAL DO SKU NO VTEX, NECESSARIO PARA ENVIAR O INVOICE PARA O VTEX
	    //_aPVItens[12] - QT VENDIDA DO SKU, NECESSARIO PARA ENVIAR O INVOICE PARA VTEX
	    //_aPVItens[13] - TES (NAO TENHO A TES)
	    //_aPVItens[14] - FRETE RATEADO (NAO TENHO)
	    //_aPVItens[15] - IMPOSTO DIFAL (NAO TENHO)
		//_aItensped[16] - DESCONTO RATEADO
		*/
	_aLin 	:= {}
	_aItens := {}

	For nI := 1 To Len(::aPedItens)

		_aLin:={::aPedItens[nI]:cCodProd,; //01
		::aPedItens[nI]:nQuantidade,; //02
		::aPedItens[nI]:nValUnit,; //03
		"",;			//04
		"",;			//05
		"",;			//06
		"",;			//07
		"",;			//08
		::aPedItens[nI]:nValUnit,;	//09
		Round(Round(::aPedItens[nI]:nQuantidade,TamSx3("C6_QTDVEN")[2]) * Round(::aPedItens[nI]:nValUnit,TamSx3("C6_PRCVEN")[2]), TamSx3("C6_VALOR")[2]),; //10
		"",;			//11
		0,;				//12
		"",;			//13
		0,;				//14
		0,;				//15
		0 }				//16

		aadd(_aItens,_aLin)

		_aLin := {}

	Next nI

	_aItens := U_FBLKIMP(oCliente:cCliente, oCliente:cLoja, _aItens, ::nValFrete, ::nTotalPedido )

	//Agora Atualiza o Array
	//Posicoes Fixas do Array _aItensped não deve ser alterado.
	//aProdutos[01] - SEQUENCIA DO ITEM
	//aProdutos[02] - CODIGO DO PRODUTO
	//aProdutos[03] - QUANTIDADE
	//aProdutos[04] - PREÇO DE VENDA
	//aProdutos[05] - .T.
	//aProdutos[06] - Data de Entrega
	//aProdutos[07] - Preço de Tabela
	For nI := 1 To Len (::aPedItens)
		::aPedItens[nI]:nValUnit 	:= Round(_aItens[nI][03],TamSx3("C6_PRCVEN")[2])
		::aPedItens[nI]:nValTotal	:= _aItens[nI][02] * ::aPedItens[nI]:nValUnit
	Next nI

EndIf

// Quebra pedidos por filiais de armazem
For nI := 1 to Len(::aPedItens)

	lVolAuto    := .F.
	cEmpEst	    := cEmpAnt
	cFilEst	    := cFilAnt
	cProduto    := ::aPedItens[nI]:cCodProd
	cFabricante := ::aPedItens[nI]:cFabricante

	// Localiza a empresa armazenadora dentro da empresa para realizar a divisão dos pedidos de venda
	jEmpForArm := U_GetEmpForArm(cProduto)

	// Verifica se o armazenamento é externo
	If jEmpForArm["externo"]
		lVolAuto    := .T.
	EndIf

	cEmpEst     := jEmpForArm["grupo"]
	cFilEst     := jEmpForArm["filial"]

	nPos := 0
	If Len(aProdEst) == 0
		aAdd(aProdEst, { cEmpEst, cFilEst, lVolAuto, {::aPedItens[nI]}} )

	Else
		nPos := aScan(aProdEst, {|x| x[1]+x[2] == cEmpEst + cFilEst})
		If nPos > 0
			aAdd(aProdEst[nPos, 4], ::aPedItens[nI] )
		Else
			aAdd(aProdEst, { cEmpEst, cFilEst , lVolAuto, {::aPedItens[nI]}} )
		EndIf
	EndIf
Next

For nI := 1 to Len(aProdEst)
	nVolumes	:= 0
	nPesoBrut	:= 0
	nPesoLiq	:= 0

	//Verifica se já não existe pedido de venda na base
	//pode ser que esteja executando novamente e apenas ter pendencias no faturamento entre grupos
	SC5->(dbOrderNickName("YPEDWEB"))
	If !SC5->(dbSeek(xFilial("SC5")+Padr(::cAPI,TamSx3("C5_YAPI")[1])+Padr(::cOrderID,TamSx3("C5_YPEDWEB")[1])+oCliente:cCliente+oCliente:cLoja + aProdEst[nI][1] + aProdEst[nI][2] ))

		aCabec		:= {}
		aItens		:= {}
		cItem		:= Padr('0',TamSx3("C6_ITEM")[1], '0')
		aMults		:= {}
		aProdutos	:= aProdEst[nI][4]
		lVolAuto	:= aProdEst[nI][3]
		lTravaSB2	:= .F.
		//------------------------------------------------------------------------------//
		// Tratamento para deadlocks através do uso de MultLock                         //
		//------------------------------------------------------------------------------//
		For nX := 1 to Len(aProdutos)
			cProduto	:= aProdutos[nX]:cCodProd
			If SB2->(dbSeek(xFilial('SB2')+cProduto+"01"))
				aAdd(aMults, SB2->(B2_FILIAL+B2_COD+B2_LOCAL))
			Endif
		Next nX

		Begin Transaction

			lTravaSB2 := MultLock("SB2",aMults,1)

			If !lTravaSB2
				SB2->(MSUnlockAll())
				DisarmTransaction()
				BREAK
			EndIf

			For nX:= 1 to Len(aProdutos)
				cProduto	:= aProdutos[nX]:cCodProd
				cItem		:= Soma1(cItem)

				//Define a TES via TES Inteligente
				cTES		:= U_VIXA103(2,cOper,oCliente:cCliente,oCliente:cLoja,"C",cProduto)

				SF4->(DbSetOrder(1))
				If SF4->(dbSeek(xFilial("SF4")+cTES))

					nPrecoVenda := aProdutos[nX]:nValUnit
					nPrecoTab	:= iIF(aProdutos[nX]:nPrecoTab > 0, aProdutos[nX]:nPrecoTab, nPrecoVenda)
					dDataEntrega:= aProdutos[nX]:dDtEntrega

					If nPrecoVenda > 0
						aAuxItens	:= {}
						nQdtVenda	:= aProdutos[nX]:nQuantidade
						nTotal		:= aProdutos[nX]:nValTotal

						If lVolAuto
							nVolumes	+= nQdtVenda
							nPesoBrut	+= aProdutos[nX]:nPesoProtheus * nQdtVenda
							nPesoLiq	+= aProdutos[nX]:nPesoProtheus * nQdtVenda
						EndIf

						aadd(aAuxItens,{"C6_ITEM"		, cItem,Nil})
						aadd(aAuxItens,{"C6_PRODUTO"	, cProduto,Nil})
						aadd(aAuxItens,{"C6_LOCAL"		, "01",Nil})
						aadd(aAuxItens,{"C6_TES"		, cTES,Nil})
						aadd(aAuxItens,{"C6_QTDVEN"		, Round(nQdtVenda,TamSx3("C6_QTDVEN")[2]),Nil})

						// Na Hipervarejo o pedido não deve ser liberado automaticamente
						If lLibPedAut
							aadd(aAuxItens,{"C6_QTDLIB"		, Round(nQdtVenda,TamSx3("C6_QTDVEN")[2]),Nil})
						Else
							aadd(aAuxItens,{"C6_QTDLIB"		, Round(0,TamSx3("C6_QTDVEN")[2]),Nil})
						EndIf

						aadd(aAuxItens,{"C6_PRUNIT"		, Round(nPrecoTab,TamSx3("C6_PRUNIT")[2]),Nil})
						aadd(aAuxItens,{"C6_PRCVEN"		, Round(nPrecoVenda,TamSx3("C6_PRCVEN")[2]),Nil})
						aadd(aAuxItens,{"C6_VALOR"		, Round(nTotal,TamSx3("C6_QTDVEN")[2]),Nil})
						aadd(aAuxItens,{"C6_ENTREG"		, dDataEntrega,Nil})

						aAdd(aAuxItens,{"C6_YPROWEB"	, aProdutos[nX]:cCodERPOrig , NIL} )
						aAdd(aAuxItens,{"C6_YQTDWEB"	, aProdutos[nX]:nQtdERPOrig , NIL} )
						aAdd(aAuxItens,{"C6_YSKUWEB"	, aProdutos[nX]:cSkuERPOrig	, NIL} )

						aAuxItens := FWVetByDic( aAuxItens, 'SC6' )

						// Verifica a disponibilidade da reserva.
						If lChekRes
							// Trata a reserva para ser validada.
							aItenAux  := U_IncResPed(aAuxItens,oCliente:cCliente,oCliente:cLoja,cProduto,nQdtVenda,"01",aItens)
							aAuxItens := aclone(aItenAux)
						End If

						aAdd(aItens,aAuxItens)

					Else

						//Registra o erro no cadastro do produtos no vetor
						::lContinua := .F.
						::cNewStatus := "P"

						aAdd(::aMsgErro,"Não foi possivel definir um preco para o produto "+AllTrim(cProduto)+" na base de dados, favor revisar a tabela SB0 na Empresa\Filial "+cEmpAnt+"\"+cFilAnt+"!")
					EndIf

				Else
					//Registra o erro no cadastro do produtos no vetor
					::lContinua := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro,"Não foi possivel encontrar uma TES de Venda para o produto "+AllTrim(cProduto)+" na base de dados, favor revisar as tabelas SF4 e SFM na Empresa\Filial "+cEmpAnt+"\"+cFilAnt+"!")
				EndIf

			Next

			If ::lContinua

				//Monta cabeçalho do pedidos de venda
				aadd(aCabec,{"C5_TIPO" 		,"N",Nil})
				aadd(aCabec,{"C5_CLIENTE"	,oCliente:cCliente,Nil})
				aadd(aCabec,{"C5_LOJACLI"	,oCliente:cLoja,Nil})
				aadd(aCabec,{"C5_LOJAENT"	,oCliente:cLoja,Nil})
				aadd(aCabec,{"C5_YEMPFOR"	,aProdEst[nI][1] + aProdEst[nI][2],Nil})

				If !Empty(oCliente:cCondPag)
					aadd(aCabec,{"C5_CONDPAG",oCliente:cCondPag,Nil})
				ElseIf !Empty(cCondPag)
					aadd(aCabec,{"C5_CONDPAG",cCondPag,Nil})
				EndIf

				If ! Empty(::cCodSA3)
					aadd(aCabec,{"C5_VEND1",::cCodSA3,Nil})
					cCodVend := ::cCodSA3
				ElseIf !Empty(oCliente:cVendedor)
					aadd(aCabec,{"C5_VEND1",oCliente:cVendedor,Nil})
					cCodVend := oCliente:cVendedor
				EndIf

				aAreaA1U := A1U->(GetArea())
				SA3->(dbSetOrder(1)) //A3_FILIAL, A3_COD, R_E_C_N_O_, D_E_L_E_T_
				A1U->(dbSetOrder(1)) //A1U_FILIAL, A1U_CGC, R_E_C_N_O_, D_E_L_E_T_

				// Informe a situação de compra
				// Não presencial, NET
				aadd(aCabec,{"C5_INDPRES"	,"2",Nil})

				// Busca o CGC do vendedor

				If A1U->(Dbseek(xFilial("A1U") + VT1->VT1_CODA1U))
					aadd(aCabec,{"C5_CODA1U",A1U->A1U_CODIGO,Nil})
				End if

				RestArea(aAreaA1U)

				//Fim Linha 37

				aadd(aCabec,{"C5_EMISSAO"	,dDataBase,Nil})
				aadd(aCabec,{"C5_YSTATUS"	,"B",Nil})
				aadd(aCabec,{"C5_YPEDWEB"	,::cOrderID,Nil})
				aadd(aCabec,{"C5_YAPI"		,::cAPI,Nil})
				aadd(aCabec,{"C5_ESPECI1"	,cEspecie,Nil})
				aadd(aCabec,{"C5_VOLUME1"	,Round(nVolumes,TamSx3("C5_VOLUME1")[2]),Nil})
				aadd(aCabec,{"C5_PESOL"		,Round(nPesoLiq,TamSx3("C5_PESOL")[2]),Nil})
				aadd(aCabec,{"C5_PBRUTO"	,Round(nPesoBrut,TamSx3("C5_PBRUTO")[2]),Nil})

				aadd(aCabec,{"C5_TRANSP"	,::cTransp,Nil})

				If !Empty(::cTipoFrete)
					aadd(aCabec,{"C5_TPFRETE",::cTipoFrete,Nil})
				EndIf

				aadd(aCabec,{"C5_FRETE",::nValFrete,Nil})
				aadd(aCabec,{"C5_TIPLIB","2",Nil})
				aadd(aCabec,{"C5_YHRINC",TIME(),Nil})

				If !Empty(oCliente:cComplemento)
					aadd(aCabec,{"C5_YMSGNF","COMPLEMENTO "+oCliente:cComplemento,Nil})
				EndIf

				aadd(aCabec,{"C5_YMODFRE", ::cModalidadeFrete,Nil}) //A VT1 já está posicionada

				If Len(aItens) > 0
					aCabec			:= FWVetByDic( aCabec, 'SC5' )
					MsExecAuto({|x,y,z| MATA410(x,y,z)},aCabec,aItens,3)
				Else
					::lContinua := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro,"Não foram encontrados itens da base para o pedido."+cEmpAnt+"\"+cFilAnt+"!")
				EndIf

				If ! lMsErroAuto //se não deu erro, atribui o número do pedido a propriedade da classe
					::cNumPedido	:= SC5->C5_NUM
				Else
					::lContinua := .F.
					::cNewStatus := "P"

					cLogTxt := "EMPRESA:" + cEmpant + " FILIAL:" + cFilAnt	+ CRLF
					cLogTxt += MemoRead(NomeAutoLog())
					// Apaga o arquivo
					FErase(NomeAutoLog())
					//aAdd(::aMsgErro,MostraErro(::cPathLog,"SC5"+AllTrim(::cNumPed)+".LOG"))
					aAdd(::aMsgErro,cLogTxt)
					DisarmTransaction()

				EndIf

			EndIf

			SB2->(MSUnlockAll())

		End Transaction

	Else //se o pedido já está gravado

		//atualiza variavel com numero do pedido de venda já cadastrado
		::cNumPedido := SC5->C5_NUM

		//Realiza estorno de liberação de estoque e credito
		SC9->(dbSetOrder(1))
		If SC9->(dbSeek(xFilial('SC9')+::cNumPedido))

			While SC9->(!Eof()) .and. xFilial('SC9')+::cNumPedido == SC9->C9_FILIAL+SC9->C9_PEDIDO

				If Empty(SC9->C9_NFISCAL)

					SC6->(dbSetOrder(1))
					SC6->(dbSeek(xFilial("SC6")+SC9->C9_PEDIDO+SC9->C9_ITEM))

					If SC6->C6_QTDVEN-SC6->C6_QTDENT > 0

						aAdd(aRecSC6,SC6->(Recno()))

					EndIf

					U_EstorPedido(SC6->C6_NUM, SC6->(Recno()))

				EndIf

				SC9->(dbSkip())

			EndDo

			U_LibPedido(::cNumPedido)
			//Caso tenha algum item liberado anteriormente realiza uma nova liberação

		EndIf

	EndIf

	If ::lContinua
		::cCodCliente		:= SC5->C5_CLIENTE
		::cLojaCliente		:= SC5->C5_LOJACLI

		dbSelectArea("SA1")
		SA1->(dbSetOrder(1))
		If SA1->(dbSeek(xFilial("SA1")+SC5->(C5_CLIENTE+C5_LOJACLI)))
			::cMunicipio	:= SA1->A1_MUN
		EndIf

	EndIf

Next

UnLockByName("CreateSC5Ped"+::cOrderID, .T., .T., .T.)

Return

Method CreateSL1Ped(oCliente) Class ECPEDIDO

	Local aCabSLQ	:= {}
	Local aAxIteSLR := {}
	Local aProdSLR 	:= {}
	Local aAxPagSL4 := {}
	lOCAL aPagSL4	:= {}
	Local nI 		:= 0
	Local nPesoBrut	:= 0
	Local nPesoLiq	:= 0
	Local nImposto	:= 0
	Local nTotCalc	:= 0
	Local nTotOrigem:= 0
	Local nTolImp	:= SuperGetMv("MV_YTOLIMP",.F.,0.05)
	Local cOper	   	:= SuperGetMv("FB_OPERVEN",.F.,"51")
	Local cCodModal := SuperGetMv("FB_MODALTR",.F.,"0003")
	Local lDescDIFAL:= SuperGetMv("MV_YDECDFL",.F.,.T.)
	Local cTES		:= ""
	Local cProduto	:= ""
	Local cLogTxt	:= ""
	Local cItemPed  := "00"
	Local cStartPath:= GetSrvProfString("Startpath","")

	Private lMsHelpAuto := .T. //Variavel de controle interno do ExecAuto
	Private lMsErroAuto := .F. //Variavel que informa a ocorrência de erros no ExecAuto
	Private INCLUI      := .T. //Variavel necessária para o ExecAuto identificar que se trata de uma inclusão
	Private ALTERA      := .F. //Variavel necessária para o ExecAuto identificar que se trata de uma inclusão

	SF4->(DbSetOrder(1))  // F4_FILIAL, F4_CODIGO, R_E_C_N_O_, D_E_L_E_T_
	SA1->(DbSetOrder(1))  // A1_FILIAL, A1_COD   , A1_LOJA   , R_E_C_N_O_, D_E_L_E_T_
	SL1->(dbSetOrder(25)) // L1_FILIAL, L1_YAPI  , L1_YPEDWEB, R_E_C_N_O_, D_E_L_E_T_
	SA1->(DbSeek(xFilial("SA1") + oCliente:cCliente + oCliente:cLoja))

	// Verifica se o pedido já existe na base.
	If !SL1->(DbSeek(xFilial("SL1") + ::cAPI + ::cOrderID))

		//-----------------------------------------------------------------------//
		// Trecho adicionado em 14/09 conforme estava no SchedPedido             //
		// Para ajuste do preço dos produtos que tem calculo do DIFAL por fora   //
		//-----------------------------------------------------------------------//
		If lDescDIFAL

			/*Para facilitar a utilização da rotina de recálculo transformo o array no
			seguinte padrão.
			//_aPVItens[01] - CODIGO DE PRODUTO	
			//_aPVItens[02] - QUANTIDADE VENDIDA
			//_aPVItens[03] - PRECO PRATICADO
			//_aPVItens[04] - FORNECEDOR DAS PECAS
			//_aPVItens[05] - LOJA FORNECEDOR
			//_aPVItens[06] - EMPRESA
			//_aPVItens[07] - FILIAL 
			//_aPVItens[08] - INDICA QUE O PRODUTO FOI LOCALIZADO NA BASE
			//_aPVItens[09] - PRECO TABELA
			//_aPVItens[10] - VALOR TOTAL DO ITEM
			//_aPVItens[11] - ID ORIGINAL DO SKU NO VTEX, NECESSARIO PARA ENVIAR O INVOICE PARA O VTEX
			//_aPVItens[12] - QT VENDIDA DO SKU, NECESSARIO PARA ENVIAR O INVOICE PARA VTEX
			//_aPVItens[13] - TES (NAO TENHO A TES)
			//_aPVItens[14] - FRETE RATEADO (NAO TENHO)
			//_aPVItens[15] - IMPOSTO DIFAL (NAO TENHO)
			//_aItensped[16] - DESCONTO RATEADO
			*/
			_aLin 	:= {}
			_aItens := {}

			For nI := 1 To Len(::aPedItens)

				_aLin:={::aPedItens[nI]:cCodProd,; //01
				::aPedItens[nI]:nQuantidade,; //02
				::aPedItens[nI]:nValUnit,; //03
				"",;			//04
				"",;			//05
				"",;			//06
				"",;			//07
				"",;			//08
				::aPedItens[nI]:nValUnit,;	//09
				Round(Round(::aPedItens[nI]:nQuantidade,TamSx3("L2_QUANT")[2]) * Round(::aPedItens[nI]:nValUnit,TamSx3("L2_VRUNIT")[2]), TamSx3("L2_VLRITEM")[2]),; //10
				"",;			//11
				0,;				//12
				"",;			//13
				0,;				//14
				0,;				//15
				0 }				//16

				aadd(_aItens,_aLin)

				_aLin := {}

			Next nI

			_aItens := U_FBLKIMP(oCliente:cCliente, oCliente:cLoja, _aItens, ::nValFrete, ::nTotalPedido )

			//Agora Atualiza o Array
			//Posicoes Fixas do Array _aItensped não deve ser alterado.
			//aProdutos[01] - SEQUENCIA DO ITEM
			//aProdutos[02] - CODIGO DO PRODUTO
			//aProdutos[03] - QUANTIDADE
			//aProdutos[04] - PREÇO DE VENDA
			//aProdutos[05] - .T.
			//aProdutos[06] - Data de Entrega
			//aProdutos[07] - Preço de Tabela
			//-----------------------------------------------------------------------//
			// Recalcula nTotalPedido com base no que foi efetivamente apurado pela  //
			// U_FBLKIMP (itens liquidos + imposto retido) mais o frete, pois o      //
			// arredondamento do preco unitario pode gerar diferenca de centavos     //
			// em relacao ao valor originalmente informado. Sem esse ajuste, o SL4   //
			// eh gravado com o valor bruto original e o ERP acusa divergencia entre //
			// o pagamento e o pedido.                                              //
			//-----------------------------------------------------------------------//
			nImposto := 0
			nTotCalc := 0
			For nI := 1 To Len (::aPedItens)
				::aPedItens[nI]:nValUnit 	:= Round(_aItens[nI][03],TamSx3("L2_VRUNIT")[2])
				::aPedItens[nI]:nValTotal	:= _aItens[nI][02] * ::aPedItens[nI]:nValUnit
				nImposto += _aItens[nI][15]
				nTotCalc += ::aPedItens[nI]:nValTotal
			Next nI

			nTotOrigem := ::nTotalPedido
			::nTotalPedido := Round(nTotCalc + nImposto + ::nValFrete, 2)

			If Abs(nTotOrigem - ::nTotalPedido) > nTolImp
				::lContinua  := .F.
				::cNewStatus := "P"
				aAdd(::aMsgErro,"A divergencia entre o valor do pedido (" + AllTrim(cValToChar(nTotOrigem)) + ") e o valor calculado apos os impostos (" + AllTrim(cValToChar(::nTotalPedido)) + ") e maior que o parametro MV_YTOLIMP configurado nesta filial (" + AllTrim(cValToChar(nTolImp)) + ") na Empresa\Filial " + cEmpAnt + "\" + cFilAnt + "!")
			EndIf

		EndIf

		If ::lContinua
			For nI := 1 to Len(::aPedItens)

				cProduto 	:= ::aPedItens[nI]:cCodProd
				nPrecoVenda := ::aPedItens[nI]:nValUnit
				dDataEntrega:= ::aPedItens[nI]:dDtEntrega
				nPesoBrut	+= ::aPedItens[nI]:nPesoProtheus * ::aPedItens[nI]:nQuantidade
				nPesoLiq	+= ::aPedItens[nI]:nPesoProtheus * ::aPedItens[nI]:nQuantidade

				// Busca TES
				cTES := U_VIXA103(2,cOper,SA1->A1_COD,SA1->A1_LOJA,"C",cProduto)

				// Verifica a existencia de TES
				If !SF4->(dbSeek(xFilial("SF4")+cTES))
					::lContinua := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro,"Não foi possivel encontrar uma TES de Venda para o produto "+AllTrim(cProduto)+" na base de dados, favor revisar as tabelas SF4 e SFM na Empresa\Filial "+cEmpAnt+"\"+cFilAnt+"!")
					Loop
				End if

				// Verifica valor de venda da Web
				If 	nPrecoVenda <= 0
					::lContinua := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro,"Não foi possivel definir um preco para o produto "+AllTrim(cProduto)+" na base de dados, favor revisar a tabela ZZZ na Empresa\Filial "+cEmpAnt+"\"+cFilAnt+"!")
					Loop
				End if

				cItemPed := Soma1(cItemPed)

				aAdd( aAxIteSLR, {"LR_ITEM"	  , cItemPed 					, NIL} )
				aAdd( aAxIteSLR, {"LR_PRODUTO", ::aPedItens[nI]:cCodProd   	, NIL} )
				aAdd( aAxIteSLR, {"LR_QUANT"  , ::aPedItens[nI]:nQuantidade , NIL} )
				aAdd( aAxIteSLR, {"LR_VRUNIT" , ::aPedItens[nI]:nValUnit   	, NIL} )
				aAdd( aAxIteSLR, {"LR_VLRITEM", ::aPedItens[nI]:nValTotal  	, NIL} )
				aAdd( aAxIteSLR, {"LR_PRCTAB" , ::aPedItens[nI]:nValUnit  	, NIL} )
				aAdd( aAxIteSLR, {"LR_LOCAL"  , "01"   						, NIL} )
				aAdd( aAxIteSLR, {"LR_TES"    , cTES   						, NIL} )
				aAdd( aAxIteSLR, {"LR_DESC"   , 0                     		, NIL} )
				aAdd( aAxIteSLR, {"LR_VALDESC", 0                     		, NIL} )
				aAdd( aAxIteSLR, {"LR_DESCPRO", 0                     		, NIL} )
				aAdd( aAxIteSLR, {"LR_VEND"   , ::cCodSA3            		, NIL} )
				aAdd( aAxIteSLR, {"LR_YPROWEB", ::aPedItens[nI]:cCodERPOrig , NIL} )
				aAdd( aAxIteSLR, {"LR_YQTDWEB", ::aPedItens[nI]:nQtdERPOrig , NIL} )
				aAdd( aAxIteSLR, {"LR_YSKUWEB", ::aPedItens[nI]:cSkuERPOrig	, NIL} )

				// Organiza conforme o SX3
				aAxIteSLR := FWVetByDic( aAxIteSLR, 'SLR' )

				AADD(aProdSLR, aAxIteSLR)

				aAxIteSLR := {}

			Next
		End if

		If ::lContinua

			aAdd( aCabSLQ, {"LQ_VEND"     , ::cCodSA3   		, NIL} )
			aAdd( aCabSLQ, {"LQ_CLIENTE"  , SA1->A1_COD   		, NIL} )
			aAdd( aCabSLQ, {"LQ_LOJA"     , SA1->A1_LOJA  		, NIL} )
			aAdd( aCabSLQ, {"LQ_TIPOCLI"  , SA1->A1_TIPO  		, NIL} )
			aAdd( aCabSLQ, {"LQ_DESCONT"  , 0             		, NIL} )
			aAdd( aCabSLQ, {"LQ_DTLIM"    , dDatabase + 10    	, NIL} )
			aAdd( aCabSLQ, {"LQ_EMISSAO"  , dDatabase     		, NIL} )
			aAdd( aCabSLQ, {"LQ_CONDPG"   , ::cCodPag			, NIL} ) // Em branco para usar condição negociada
			aAdd( aCabSLQ, {"LQ_FORMPG"   , "NF"          		, NIL} )
			aAdd( aCabSLQ, {"LQ_NUMMOV"   , "1 "          		, NIL} )

			// Não presencial, Net
			aAdd( aCabSLQ, {"LQ_INDPRES"  , "2"   				, NIL} ) // Não Presencial,Net

			// Verifica se é entrega e selecione o modal
			If ::cTipoExpedicao == "1"
				aAdd( aCabSLQ, {"LQ_YCDCLFR"  , cCodModal	    , NIL} )
			End if

			aAreaA1U := A1U->(GetArea())
			A1U->(dbSetOrder(1)) //A1U_FILIAL, A1U_CODIGO

			If A1U->(Dbseek(xFilial("A1U") + VT1->VT1_CODA1U))
				aadd(aCabSLQ,{"LQ_INTERMD",A1U->A1U_CODIGO,Nil})
			End if

			// Retorno a area antes do exeauto para que não afete a validação do F3.
			// ExistCpo
			RestArea(aAreaA1U)

			aAdd( aCabSLQ, {"LQ_TRANSP"	  , ::cTransp	  		, NIL} ) // Transportadora
			aAdd( aCabSLQ, {"LQ_TPFRET"	  , "C"	  		  		, NIL} ) // C=CIF
			aAdd( aCabSLQ, {"LQ_YTPENTR"  , ::cTipoExpedicao	, NIL} ) // 1=Loja Entrega, 2=Cliente Retira
			aAdd( aCabSLQ, {"LQ_FRETE"    , ::nValFrete   		, NIL} ) // Valor do Frete
			aAdd( aCabSLQ, {"LQ_YTPVND"	  , "2"	  		  		, NIL} ) // 2=Pedido
			aAdd( aCabSLQ, {"LQ_YPEDWEB"  , ::cOrderID	  		, NIL} )
			aAdd( aCabSLQ, {"LQ_YAPI"	  , ::cAPI		  		, NIL} )
			aAdd( aCabSLQ, {"LQ_PBRUTO"	  , nPesoBrut		  	, NIL} )
			aAdd( aCabSLQ, {"LQ_PLIQUI"	  , nPesoLiq		  	, NIL} )
			aAdd( aCabSLQ, {"LQ_ESPECI1"  , "VOLUME(S)" 		, Nil} )
			aAdd( aCabSLQ, {"LQ_YSTATUS"  , "B"		  	  		, NIL} ) // B=Bloqueado



			// Organiza conforme o SX3
			aCabSLQ := FWVetByDic( aCabSLQ, 'SLQ' )

			// Para inclusão do pedido o sistema irá criar apenas uma parcela com
			// o total do pedido e futuramento será transformado quando identificado
			// o pagamento.
			aAdd( aAxPagSL4, {"L4_DATA"   , dDatabase 		, NIL} )
			aAdd( aAxPagSL4, {"L4_VALOR"  , ::nTotalPedido  , NIL} )
			aAdd( aAxPagSL4, {"L4_FORMA"  , "NF"			, NIL} )
			aAdd( aAxPagSL4, {"L4_ADMINIS", " "       		, NIL} )
			aAdd( aAxPagSL4, {"L4_NUMCART", ::cSequence  	, NIL} )
			aAdd( aAxPagSL4, {"L4_FORMAID", " "       		, NIL} )
			aAdd( aAxPagSL4, {"L4_MOEDA"  , 0         		, NIL} )

			// Organiza conforme o SX3
			aAxPagSL4 := FWVetByDic( aAxPagSL4, 'SL4' )

			aAdd(aPagSL4, aAxPagSL4)
			aAxPagSL4 := {}

			nModulo := 12
			SetFunName("LOJA701")

			Begin Transaction

				MSExecAuto({|a,b,c,d,e,f,g,h| Loja701(a,b,c,d,e,f,g,h)},.F.,3,"","",{},aCabSLQ,aProdSLR ,aPagSL4)

				If lMsErroAuto
					::lContinua		:= .F.

					cLogTxt := "EMPRESA:" + cEmpant + " FILIAL:" + cFilAnt	+ CRLF
					cLogTxt += MostraErro(cStartPath)
					aAdd(::aMsgErro,cLogTxt)

					FWLogMsg("INFO", , "INFO", , , , cLogTxt, , , )
					DisarmTransaction()
				Else
					::cNumPedido	:= SL1->L1_NUM

					// Força para nascer bloqueado
					RecLock("SL1",.F.)
					SL1->L1_YSTATUS := "B"
					SL1->(msUnlock())
				EndIf

			End Transaction

		End if
	Else
		//atualiza variavel com numero do pedido de venda já cadastrado
		::cNumPedido := SL1->L1_NUM
	Endif

	If ::lContinua
		::cCodCliente	:= SA1->A1_COD
		::cLojaCliente	:= SA1->A1_LOJA
		::cMunicipio	:= SA1->A1_MUN
	EndIf
Return


Method CreateSUAPed(oCliente) Class ECPEDIDO

	Local aHeader 		:= {}
	Local aItem 		:= {}
	Local aItems 		:= {}
	Local nCount 		:= 0
	Local nX 			:= 0
	Local aProdEst 		:= {}
	Local aProdutos 	:= {}
	Local cBkpFunName	:= Funname()

	Private lMsErroAuto := .F.

	// Quebra pedidos por filiais de armazem
	For nCount := 1 To Len(::aPedItens)

		lVolAuto := .F.
		cEmpEst  := cEmpAnt
		cFilEst  := cFilAnt
		cProduto := ::aPedItens[nCount]:cCodProd
		cFabricante := ::aPedItens[nCount]:cFabricante

		// Localiza a empresa armazenadora dentro da empresa para realizar a divisão dos pedidos de venda
		jEmpForArm := U_GetEmpForArm(cProduto)

		// Verifica se o armazenamento é externo
		If jEmpForArm["externo"]
			lVolAuto := .T.
		EndIf

		cEmpEst := jEmpForArm["grupo"]
		cFilEst := jEmpForArm["filial"]

		nPos := 0

		If Len(aProdEst) == 0

			aAdd(aProdEst, {cEmpEst, cFilEst, lVolAuto, {::aPedItens[nCount]}})
		Else

			nPos := aScan(aProdEst, {|x| x[1]+x[2] == cEmpEst + cFilEst})

			If nPos > 0
				aAdd(aProdEst[nPos, 4], ::aPedItens[nCount])
			Else

				aAdd(aProdEst, {cEmpEst, cFilEst, lVolAuto, {::aPedItens[nCount]}})
			EndIf
		EndIf
	Next

	For nCount := 1 to Len(aProdEst)

		// Verifica se já existe atentimento call center
		SUA->(DbsetOrder(14))
		If !SUA->(Dbseek(FWxFilial("SUA") + Padr(::cOrderID, TamSx3("UA_YPEDWEB")[1]) + Padr(::cAPI, TamSx3("UA_YAPI")[1]) ))

			aHeader := {}
			aItem := {}
			aItems := {}

			aMults := {}
			aProdutos := aProdEst[nCount][4]

			//------------------------------------------------------------------------------//
			// Tratamento para deadlocks através do uso de MultLock                         //
			//------------------------------------------------------------------------------//
			For nX := 1 to Len(aProdutos)

				If SB2->(dbSeek(xFilial('SB2') + aProdutos[nX]:cCodProd + "01"))
					aAdd(aMults, SB2->(B2_FILIAL + B2_COD + B2_LOCAL))
				Endif
			Next

			If !MultLock("SB2", aMults, 1)
				::lContinua := .F.
				SB2->(MSUnlockAll())
				Break
			EndIf


			For nX := 1 to Len(aProdutos)

				aItem := {}

				lVldSalEst := U_FLIB008_Valida_Saldo_Estoque(aProdutos[nX]:cCodProd, aProdutos[nX]:nQuantidade)

				aAdd(aItem, {"UB_ITEM"	 , StrZero(nX, 2)	    						, Nil})
				aAdd(aItem, {"UB_PRODUTO", aProdutos[nX]:cCodProd						, Nil})
				aAdd(aItem, {"UB_QUANT"	 , If (lVldSalEst, aProdutos[nX]:nQuantidade, 0), Nil})
				aAdd(aItem, {"UB_VRUNIT" , aProdutos[nX]:nValUnit						, Nil})
				aAdd(aItem, {"UB_OPER"	 , "01"											, Nil})
				aAdd(aItem, {"UB_YPROWEB", aProdutos[nX]:cCodERPOrig					, Nil})
				aAdd(aItem, {"UB_YSKUWEB", aProdutos[nX]:cSkuERPOrig					, Nil})
				aAdd(aItem, {"UB_YQTDWEB", aProdutos[nX]:nQtdERPOrig					, Nil})
				aAdd(aItem, {"UB_YPRCWEB", aProdutos[nX]:nValUnit						, Nil})

				aItem := FWVetByDic(aItem, "SUB")
				aAdd(aItems, aItem)

			Next

			If ::lContinua

				cNumTMK := TkNumero("SUA", "UA_NUM")

				aAdd(aHeader, {"UA_NUM"		, cNumTMK			, Nil})
				aAdd(aHeader, {"UA_CLIENTE"	, oCliente:cCliente	, Nil})
				aAdd(aHeader, {"UA_LOJA"	, oCliente:cLoja	, Nil})
				aAdd(aHeader, {"UA_OPERADO"	, ::cOperador		, Nil}) // Codigo do Operador padrao
				aAdd(aHeader, {"UA_VEND"	, ::cCodSA3			, Nil}) // Codigo do Vendedor padrao
				aAdd(aHeader, {"UA_OPER"	, "3"				, Nil}) // 1-Faturamento 2-Orcamento 3-Atendimento
				aAdd(aHeader, {"UA_TMK"		, "1"				, Nil}) // 1-Ativo 2-Receptivo
				aAdd(aHeader, {"UA_CONDPG"	, ::cCodPag			, Nil}) // Condicao de Pagamento
				aAdd(aHeader, {"UA_TRANSP"	, ::cTransp			, Nil}) // Transportadora
				aAdd(aHeader, {"UA_TPFRETE"	, ::cTipoFrete		, Nil}) // Tipo Frete C=CIF
				aAdd(aHeader, {"UA_FRETE"	, ::nValFrete		, Nil}) // Valor Frete
				aAdd(aHeader, {"UA_INDPRES"	, "2"				, Nil}) // 0=Não Aplica; 1=Presencial; 2=Não Presencial,Net; 3=Não Presencial,TeleAtendi.; 5=Presencial,ForadoEstab.; 9=Não Presencial,outros
				aAdd(aHeader, {"UA_YPEDWEB"	, ::cOrderID		, Nil}) // Pedido Web
				aAdd(aHeader, {"UA_YAPI"	, ::cAPI			, Nil}) // API

				If Len(aItems) > 0
					aHeader := FWVetByDic(aHeader, 'SUA')
					SetFunName("TMKA271")
					MSExecAuto({|a, b, c, d| TMKA271(a, b, c, d)}, aHeader, aItems, 3, "2") // 3=Inclusão; "2"=TeleVendas
				Else
					::lContinua := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro, "Não foram encontrados itens na base para o atendimento." + cEmpAnt + "\" + cFilAnt +"!")
				EndIf

				If lMsErroAuto

					::lContinua := .F.
					::cNewStatus := "P"

					cLogTxt := "EMPRESA:" + cEmpant + " FILIAL:" + cFilAnt + CRLF
					cLogTxt += MemoRead(NomeAutoLog())

					FErase(NomeAutoLog())
					aAdd(::aMsgErro, cLogTxt)
					DisarmTransaction()
				Else

					::cNumPedido := cNumTMK
					SUA->(DbsetOrder(1))
					SUA->(Dbseek(FWxFilial("SUA") + cNumTMK))
					SetFunName(cBkpFunName)
				EndIf
			EndIf

			SB2->(MSUnlockAll())

		Else
			::cNumPedido := SUA->UA_NUM
		EndIf

		If ::lContinua

			::cCodCliente := SUA->UA_CLIENTE
			::cLojaCliente := SUA->UA_LOJA

			DbSelectArea("SA1")
			SA1->(DbSetOrder(1))
			If SA1->(Dbseek(FWxFilial("SA1") + ::cCodCliente + ::cLojaCliente))
				::cMunicipio := SA1->A1_MUN
			EndIf
		EndIf
	Next
Return()

Method GetVendedor(cMarketPlace,cCodCli,cLoja) Class ECPEDIDO

	Local aArea	    	:= GetArea()
	Local aAreaSA3		:= SA3->(GetArea())
	Local lCliXVend		:= SuperGetMV("MV_YCLIXVE",.F.,.T.)

	Default cCodCli		:= ""
	DeFault cLoja		:= ""
	Default cMarketPlace:= ""

	::cCodSA3 := ""

	// Recupera o vendedor da VT1 se tiver preenchido
	If !Empty(VT1->VT1_CODSA3)
		::cCodSA3 := VT1->VT1_CODSA3
	End if

	// Verifica se localiza o vendedor pelo cliente
	If !Empty(cCodCli)

		cCodCli := Avkey(cCodCli,"ZA0_CLIENT")
		cLoja 	:= Avkey(cLoja	,"ZA0_LOJA")

		ZA0->(dbsetorder(1))
		If ZA0->(dbSeek(xFilial("ZA0")+cCodCli+cLoja))
			::cCodSA3 := ZA0->ZA0_VEND
		Else
			If lCliXVend
				::cCodSA3 := ""
			End if
		End if
	End if

	// Tratamento de vendedor padrao Nuvemshop se vazio
	If Empty(::cCodSA3) .And. AllTrim(::cAPI) == "NUVEMSHOP"
		::cCodSA3 := SuperGetMv("MV_YVENNUV", .F., SuperGetMv("VT_VENDPAD", .F., ""))
		If !Empty(::cCodSA3)
			SA3->(DbSetOrder(1))
			If !SA3->(DbSeek(xFilial("SA3") + ::cCodSA3))
				::cCodSA3 := ""
			EndIf
		EndIf
		If Empty(::cCodSA3)
			SA3->(DbSetOrder(1))
			SA3->(DbGoTop())
			While SA3->(!Eof())
				If SA3->A3_MSBLQL <> "1"
					::cCodSA3 := SA3->A3_COD
					Exit
				EndIf
				SA3->(DbSkip())
			EndDo
		EndIf
	EndIf

	::cCodSA3 := AvKey(::cCodSA3,"A3_COD")

	// Verifica se o codigo do vendedor é valido
	SA3->(dbsetorder(1))
	If !SA3->(DbSeek(xFilial('SA3')+ ::cCodSA3))

		::lContinua := .F.
		::cNewStatus := "P"
		aAdd(::aMsgErro,"Não foi possivel localizar um código de vendedor válido para este Pedido: VT1_CODSA3 ou Carterização Vendedor")

	End if

	RestArea(aAreaSA3)
	RestArea(aArea)

Return ::cCodSA3

Method VldPedTroca() Class ECPEDIDO

	Local cVendB2W := SuperGetMV("MV_YVENB2W",.f.,"0006")
	Local cSeqnINI := SuperGetMV("MV_YSEQB2W",.F.,"4")
	Local nLenSeqn := Len(cSeqnINI)

	// Verifica se o vendedor é B2W
	If Alltrim(::cCodSA3) $ Alltrim(cVendB2W) .and. !Empty(cSeqnINI)

		// Verifica se o pedido inicia com...
		If Alltrim(SubStr(::cSequence,1,nLenSeqn)) ==  Alltrim(cSeqnINI)

			::lContinua := .f.
			::cNewStatus := "P"
			aAdd(::aMsgErro,"ATENÇÃO - O pedido inicia com a expressão '" + Alltrim(cSeqnINI) + "', portanto, é considerado como Pedido de TROCA!!!")
		End if
	End if

Return

//===================================================================

Method GetProduto(oPedido, oCliente) Class ECPEDIDO
	Local aArea		    := GetArea()
	Local aAreaSB1	    := SB1->(GetArea())
	Local nI			:= 0
	Local aItens		:= {}
	Local nValorAtual	:= 0
	Local nQdeItem	    := 0
	Local nPrecoFinal	:= 0
	Local nResto		:= 0
	Local cPrdProtheus  := ''
	Local nPesoWeb	    := 0
	Local nValor		:= 0
	Local nPrecoTab		:= 0
	Local nVlrDesc		:= 0
	Local nVlrMerc		:= 0
	Local oPedItens		:= Nil
	Local cApi			:= ::cApi
	Local dDataEntrega  := stod('')
	Local xItens        := Nil
	Local nQuantidade   := 0
	Local nValUnit      := 0
	Local nVlrRatDesc	:= 0
	Local cAliasVTD		:= ''
	Local cAliasMEV		:= ''
	Local cAliasSB1		:= ''
	Local cQrySB1		:= ''
	Local cSegmento		:= ''
	Local cAtvLotMin	:= "N"
	Local nZ

	IF Alltrim(::cAPI)=="LINKAPI"

		xItens := oPedido:Items

	ElseIf Alltrim(::cAPI)=="ANYMARKET"

		// Recupera os itens do produto
		xItens := oPedido["items"]

		// Recupera o desconto do pedido
		If oPedido:hasProperty("discount")
			nVlrDesc := oPedido["discount"]
		End if

		// Recupera o valor da mercadoria
		If oPedido:hasProperty("gross")
			nVlrMerc	:= oPedido["gross"]
		End if

	ElseIf Alltrim(::cAPI)=="COCKPIT"

		// Recupera os itens do produto
		xItens := oPedido["items"]

		// Recupera o desconto do pedido
		If oPedido:hasProperty("discount")
			nVlrDesc := oPedido["discount"]
		End if

		// Recupera o valor da mercadoria
		If oPedido:hasProperty("gross")
			nVlrMerc	:= oPedido["gross"]
		End if

	ElseIf Alltrim(::cAPI) == "NUVEMSHOP"

		If oPedido:hasProperty("products")
			xItens := oPedido["products"]
		EndIf
		If oPedido:hasProperty("discount")
			nVlrDesc := Val(cValToChar(oPedido["discount"]))
		EndIf
		If oPedido:hasProperty("subtotal")
			nVlrMerc := Val(cValToChar(oPedido["subtotal"]))
		EndIf

	ElseIf Alltrim(::cAPI) == "CWS"

		oCws := CWSIntegration():New()

		// Recupera os itens do produto
		If oPedido:hasProperty("deliveries")

			If Len(oPedido["deliveries"]) > 0

				xItens := oPedido["deliveries"][1]["products"]

			EndIf

		EndIf

	EndIf

	DbSelectArea('SB1')
	SB1->(DbSetOrder(1))

	DbSelectArea('VT9')
	VT9->(DbSetOrder(1))

	DbSelectArea('VTD')
	VTD->(DbSetOrder(1))

	DbSelectArea('VTR')
	VTR->(DbSetOrder(2))

	// Recupea o segmento da empresa
	If VTR->(Dbseek(xFilial("VTR") + cEmpAnt + cFilant))
		cSegmento := VTR->VTR_SEGMEN
		cAtvLotMin:= VTR->VTR_ATVLOT
	Else
		cSegmento := Nil
	End if

	For nI := 1 To Len(xItens)

		Do Case

		Case Alltrim(::cAPI) == "ANYMARKET"

			cApi			:= Padr(::cAPI, TamSx3("VT9_API")[1])
			cPrdProtheus	:= ''

			If VT9->(DbSeek(xFilial('VT9')+ cApi + xItens[nI]["sku"]["partnerId"]))
				cPrdProtheus := VT9->VT9_PRODUT
			EndIf

			// O Desconto do Marketplace precisa realizar o rateio
			// Recupera o percentual da participação do item
			nPerc := Round(xItens[nI]["total"]/nVlrMerc,2)

			// Busca o valor do desconto conforme o percentual da participação
			nVlrD := Round(nPerc * nVlrDesc,2)

			// Atualiza o valor total do pedido com o desconto
			xItens[nI]["total"] -= nVlrD

			// Alimenta o valor de desconto rateado
			nVlrRatDesc+= nVlrD

			// Verifica se é o ultimo produto
			If nI == Len(xItens)

				// Verifica se sobrou valores a ratear
				If nVlrRatDesc <> nVlrDesc
					xItens[nI]["total"] -= (nVlrDesc-nVlrRatDesc)
				End if
			End if

			cCodSku			:= xItens[nI]["sku"]["partnerId"]
			nValUnit		:= xItens[nI]["total"]/xItens[nI]["amount"]
			nPrecoTab		:= nValUnit
			cCodWeb			:= xItens[nI]["sku"]["partnerId"]
			cCodProd		:= cPrdProtheus
			nQuantidade		:= xItens[nI]["amount"]
			nValTotal		:= nQuantidade * nValUnit
			nVlrOriginal	:= xItens[nI]["total"]/xItens[nI]["amount"]
			nPesoWeb		:= 0
			::GetDataEntrega(oPedido)
			dDataEntrega	:= ::dDataEntrega

		Case Alltrim(::cAPI) == "COCKPIT"

			cApi			:= Padr(::cAPI, TamSx3("VT9_API")[1])
			cPrdProtheus	:= xItens[nI]["sku"]["partnerId"]

			// O Desconto do Marketplace precisa realizar o rateio
			// Recupera o percentual da participação do item
			nPerc := Round(xItens[nI]["total"]/nVlrMerc,2)

			// Busca o valor do desconto conforme o percentual da participação
			nVlrD := Round(nPerc * nVlrDesc,2)

			// Atualiza o valor total do pedido com o desconto
			xItens[nI]["total"] -= nVlrD

			// Alimenta o valor de desconto rateado
			nVlrRatDesc+= nVlrD

			// Verifica se é o ultimo produto
			If nI == Len(xItens)

				// Verifica se sobrou valores a ratear
				If nVlrRatDesc <> nVlrDesc
					xItens[nI]["total"] -= (nVlrDesc-nVlrRatDesc)
				End if
			End if

			cCodSku			:= xItens[nI]["sku"]["partnerId"]
			nValUnit		:= xItens[nI]["total"]/xItens[nI]["amount"]
			nPrecoTab		:= nValUnit
			cCodWeb			:= xItens[nI]["sku"]["partnerId"]
			cCodProd		:= cPrdProtheus
			nQuantidade		:= xItens[nI]["amount"]
			nValTotal		:= nQuantidade * nValUnit
			nVlrOriginal	:= xItens[nI]["total"]/xItens[nI]["amount"]
			nPesoWeb		:= 0
			::GetDataEntrega(oPedido)
			dDataEntrega	:= ::dDataEntrega

		Case Alltrim(::cAPI) == "LINKAPI"

			cAliasVTD		:= GetNextAlias()

			BeginSql Alias cAliasVTD
					SELECT  DISTINCT
						VTD.VTD_IDWEB,
						VTD.VTD_PRODUT
					FROM
						%Table:VTD% VTD
					WHERE VTD.VTD_FILIAL	= %xFilial:VTD%
						AND VTD.VTD_API		= %Exp:self:cAPI%
						AND VTD.VTD_IDSKU	= %Exp:xItens[nI]:sellerSku%
						AND VTD.%NotDel%
			EndSql

			cCodSku	        := xItens[nI]:sellerSku
			nValUnit        := xItens[nI]:sellingPrice / 100 //Valor já com desconto
			nPrecoTab		:= nValUnit //xItens[nI]:price / 100
			cCodWeb         := (cAliasVTD)->VTD_IDWEB
			cCodProd        := (cAliasVTD)->VTD_PRODUT
			nQuantidade		:= xItens[nI]:quantity
			nValTotal		:= nQuantidade * nValUnit
			nVlrOriginal	:= nValUnit //xItens[nI]:sellingPrice / 100
			nPesoWeb		:= xItens[nI]:additionalInfo:dimension:weight / 1000
			::GetDataEntrega(oPedido)
			dDataEntrega	:= ::dDataEntrega

			(cAliasVTD)->(dbCloseArea())


		Case Alltrim(::cAPI) == "CWS"

			cApi := Padr(::cAPI, TamSx3("VT9_API")[1])

			cPrdProtheus := oCws:GetIdERPByCWS(xItens[nI]["partnerPartCode"])
			//cPrdProtheus := RetField("SB1", 18, xFilial("SB1") + xItens[nI]["partnerPartCode"], "B1_COD")

			cCodSku	:= cValToChar(xItens[nI]["id"])
			nValUnit := xItens[nI]["price"]
			nPrecoTab := nValUnit
			cCodWeb	:= xItens[nI]["partnerPartCode"]
			cCodProd := cPrdProtheus
			nQuantidade	:= xItens[nI]["quantity"]
			nValTotal := nQuantidade * nValUnit
			nVlrOriginal := nValUnit
			nPesoWeb := 0

			::GetDataEntrega(oPedido)

			dDataEntrega := ::dDataEntrega

		Case Alltrim(::cAPI) == "NUVEMSHOP"


			cCodSku := ""
			cBarCode := ""
			If xItens[nI]:hasProperty("sku")
				cCodSku := AllTrim(cValToChar(xItens[nI]["sku"]))
			EndIf
			If xItens[nI]:hasProperty("barcode")
				cBarCode := AllTrim(cValToChar(xItens[nI]["barcode"]))
			EndIf

			cPrdProtheus := ""

			// 1) Busca por EAN (B1_CODBAR) via SQL nativo
			If !Empty(cBarCode)
				cAliasSB1 := GetNextAlias()
				cQrySB1 := "SELECT B1_COD FROM " + RetSqlName("SB1") + " SB1 "
				cQrySB1 += " WHERE SB1.D_E_L_E_T_ = ' ' "
				cQrySB1 += "   AND (SB1.B1_FILIAL = '" + xFilial("SB1") + "' OR SB1.B1_FILIAL = ' ') "
				cQrySB1 += "   AND SB1.B1_CODBAR = '" + cBarCode + "' "
				cQrySB1 := ChangeQuery(cQrySB1)
				dbUseArea(.T., "TOPCONN", TcGenQry(,, cQrySB1), cAliasSB1, .F., .T.)
				If !(cAliasSB1)->(Eof())
					cPrdProtheus := AllTrim((cAliasSB1)->B1_COD)
				EndIf
				(cAliasSB1)->(dbCloseArea())

				// Fallback via indice caso query nao retorne
				If Empty(cPrdProtheus)
					SB1->(DbSetOrder(5)) // B1_CODBAR
					If SB1->(DbSeek(xFilial("SB1") + cBarCode))
						cPrdProtheus := SB1->B1_COD
					EndIf
				EndIf
			EndIf

			// 2) Busca por Codigo interno Protheus (B1_COD)
			If Empty(cPrdProtheus) .And. !Empty(cCodSku)
				SB1->(DbSetOrder(1)) // B1_COD
				If SB1->(DbSeek(xFilial("SB1") + PADR(cCodSku, TamSX3("B1_COD")[1])))
					cPrdProtheus := SB1->B1_COD
				EndIf
			EndIf

			// 3) Se o proprio SKU for o EAN ou estiver gravado no B1_CODBAR
			If Empty(cPrdProtheus) .And. !Empty(cCodSku)
				cAliasSB1 := GetNextAlias()
				cQrySB1 := "SELECT B1_COD FROM " + RetSqlName("SB1") + " SB1 "
				cQrySB1 += " WHERE SB1.D_E_L_E_T_ = ' ' "
				cQrySB1 += "   AND (SB1.B1_FILIAL = '" + xFilial("SB1") + "' OR SB1.B1_FILIAL = ' ') "
				cQrySB1 += "   AND SB1.B1_CODBAR = '" + cCodSku + "' "
				cQrySB1 := ChangeQuery(cQrySB1)
				dbUseArea(.T., "TOPCONN", TcGenQry(,, cQrySB1), cAliasSB1, .F., .T.)
				If !(cAliasSB1)->(Eof())
					cPrdProtheus := AllTrim((cAliasSB1)->B1_COD)
				EndIf
				(cAliasSB1)->(dbCloseArea())
			EndIf

			// 4) Busca no De/Para VT9 oficial da Fortbras
			If Empty(cPrdProtheus) .And. !Empty(cCodSku) .And. ChkFile("VT9")
				VT9->(DbSetOrder(1))
				cApi := Padr(::cAPI, TamSx3("VT9_API")[1])
				If VT9->(DbSeek(xFilial("VT9") + cApi + cCodSku))
					cPrdProtheus := VT9->VT9_PRODUT
				EndIf
			EndIf

			nQuantidade  := Val(cValToChar(xItens[nI]["quantity"]))
			nValUnit     := Val(cValToChar(xItens[nI]["price"]))
			nPrecoTab    := nValUnit
			cCodWeb      := IIf(!Empty(cCodSku), cCodSku, cBarCode)
			cCodProd     := cPrdProtheus
			nValTotal    := nQuantidade * nValUnit
			nVlrOriginal := nValUnit
			nPesoWeb     := 0
			dDataEntrega := dDataBase



		OTHERWISE
			aAdd(::aMsgErro,'A API "'+AllTrim(::cAPI)+'" não é suportada no momento!')
			::lContinua := .F.
			::cNewStatus := "P"
			Return

		EndCase

		//=======================================================================
		//daqui para baixo, as funções servem para todos as API
		//=======================================================================

		DbSelectArea('SB1')
		SB1->(DbSetOrder(1))

		If ! Empty(cCodProd) .AND. SB1->(DbSeek(xFilial('SB1') + cCodProd ))
			If SB1->B1_TIPO == 'KT'

				//Obtem os produtos do KIT
				cAliasMEV		:= GetNextAlias()

				BeginSql Alias cAliasMEV
					SELECT
						MEU.MEU_CODIGO, MEU.MEU_DESCNT, MEV.MEV_PRODUT, MEV.MEV_QTD, MEV.MEV_DESCNT
						, B1_FABRIC, B1_COD, B1_PESO
						, VT9_IDWEB
					FROM
						%Table:MEU% MEU
						JOIN %Table:MEV% MEV ON MEV.MEV_FILIAL = %xFilial:MEV% AND MEV.%NotDel% AND MEV.MEV_CODKIT = MEU.MEU_CODIGO
						JOIN %Table:SB1% SB1 ON SB1.B1_FILIAL = %xFilial:SB1% AND SB1.%NotDel% AND SB1.B1_COD = MEV.MEV_PRODUT
						JOIN %Table:VT9% VT9 ON VT9.VT9_FILIAL = %xFilial:VT9% AND VT9.%NotDel% AND VT9.VT9_PRODUT = MEU.MEU_CODIGO
							AND VT9_API = %Exp:cApi%
					WHERE
						MEU.MEU_FILIAL = %xFilial:MEU%
						AND MEU.%NotDel%
						AND MEU.MEU_CODIGO = %Exp:cCodProd%
				EndSql

				If (cAliasMEV)->(Eof())
					aAdd(::aMsgErro,'O(s) componente(s) do Kit ('+AllTrim(cCodProd)+') não foi(ram) encontrado(s)!')
					::lContinua := .F.
					::cNewStatus := "P"
				Else
					nValorAtual := 0
					nQdeItem	:= 0
					//Soma os valores atuais dos produtos do KIT para rateio de valores
					(cAliasMEV)->(DbGoTop())
					While !(cAliasMEV)->(Eof())
						nValorAtual += U_PrvEcommerce((cAliasMEV)->MEV_PRODUT,cSegmento) * (cAliasMEV)->MEV_QTD * nQuantidade
						nQdeItem ++

						(cAliasMEV)->(DbSkip())
					EndDo

					(cAliasMEV)->(DbGoTop())

					If nQdeItem == 1 //Caso o KIT possua apenas um produto

						oPedItens               := ECPEDITENS():NEW()
						oPedItens:cCodWeb       := (cAliasMEV)->VT9_IDWEB
						oPedItens:cCodProd      := (cAliasMEV)->MEV_PRODUT
						oPedItens:nQuantidade   := nQuantidade * (cAliasMEV)->MEV_QTD
						oPedItens:nValUnit      := nValUnit / (cAliasMEV)->MEV_QTD
						oPedItens:nValTotal     := nValTotal
						oPedItens:dDtEntrega    := dDataEntrega
						oPedItens:cCodSku       := cCodSku
						oPedItens:nVlrOriginal  := nVlrOriginal
						oPedItens:nPesoWeb      := nPesoWeb
						oPedItens:nPesoProtheus := (cAliasMEV)->B1_PESO
						oPedItens:cFabricante   := (cAliasMEV)->B1_FABRIC
						oPedItens:cCodERPOrig	:= (cAliasMEV)->MEU_CODIGO
						oPedItens:nQtdERPOrig	:= nQuantidade
						oPedItens:cSkuERPOrig	:= cCodSku

						oPedItens:CreateSB2()
						oPedItens:GetPreco(oCliente)
						aAdd(aItens, oPedItens)

					Else // Caso o produto seja um KIT e este KIT possuir mais de um produto

						//nPerc := 100-(nValorAtual*100/nPrecoVenda)
						nPerc := nValUnit/nValorAtual
						nValor := 0
						nResto := 0
						While !(cAliasMEV)->(Eof())
							nValor  := U_PrvEcommerce((cAliasMEV)->MEV_PRODUT,cSegmento) //* (cAliasMEV)->MEV_QTD * nQdtVenda
							nQde	:= nQuantidade * (cAliasMEV)->MEV_QTD

							//Rateia o preço entre os itens
							nFator				:= nVlrOriginal / nValUnit
							nPrecoFinal 		:= nValor * nPerc * nQuantidade
							nValUnit 			:= round(nPrecoFinal, TamSx3("C6_PRCVEN")[2])

							nResto 					+= nValUnit * nQde

							oPedItens               := ECPEDITENS():NEW()
							oPedItens:cCodWeb       := (cAliasMEV)->VT9_IDWEB
							oPedItens:cCodProd      := (cAliasMEV)->MEV_PRODUT
							oPedItens:nQuantidade   := nQde
							oPedItens:nValUnit      := round(nPrecoFinal, TamSx3("C6_PRCVEN")[2])
							oPedItens:nValTotal     := oPedItens:nQuantidade * oPedItens:nValUnit
							oPedItens:dDtEntrega    := dDataEntrega
							oPedItens:cCodSku       := (cAliasMEV)->MEV_PRODUT
							oPedItens:nVlrOriginal  := round(nPrecoFinal * nFator, TamSx3("C6_PRCVEN")[2])
							oPedItens:nPesoWeb      := nPesoWeb
							oPedItens:nPesoProtheus := (cAliasMEV)->B1_PESO
							oPedItens:cFabricante   := (cAliasMEV)->B1_FABRIC
							oPedItens:cCodERPOrig	:= (cAliasMEV)->MEU_CODIGO
							oPedItens:nQtdERPOrig	:= nQuantidade
							oPedItens:cSkuERPOrig	:= cCodSku

							oPedItens:CreateSB2()
							oPedItens:GetPreco(oCliente)
							aAdd(aItens, oPedItens)

							(cAliasMEV)->(DbSkip())

						EndDo

						// Verifica se possui diferença
						If round(nResto,TamSx3("C6_VALOR")[2]) <> round(nValTotal,TamSx3("C6_VALOR")[2])
							aItens[Len(aItens)]:nValTotal += round(nValTotal - nResto,TamSx3("C6_VALOR")[2])
							aItens[Len(aItens)]:nValUnit  := round(aItens[Len(aItens)]:nValTotal/aItens[Len(aItens)]:nQuantidade, TamSx3("C6_PRCVEN")[2])
						End if

					EndIf

				EndIf

				(cAliasMEV)->(DbCloseArea())

			Else //Se o produto não for um KIT
				nLoteDist 	:= RetFldProd(SB1->B1_COD,"B1_LM")
				nQtdJson	:= nQuantidade

				// Verifica se o seller utiliza o conceito da Z32
				If Alltrim(cAtvLotMin) == "S"
					// Verifica se o produto é vendido unitario
					Z32->(dbSetOrder(1))
					If Z32->(Dbseek(xFilial("Z32") + SB1->B1_COD))
						nLoteDist := 1
					End if
				End if

				If nLoteDist > 1
					nQuantidade *= nLoteDist
					nValUnit    /= nLoteDist
				EndIf

				nPrecoTab	:= ((nPrecoTab*nQtdJson) / nQuantidade)
				oPedItens               := ECPEDITENS():NEW()
				oPedItens:cCodWeb       := cCodWeb
				oPedItens:cCodProd      := cCodProd
				oPedItens:nQuantidade   := nQuantidade
				oPedItens:nValUnit      := nValUnit
				oPedItens:nPrecoTab		:= nPrecoTab
				oPedItens:nValTotal     := nValTotal
				oPedItens:cCodSku       := cCodSku
				oPedItens:nVlrOriginal  := nVlrOriginal
				oPedItens:nPesoWeb      := nPesoWeb
				oPedItens:nPesoProtheus := SB1->B1_PESO
				oPedItens:dDtEntrega    := dDataEntrega
				oPedItens:cFabricante   := SB1->B1_FABRIC
				oPedItens:cCodERPOrig	:= cCodProd
				oPedItens:nQtdERPOrig	:= nQuantidade
				oPedItens:cSkuERPOrig	:= cCodSku
				oPedItens:CreateSB2()
				oPedItens:GetPreco(oCliente)

				aAdd(aItens, oPedItens)

			EndIf
		Else
			aAdd(::aMsgErro,'Não foi encontrado o produto "'+cCodWeb+'" no cadastro de Produto X Web!')
			::lContinua	 := .F.
			::cNewStatus := "P"
		EndIf

	Next

	If Len(aItens) == 0
		aAdd(::aMsgErro,'Não foi encontrado produtos dentro do pedido!')
		::lContinua	 := .F.
		::cNewStatus := "P"
		::aPedItens := {}
	else
		::aPedItens := aClone(aItens)
	EndIf

	RestArea(aAreaSB1)
	RestArea(aArea)

Return

//===================================================================

Method GetTransp(oPedido) Class ECPEDIDO

	Local cAPI		:= ''
	Local cIdTransp	:= ''
	Local cTranspME2:= SuperGetMv("VT_ME2TRAN",.F.,"000091")
	Local cDelivery := ""
	Local cCWSRetira:= SuperGetMv("MV_YCWSRETI",.f.,"PICKUP_IN_STORE")
	Local cCWSEntreg:= SuperGetMV("MV_YCWSENTR",.F.,"OWN_CARRIER")


	Do Case

	Case Alltrim(::cApi) == "ANYMARKET"

		oAnyPedido := AnyPedido():New()

		If oAnyPedido:GetIdCotacao(VT1->VT1_ORDID) .And. oAnyPedido:cHTTPCode == "200"

			oJson := JsonObject():New()
			oJson:FromJson(oAnyPedido:cJsonResp)

			If oJson:HasProperty("quoteId") .And. oJson:HasProperty("price")

				::nVlrCustoFrete := oJson["price"]
				::cIdCotacao 	 := oJson["quoteId"]

			EndIf

		EndIf

		cAPI := PadR(::cAPI,TamSx3('VT6_API')[1])

		::cTipoExpedicao := "1"

		If oPedido:hasProperty("items") .and. Len(oPedido["items"]) > 0

			If oPedido["items"][1]:hasProperty("shippings")
				If oPedido["items"][1]:hasProperty("shippings") .and. Len(oPedido["items"][1]["shippings"]) > 0
					If oPedido["items"][1]["shippings"][1]:hasProperty("shippingtype")
						cIdTransp := oPedido["items"][1]["shippings"][1]["shippingtype"]
					End if
				End if
			End if
		End if

	Case Alltrim(::cApi) == "COCKPIT"

		oCockPed := CockPedido():New()

		If oCockPed:GetIdCotacao(VT1->VT1_ORDID) .And. oCockPed:cHTTPCode == "200"

			oJson := JsonObject():New()
			oJson:FromJson(oCockPed:cJsonResp)

			If oJson:HasProperty("quoteId") .And. oJson:HasProperty("price")

				::nVlrCustoFrete := oJson["price"]
				::cIdCotacao 	 := oJson["quoteId"]

			EndIf

		EndIf

		cAPI := PadR(::cAPI,TamSx3('VT6_API')[1])

		::cTipoExpedicao := "1"

		If oPedido:hasProperty("items") .and. Len(oPedido["items"]) > 0

			If oPedido["items"][1]:hasProperty("shippings")
				If oPedido["items"][1]:hasProperty("shippings") .and. Len(oPedido["items"][1]["shippings"]) > 0
					If oPedido["items"][1]["shippings"][1]:hasProperty("shippingtype")
						cIdTransp := oPedido["items"][1]["shippings"][1]["shippingtype"]
					End if
				End if
			End if
		End if

	Case Alltrim(::cAPI) == 'NUVEMSHOP'

		cAPI := PadR(::cAPI, TamSx3('VT6_API')[1])
		::cTipoExpedicao := "1" // Loja Entrega

		If oPedido:hasProperty("shipping_option")
			cIdTransp := AllTrim(cValToChar(oPedido["shipping_option"]))
		ElseIf oPedido:hasProperty("shipping_pickup_type")
			cIdTransp := AllTrim(cValToChar(oPedido["shipping_pickup_type"]))
		EndIf

		// Localiza De/Para no VT6
		If !Empty(cIdTransp)
			VT6->(dbSetOrder(1))
			If VT6->(dbSeek(xFilial("VT6") + cAPI + Upper(PadR(cIdTransp, TamSx3('VT6_IDWEB')[1]))))
				::cTransp := VT6->VT6_TRANSP
			EndIf
		EndIf

		// Fallback de transportadora Nuvemshop (Utiliza parametro proprio ou VT_ME2TRAN padrao Fortbras "000091")
		If Empty(::cTransp)
			::cTransp := SuperGetMv("MV_YTRANPNUV", .F., SuperGetMv("VT_ME2TRAN", .F., "000091"))
			If !Empty(::cTransp)
				SA4->(DbSetOrder(1))
				If !SA4->(DbSeek(xFilial("SA4") + ::cTransp))
					::cTransp := ""
				EndIf
			EndIf
			If Empty(::cTransp)
				SA4->(DbSetOrder(1))
				If SA4->(DbSeek(xFilial("SA4")))
					While SA4->(!Eof()) .And. SA4->A4_FILIAL == xFilial("SA4")
						If SA4->(FieldPos("A4_MSBLQL")) == 0 .Or. SA4->A4_MSBLQL <> "1"
							::cTransp := SA4->A4_COD
							Exit
						EndIf
						SA4->(DbSkip())
					EndDo
				EndIf
			EndIf
		EndIf

	Case Alltrim(::cAPI) == 'LINKAPI'

		cAPI 		:= PadR(::cAPI,TamSx3('VT6_API')[1])

		// Verifica se existe informações de logistica
		If Len(oPedido:shippingData:logisticsInfo) > 0

			// Verifica o tipo de Entrega (DELIVERY ou PICKUP-IN-POINT)
			If AttIsMemberOf(oPedido:shippingData:LogisticsInfo[1],"deliveryChannel")

				cDelivery := UPPER(ALLTRIM(oPedido:shippingData:LogisticsInfo[1]:deliveryChannel))

				Do Case
				Case cDelivery == "DELIVERY" 		// ENTREGA

					::cTipoExpedicao := "1"

					// Localiza o codigo da transportadora
					If AttIsMemberOf(oPedido:shippingData:LogisticsInfo[1],"deliveryIds")

						// Verifica se existe o codigo da transportadora
						IF Len(oPedido:shippingData:LogisticsInfo[1]:deliveryIds) > 0

							If AttIsMemberOf(oPedido:shippingData:LogisticsInfo[1]:deliveryIds[1],"courierId")
								cIdTransp		:= Upper(Padr(oPedido:shippingData:logisticsInfo[1]:deliveryIds[1]:courierId,TamSx3("VT6_IDWEB")[1]))
							Else
								::lContinua	 := .F.
								::cNewStatus := "P"
								aAdd(::aMsgErro, "Não possivel identificar informações do transportador. A Tag 'courierId' se encontra vazia no Json e o pedido é do tipo de envio LOJA ENTREGA.")
							End if
						Else
							::lContinua	 := .F.
							::cNewStatus := "P"
							aAdd(::aMsgErro, "Não possivel identificar informações do transportador. A Tag 'deliveryIds' se encontra vazia no Json e o pedido é do tipo de envio LOJA ENTREGA.")
						End if
					Else
						::lContinua	 := .F.
						::cNewStatus := "P"
						aAdd(::aMsgErro, "Não possivel identificar informações do transportador. A Tag 'deliveryIds' não foi encontrada no Json e o pedido é do tipo de envio LOJA ENTREGA.")
					Endif

				Case cDelivery == "PICKUP-IN-POINT" // RETIRADA NA LOJA
					::cTipoExpedicao := "2"
				EndCase
			Else
				::lContinua	 := .F.
				::cNewStatus := "P"
				aAdd(::aMsgErro, "Não possivel identificar informações do tipo de entrega. Tag 'deliveryChannel' não encontrada no Json.")
			End if
		Else
			::lContinua	 := .F.
			::cNewStatus := "P"
			aAdd(::aMsgErro, "Não possivel identificar informações do tipo de entrega. Tag 'logisticsInfo' se encontra vazia no Json.")
		Endif

	Case Alltrim(::cApi) == "CWS"

		cAPI := PadR(::cAPI,TamSx3('VT6_API')[1])

		If oPedido:hasProperty("deliveries") .and. Len(oPedido["deliveries"]) > 0

			If oPedido["deliveries"][1]:hasProperty("freight")

				// Recupera o Tipo de Entrega
				cDelivery := oPedido["deliveries"][1]["freight"]["type"]

				Do Case

				Case cDelivery $ cCWSEntreg 	// ENTREGA

					::cTipoExpedicao := "1"

					If oPedido["deliveries"][1]:hasProperty("ownCarrierCnpj")
						cIdTransp := oPedido["deliveries"][1]['ownCarrierCnpj']
					Else
						::lContinua	 := .F.
						::cNewStatus := "P"
						aAdd(::aMsgErro, "Não possível identificar informações do transportador. Tag 'deliveries-ownCarrierCnpj' não encontrada no Json.")
					End if

				Case cDelivery $ cCWSRetira // RETIRADA NA LOJA

					cIdTransp := SuperGetMv("VT_CWSTRAN", .F., "RETIRA")
					::cTipoExpedicao := "2"
				EndCase
			Else
				::lContinua	 := .F.
				::cNewStatus := "P"
				aAdd(::aMsgErro, "Não possível identificar informações do tipo de entrega. Tag 'deliveries-freight' não encontrada no Json.")
			Endif

		Else
			::lContinua	 := .F.
			::cNewStatus := "P"
			aAdd(::aMsgErro, "Não possível identificar informações de transporte. Tag 'deliveries' não encontrada no Json.")
		End if
	EndCase

	//Compatibiliza o tamanho do campo
	cIdTransp := Upper(PadR(cIdTransp, TamSx3('VT6_IDWEB')[1]))

	//Retira acentuação do campo
	cIdTransp := FWNoAccent(cIdTransp)

	// Localiza o codigo da transportadora no ERP
	VT6->(dbSetOrder(1))
	If VT6->(dbSeek(xFilial("VT6") + cAPI + cIdTransp))
		::cTransp := VT6->VT6_TRANSP
	EndIf

	// Para modalidade do frete ME2, utiliza sempre a transportadora do parametro VT_ME2TRAN
	If Alltrim(VT1->VT1_MODFRE) == "ME2" .AND. !Empty(cTranspME2)
		::cTransp	:= cTranspME2
		::lContinua	:= .T.
	EndIf

	// Blindagem Nuvemshop: Se nao localizou transportadora valida, forca VT_ME2TRAN padrao Fortbras
	If AllTrim(::cAPI) == "NUVEMSHOP"
		If Empty(::cTransp) .Or. !SA4->(dbSeek(xFilial("SA4") + ::cTransp))
			::cTransp := SuperGetMv("MV_YTRANPNUV", .F., SuperGetMv("VT_ME2TRAN", .F., "000091"))
		EndIf
	EndIf

	SA4->(dbSetOrder(1))
	If !SA4->(dbSeek(xFilial("SA4")+::cTransp))
		::lContinua	 := .F.
		::cNewStatus := "P"
		aAdd(::aMsgErro, "A transportadora: "+Alltrim(::cTransp)+" do de/para não foi possivel localizar em nosso cadastro. Favor verificar a VT6 e o parametro VT_ME2TRAN")
	EndIf

	// Verifica se localizou a transportadora para pedido com o tipo entrega
	If ::cTipoExpedicao == "1" .AND. Empty(::cTransp) .and. ::lContinua

		::lContinua	 := .F.
		::cNewStatus := "P"
		aAdd(::aMsgErro, "A transportadora: "+Alltrim(cIdTransp)+" não existe no cadastro Transportadora X WEB para API - " + cAPI + " na Empresa:"+cEmpAnt+"\"+cFilAnt+"!")
	EndIf

Return

Method StartModFrete() Class ECPEDIDO

	Local aAreaVT6 := VT6->(GetArea())

	VT6->(dbSetOrder(2)) //VT6_FILIAL, VT6_API, VT6_TRANSP, VT6_IDWEB, R_E_C_N_O_, D_E_L_E_T_
	If !Empty(::cTransp)

		If VT6->(Dbseek(xFilial("VT6") + ::cAPI + ::cTransp))

			If !Empty(VT6->VT6_MODFRE)
				::cModalidadeFrete := VT6->VT6_MODFRE
			End if
		End if
	End if

	RestArea(aAreaVT6)

Return()


Method UpdVT1() Class ECPEDIDO

	Local cObsErro	:= ""
	Local nX        := 0

	If Len(::aMsgErro) > 0

		For nX:= 1 to Len(::aMsgErro)
			//Coloquei desta forma para não gerar o enter se a Obsertção estiver vazia
			//para não impactar no comando "Empty"
			If !Empty(cObsErro)
				cObsErro += CHR(13)+CHR(10)
			EndIf

			cObsErro += AllTrim(::aMsgErro[nX]) += CHR(13)+CHR(10)

		Next nX

		VT1->VT1_OBS	:= SubStr(cObsErro,1,TamSx3("VT1_OBS")[1])
		//retirado o status 5 para tentar enviar os dados para a Transportadora sempre
		If VT1->VT1_STATUS <> "P" .And. VT1->VT1_STATUS <> '5' .AND. ! Empty(VT1->VT1_OBS)
			VT1->VT1_STATAN	:= VT1->VT1_STATUS
			VT1->VT1_STATUS	:= "P"
		EndIf

		::aMsgErro := {}

	ElseIf ! Empty( ::cNewStatus )//processou o pedido com sucesso
		VT1->VT1_OBS    := 'O pedido do cliente foi gerado Status "'+ ::cNewStatus +'"'

		If ::cNewStatus == 'P'
			VT1->VT1_STATAN := VT1->VT1_STATUS
		EndIf

		VT1->VT1_STATUS := ::cNewStatus
		VT1->VT1_NUMPED := ::cNumPedido
		VT1->VT1_CODCLI := ::cCodCliente
		VT1->VT1_LOJCLI := ::cLojaCliente
		VT1->VT1_MUN    := ::cMunicipio
		VT1->VT1_CODSA3	:= ::cCodSA3
		VT1->VT1_TPENTR := ::cTipoExpedicao
		VT1->VT1_CFRETE := ::nVlrCustoFrete
		VT1->VT1_IDCOTA := ::cIdCotacao

	Else
		VT1->VT1_OBS := "Em Processamento - "+dtoc(dDatabase)+" as "+Time()

	EndIf

	VT1->VT1_MODFRE := IIf(Empty(::cModalidadeFrete), VT1->VT1_MODFRE, ::cModalidadeFrete)
	VT1->VT1_DATAUL := dDataBase
	VT1->VT1_HORAUL := Time()

Return()


Method SetVT1(cOrderId, cAPI, cSequence) Class ECPEDIDO

	Local lRet 		  := .T.

	Default cOrderId  := ::cOrderId
	Default cAPI 	  := ::cApi
	Default cSequence := ::cSequence

	::cOrderID 	:= PADR(cOrderID, TamSX3("VT1_ORDID")[1])
	::cAPI 		:= PADR(cAPI, TamSX3("VT1_API")[1])
	::cSequence	:= PADR(cSequence, TamSX3("VT1_SEQUEN")[1])

	VT1->(dbSetOrder(1))
	If (lRet := VT1->(dbSeek(xFilial("VT1") + ::cOrderID + ::cAPI)))

		::cAPI 		:= VT1->VT1_API
		::cOrderID 	:= VT1->VT1_ORDID
		::cSequence := VT1->VT1_SEQUEN
		::cNumPedido := VT1->VT1_NUMPED
		::cCodCliente := VT1->VT1_CODCLI
		::cLojaCliente := VT1->VT1_LOJCLI
		::cIdCarrinho := VT1->VT1_IDCART
		::nValFrete := VT1->VT1_FRETE
		::cModalidadeFrete := VT1->VT1_MODFRE
		::cTipoExpedicao := VT1->VT1_TPENTR
		::cJson := VT1->VT1_JSON
		::dDtPagamento := VT1->VT1_DATAPG
		::cHrPagamento := VT1->VT1_HORAPG
		::cStatus := VT1->VT1_STATUS
		::dDtWeb := VT1->VT1_DTWEB
		::cHoraWeb := VT1->VT1_HRWEB
		::dDtIntHUB := VT1->VT1_DTCHUB
		::cHrIntHUB := VT1->VT1_HRCHUB
		::dDtPGHUB := VT1->VT1_DTPHUB
		::cHrPGHUB := VT1->VT1_HRPHUB
		::dDtPGERP := VT1->VT1_DTPGRE
		::cHrPGERP := VT1->VT1_HRPGRE
		::cCODVTR := VT1->VT1_CODVTR
		::cCODVTQ := VT1->VT1_CODVTQ
		::cCODVT8 := VT1->VT1_CODVT8
		::cCODVTP := VT1->VT1_CODVTP
		::cCODSA3 := VT1->VT1_CODSA3
		::cCodTipPed := VT1->VT1_TIPPED
		::cCODA1U := VT1->VT1_CODA1U
		::cCODVTN := VT1->VT1_CODVTN
		::nVlrCustoFrete := VT1->VT1_CFRETE
		::cIdCotacao := VT1->VT1_IDCOTA

	EndIf

Return(lRet)


/*/{Protheus.doc} GetModFrete
Busca a modalidade do frete no mercado livre
@author henrique
@since 25/08/2021
@version 1.0
@example
(examples)
@see (links_or_references)
/*/Method GetModFrete( oPedido ) Class ECPEDIDO
	Local oBjMEnvios := Nil
	Local cNomeAdquir:= ''

	If Type('oPedido:DadosPgto[1]:cNomeAdquir') == 'C'
		cNomeAdquir := UPPER(oPedido:DadosPgto[1]:cNomeAdquir)
	EndIf

	If Alltrim(::cAPI) == 'B2C-RESULT' .OR. Alltrim(::cAPI) == "00K"

		If UPPER('mercadopago') $ cNomeAdquir .and. ! Empty(::cIdCarrinho)

			oBjMEnvios 	:= MEnviosRastreamento():New()

			oBjMEnvios:cSequen := ::cSequence
			oBjMEnvios:cIdCart := ::cIdCarrinho

			aRetME2 := oBjMEnvios:GetAtuRastro(.F.)
			aAdd(::aMsgErro, If(aRetME2[1], VT1->VT1_OBS, aRetME2[2]))

			::cNewStatus        := If(aRetME2[1], VT1->VT1_STATUS, "P")
			::cModalidadeFrete	:= oBjMEnvios:cModFrete

			If ::cNewStatus == 'P'
				::lContinua := .F.
			Endif

			FreeObj(oBjMEnvios)

		EndIf

	EndIf

Return

Method GetDataEntrega(oPedjSON) Class ECPEDIDO

	Local cDataVTEX		:= ""
	Local cHoraVTEX		:= ""
	Local cHoraLocal	:= ""
	Local aDtEmissao	:= {}
	Local dDataLocal	:= CTOD("")
	Local lDtVTEX		:= SuperGetMv("MV_YDTVTEX",.f.,.t.)

	Private oPedShipp	:= Nil

	// Conteudo padrão caso nao identifique pela API
	::dDataEntrega		:= dDataBase + 10

	If Alltrim(::cAPI) == "B2C-RESULT"

		::dDataEntrega	:= dDataBase + 10

	Elseif  Alltrim(::cAPI) == "ANYMARKET"

		If oPedjSON:hasProperty("shipping") .AND. oPedjSON["shipping"]:hasProperty("promisedShippingTime")

			aDtEmissao := FwDateTimeToLocal(oPedjSON["shipping"]["promisedShippingTime"])
			::dDataEntrega := aDtEmissao[1]
		End if

	Elseif  Alltrim(::cAPI) == "COCKPIT"

		If oPedjSON:hasProperty("shipping") .AND. oPedjSON["shipping"]:hasProperty("promisedShippingTime")

			aDtEmissao := FwDateTimeToLocal(oPedjSON["shipping"]["promisedShippingTime"])
			::dDataEntrega := aDtEmissao[1]
		End if

	Elseif  Alltrim(::cAPI) == "00K"

		If AttIsMemberOf(oPedjSON,"shipping")  .and. ValType(oPedjSON:shipping) <> "U"

			if  AttIsMemberOf(oPedjSON:shipping,"estimatedDate") .and. ValType(oPedjSON:shipping:estimatedDate) <> "U"
				aDtEmissao := FwDateTimeToLocal(oPedjSON:shipping:estimatedDate)
				::dDataEntrega := aDtEmissao[1]
			End if

		End if

	ElseIf Alltrim(::cAPI) == "LINKAPI"

		If lDtVTEX .and. AttIsMemberOf(oPedjSON,"shippingData")
			If AttIsMemberOf(oPedjSON:shippingData,"LOGISTICSINFO")
				If ValType(oPedjSON:shippingData:LogisticsInfo) == "A"

					// LOCALIZA A PREVISAO DE ENTREGA
					If AttIsMemberOf(oPedjSON:shippingData:LogisticsInfo[1],"shippingEstimateDate")
						If ValType(oPedjSON:shippingData:LogisticsInfo[1]:shippingEstimateDate) == "C"
							cDataVTEX  := oPedjSON:shippingData:LogisticsInfo[1]:shippingEstimateDate
							cHoraVTEX  := SubStr(cDataVTEX,12,2)+":"+SubStr(cDataVTEX,15,2)+":"+SubStr(cDataVTEX,18,2)
							cDataVTEX  := STOD(SubStr(cDataVTEX,1,4)+SubStr(cDataVTEX,6,2)+SubStr(cDataVTEX,9,2))
							cHoraLocal := UTCToLocal(DTOS(cDataVTEX), cHoraVTEX )[2]
							dDataLocal := STOD(UTCToLocal(DTOS(cDataVTEX), cHoraVTEX )[1])
							::dDataEntrega := dDataLocal
						End if
					End if
				End If
			End if
		End if
	EndIf

Return ::dDataEntrega

//===================================================================
//

	Class ECPEDITENS

		Data cCodProd
		Data nQuantidade
		Data nValUnit
		Data nValTotal
		Data dDtEntrega
		Data cCodWeb
		Data cCodSku
		Data nVlrOriginal
		Data nPesoWeb
		Data nPesoProtheus
		Data cFabricante
		Data cCodERPOrig
		Data nQtdERPOrig
		Data cSkuERPOrig
		Data nPrecoTab

		Method New() CONSTRUCTOR
		Method CreateSB2()
		Method GetPreco()

	EndCLass

//===================================================================

Method New() Class ECPEDITENS

	::cCodProd      := ""
	::nQuantidade   := 0
	::nValUnit      := 0
	::nValTotal     := 0
	::dDtEntrega    := CTOD("")
	::cCodWeb       := ""
	::cCodSku       := ""
	::nVlrOriginal  := 0
	::nPesoWeb      := 0
	::cFabricante   := ''
	::nPesoProtheus := 0
	::nPrecoTab		:= 0
	::cCodERPOrig	:= ""
	::nQtdERPOrig	:= 0
	::cSkuERPOrig	:= ""

Return

//===================================================================

Method CreateSB2() Class ECPEDITENS
	Local aArea     := GetArea()
	Local aAreaSB2  := SB2->(GetArea())
	Local cIdProd	:= ""

	//Acrescenta informações ao sb2
	SB2->(dbSetOrder(1))

	cIdProd := AvKey(::cCodProd,"B2_COD")

	If !SB2->(dbSeek(xFilial("SB2")+cIdProd +"01"))
		CriaSB2(cIdProd ,"01") //Função padrão Protheus
	EndIf

	RestArea(aAreaSB2)
	RestArea(aArea)

Return

//===================================================================

Method GetPreco(oCliente) Class ECPEDITENS

	Local oPreco

	If ! oCliente:lClienteWEB
		/*Instancia o Objeto da Classe de Regras de Preco*/
		oPreco:= TpwPreco():New(::cCodProd,oCliente:cCliente,oCliente:cLoja,"")
		::nValUnit      := oPreco:nPreco
		::nVlrOriginal  := oPreco:nPreco
		::nValTotal     := oPreco:nPreco * ::nQuantidade
		FreeObj(oPreco)
	EndIf

Return

Method GetCondicao(oPedido) Class ECPEDIDO

	Do Case
	Case Alltrim(::cApi) == "CWS"

		If oPedido:hasProperty("payments") .and. Len(oPedido["payments"]) > 0
			If oPedido["payments"][1]:hasProperty("customPayment") .and. Len(oPedido["payments"][1]["customPayment"]) > 0
				If oPedido["payments"][1]['customPayment'][1]:hasProperty("termInternalCode")
					::cCodPag := oPedido["payments"][1]["customPayment"][1]['termInternalCode']
				Else
					::lContinua	 := .F.
					::cNewStatus := "P"
					aAdd(::aMsgErro, "Não possivel identificar informações do pagamento. A Tag 'termInternalCode' não foi localizada no json.")
				Endif
			Else
				::lContinua	 := .F.
				::cNewStatus := "P"
				aAdd(::aMsgErro, "Não possivel identificar informações do pagamento. A Tag 'customPayment' não foi localizada no json.")
			Endif
		Else
			::lContinua	 := .F.
			::cNewStatus := "P"
			aAdd(::aMsgErro, "Não possivel identificar informações do pagamento. A Tag 'payments' não foi localizada no json.")
		Endif
	EndCase

	//Compatibiliza o tamanho do campo
	::cCodPag := Upper(PadR(::cCodPag, TamSx3('E4_CODIGO')[1]))

	If ::lContinua

		SE4->(dbSetOrder(1))
		If !SE4->(dbSeek(xFilial("SE4")+::cCodPag))
			::lContinua	 := .F.
			::cNewStatus := "P"
			aAdd(::aMsgErro, "Não foi possível localizar a condição de pagamento junto ao ERP com o código WEB (" + ::cCodPag + ")")
		EndIf
	End if
Return()


Method GetOperador(cCodSA3) Class ECPEDIDO

	Local cSQL := ""
	Local cQry := GetNextAlias()

	Default cCodSA3 := ::cCodSA3

	cSQL := " SELECT TOP 1 U7_CODUSU,U7_COD "
	cSQL += " FROM " + RetSQLName("SU7")
	cSQL += " WHERE U7_FILIAL = " + ValToSQL(FWxFilial("SU7"))
	cSQL += " AND U7_CODVEN = " + ValToSQL(::cCodSA3)
	cSQL += " AND D_E_L_E_T_ = '' "

	TcQuery cSQL New Alias (cQry)

	If !Empty((cQry)->U7_COD)

		::cOperador := (cQry)->U7_COD
		__cUserID 	:= (cQry)->U7_CODUSU
	EndIf

	If Empty(::cOperador)
		::lContinua := .F.
		::cNewStatus := "P"
		aAdd(::aMsgErro, "Não foi possível localizar um operador válido para este atendimento atrelado ao vendedor (" + Alltrim(::cCodSA3) + ")")
	EndIf

	(cQry)->(DBCloseArea())

Return ::cOperador

Method StartSUACanc() Class ECPEDIDO

	Local lRet 		:= .T.
	Local aHeader 	:= {}
	Local aItem 	:= {}
	Local aItems 	:= {}
	Local cUserAux 	:= __cUserID

	Private lMsErroAuto := .F.

	If ::SetVT1()

		DbSelectArea("SUA")
		SUA->(DbSetOrder(1))
		If SUA->(DbSeek(FWxFilial("SUA") + VT1->VT1_NUMPED))

			// Verifica se o atendimento possui pedido de venda
			If !Empty(SUA->UA_NUMSC5)

				// Cancela o pedido de venda
				If !::StartSC5Canc()

					aAdd(::aMsgErro, "Erro ao estornar pedido de venda associado ao atentimento.")
				EndIf
			EndIf

			If ::lContinua

				// Estorna Reservas
				If U_TK271EstR()

					// Muda para o usuario que gerou Atendimento no Call Center
					SU7->(DbSetOrder(1))
					If SU7->(DbSeek(FWxFilial("SU7") + SUA->UA_OPERADO))
						__cUserID := SU7->U7_CODUSU
					EndIf

					aAdd(aHeader, {"UA_NUM"		, SUA->UA_NUM	 , Nil})
					aAdd(aHeader, {"UA_CLIENTE"	, SUA->UA_CLIENTE, Nil})
					aAdd(aHeader, {"UA_LOJA"	, SUA->UA_LOJA	 , Nil})
					aAdd(aHeader, {"UA_CANC"	, "S"			 , Nil})
					aAdd(aHeader, {"UA_STATUS"	, "CAN"		 	 , Nil})

					DbSelectArea("SUB")
					SUB->(DbSetOrder(1) )
					If SUB->(DbSeek(FWxFilial("SUB") + SUA->UA_NUM))

						While !SUB->(Eof()) .And. SUB->UB_FILIAL == xFilial("SUB") .And. SUB->UB_NUM == SUA->UA_NUM

							aItem := {}

							aAdd(aItem, {"LINPOS"	 , "UB_ITEM"		, SUB->UB_ITEM})
							aAdd(aItem, {"AUTDELETA" , "N"				, Nil})
							aAdd(aItem, {"UB_PRODUTO", SUB->UB_PRODUTO	, Nil})
							aAdd(aItem, {"UB_QUANT"	 , SUB->UB_QUANT	, Nil})
							aAdd(aItem, {"UB_VRUNIT" , SUB->UB_VRUNIT	, Nil})
							aAdd(aItem, {"UB_TES"	 , SUB->UB_TES		, Nil})

							aAdd(aItems, aItem)

							SUB->(DbSkip())

						EndDo()

						MsExecAuto({|a, b, c, d| TMKA271(a, b, c, d)}, aHeader, aItems, 4, "2") // 4=Alteracao; "2"=TeleVendas

						If !lMsErroAuto

							cMensagem := "Atendimento cancelado automaticamente - StartSUACanc()"

							RecLock("SUA", .F.)

							If Empty(SUA->UA_CODCANC)

								MSMM(, TamSx3("UA_OBSCANC")[1],, cMensagem, 1,,, "SUA", "UA_CODCANC")
							EndIf

							SUA->(MsUnLock())

						Else

							cLogTxt := MemoRead(NomeAutoLog())
							FErase(NomeAutoLog())
							aAdd(::aMsgErro, cLogTxt)
							lRet := .F.
						EndIf
					Else
						lRet := .F.
					EndIf
				Else
					aAdd(::aMsgErro, "Erro ao estornar reserva associada ao atentimento.")
					lRet := .F.
				EndIf
			EndIf
		Else
			lRet := .F.
		EndIf
	Else
		lRet := .F.
	EndIf

	__cUserID := cUserAux

Return(lRet)


Method CreateReserva() Class ECPEDIDO

	If ::SetVT1()

		If VT1->(SimpleLock())

			If AllTrim(VT1->VT1_TIPPED) == 'SUA'

				::CreateResSUA()
			EndIF

			::UpdVT1()

			VT1->(MsUnlock())
		EndIf
	EndIf
Return

Method CreateResSUA() Class ECPEDIDO

	Local cLogError	:= ""
	Local cNumRes	:= ""
	Local cCodProd	:= ""
	Local cDesProd	:= ""
	Local cMsg		:= ""
	Local aErro		:= {}
	Local lRet 		:= .F.
	Local cAliasSUB	:= GetNextAlias()

	SUA->(DbsetOrder(1))
	If SUA->(Dbseek(FWxFilial("SUA") + VT1->VT1_NUMPED))

		If !Empty(SUA->UA_YNUMRES) .OR. Alltrim(SUA->UA_OPER) == "1"

			::lContinua  := .T.
			::cNewStatus := "1"

		ElseIf Alltrim(SUA->UA_OPER) == "3" .And. Empty(SUA->UA_CANC)

			INCLUI := .T.
			ALTERA := .F.

			oViewSC0 := FwLoadView("MATA430")
			oModelSC0:= oViewSC0:GetModel()
			oModelSC0:SetOperation(MODEL_OPERATION_INSERT)
			oModelSC0:Activate()

			// Recupera o codigo da reserva.
			cNumRes := oModelSC0:GetModel("MASTER"):GetValue("C0_NUM")

			SUB->(DbSetOrder(1))
			If SUB->(DbSeek(xFilial("SUB") + SUA->(UA_NUM)))

				oModelSC0:SetValue('MASTER','C0_TIPO', "VD")
				oModelSC0:SetValue('MASTER','C0_DOCRES', SUA->UA_VEND)

				cAliasSUB := GetNextAlias()

				BeginSQL Alias cAliasSUB
					SELECT UB_PRODUTO, SUM(UB_QUANT) AS UB_QUANT, UB_LOCAL 
					FROM %Table:SUB% SUB
					WHERE SUB.UB_FILIAL = %Exp:xFilial("SUB")%
					AND SUB.UB_NUM = %Exp:SUA->UA_NUM%
					AND SUB.UB_QUANT > 0
					AND SUB.D_E_L_E_T_ = ''
					GROUP BY UB_PRODUTO, UB_LOCAL
				EndSql

				While (cAliasSUB)->(!EOF())

					// Verifica se existe dados anteriores
					If !oModelSC0:GetModel('SC0GRID'):IsEmpty()
						oModelSC0:GetModel('SC0GRID'):AddLine()
					EndIf

					oModelSC0:SetValue('SC0GRID' , 'C0_PRODUTO', Alltrim((cAliasSUB)->UB_PRODUTO))
					oModelSC0:LoadValue('SC0GRID', 'C0_LOCAL'  , Alltrim((cAliasSUB)->UB_LOCAL))

					lRet := oModelSC0:SetValue('SC0GRID', 'C0_QUANT', (cAliasSUB)->UB_QUANT)

					oModelSC0:LoadValue('SC0GRID','C0_VALIDA' , SUA->UA_DTLIM)
					oModelSC0:LoadValue('SC0GRID','C0_YCODCLI', SUA->UA_CLIENTE)
					oModelSC0:LoadValue('SC0GRID','C0_YLOJA'  , SUA->UA_LOJA)

					If !lRet

						oModelGRID := oModelSC0:GetModel('SC0GRID')
						cCodProd := oModelGRID:GetValue("C0_PRODUTO")
						cDesProd := Alltrim(POSICIONE("SB1",1,xFilial("SB1") + cCodProd, "B1_DESC"))
						aErro := oModelSC0:GetErrorMessage()

						cMsg += "<b>Produto: </b>" + Alltrim(cCodProd) + "</b><br />"
						cMsg += "<b>Descrição: </b>" + cDesProd + "<br />"
						cMsg += "<b>Mensagem do erro: </b>" + Alltrim(cValToChar(aErro[06])) + "<br />"
						cMsg += "<b>Mensagem da solução: </b>" + Alltrim(cValToChar(aErro[07])) + "<br />"
						cMsg += "<b>Qtd requisitada: </b>" + Alltrim(cValToChar(aErro[08])) + "<br /><br />"
						cMsg := Alltrim(cMsg)
					EndIf

					(cAliasSUB)->(DbSkip())
				EndDo()

				(cAliasSUB)->(DbCLoseArea())

				If Empty(cMsg)
					If oModelSC0:VldData()
						If oModelSC0:CommitData()
							lRet := .T.
						Else
							lRet := .F.
							AEval(oModelSC0:GetErrorMessage(), {|x| cLogError += cValToChar(x) + CRLF})
						EndIf
					Else
						AEval(oModelSC0:GetErrorMessage(), {|x| cLogError += cValToChar(x) + CRLF})
					EndIf

					oModelSC0:DeActivate()
				EndIf
			EndIf

			If lRet

				::lContinua 	:= .T.
				::cNewStatus 	:= "1"

				Reclock("SUA",.F.)
				SUA->UA_YNUMRES := cNumRes
				SUA->(MsUnlock())
			Else
				::lContinua 	:= .F.
				::cNewStatus 	:= "P"
				aAdd(::aMsgErro, "Erro ao incluir reserva do atendimento call center - " + "Empresa:" + cEmpant + " FILIAL:" + cFilAnt + CRLF)
				aAdd(::aMsgErro, cLogError)
			EndIF
		EndIf
	End if
Return()
