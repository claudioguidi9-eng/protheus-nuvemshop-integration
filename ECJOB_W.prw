#INCLUDE "PROTHEUS.CH"
#INCLUDE "TBICONN.CH"
#Include "aarray.ch"

/*/{Protheus.doc} ECJOB_W
Obtem todos os pedidos WEb para cadastrar no Protheus com satus vazio
@author henrique/leandro/mauricio
@since 23/08/2021
@version 1.0
@example
(examples)
@see (links_or_references)
/*/
User Function ECJOB_W(cEmp,cFil,cUsaFil,cAPI)

	Local oSched 	:= SchedAcesso():New()
	Local nTempo    := 1000
	Local nMaxMemory:= 0
	Local cEmpresa	:= ""
	Local cCodEmp	:= ""

	Default cEmp	:= "01"
	Default cFil    := "03150001"
	Default cUsaFil := "N"
	Default cAPI 	:= "ANYMARKET"

	oSched:cEmp 	:= cEmp
	oSched:cFil 	:= cFil

	oSched:IniciaAmb()

	// Recupera o nome da empresa
	cEmpresa := FWEmpName(cEmp)

	// Forma o codigo da empresa
	cCodEmp := cEmp + "-XX"

	// Verifica se acao e na filial isolada
	If cUsaFil == "S"
		cEmpresa := FWFilialName(cEmp,cFil ,2)
		cCodEmp := cEmp + "-" + cFil
	End if

	cEmpresa := PADR(Alltrim(cEmpresa),40," ")

	nTempo *= SuperGetMV("JOB_WSLEEP",.F.,120)
	nMaxMemory := SuperGetMV("JOB_MAXMEM",.F.,3)

	While !KillApp()

		// Lock isolado por empresa, filial e API (evita que AnyMarket, LinkApi, Cockpit etc. bloqueiem uns aos outros)
		If !LockByName("ECJOB_W" + cEmp + cFil + AllTrim(Upper(cAPI)), .T., .T., .T.)
			Conout("Rotina ECJOB_W (" + AllTrim(cAPI) + ") esta sendo executada por outra instancia.")
		Else

			FWMonitorMsg("JOB | ECJOB_W | " + Alltrim(cAPI) + " | " + cCodEmp +  ' | ' + cEmpresa +  "| Processing")

			Do Case

			Case Alltrim(UPPER(cAPI)) == "ANYMARKET"
				ECJOB_W1()

			Case Alltrim(UPPER(cAPI)) == "LINKAPI"
				ECJOB_W2()

			Case Alltrim(UPPER(cAPI)) == "CWS"
				ECJOB_W3()

			Case Alltrim(UPPER(cAPI)) == "COCKPIT"
				ECJOB_W4()

			Case Alltrim(UPPER(cAPI)) == "NUVEMSHOP"
				ECJOB_W5()

			EndCase

			FWMonitorMsg("JOB | ECJOB_W | " + Alltrim(cAPI) + " | " + cCodEmp +  ' | ' + cEmpresa +  "| Stand By")
			UnLockByName("ECJOB_W" + cEmp + cFil + AllTrim(Upper(cAPI)), .T., .T., .T.)
		EndIf

		// Tratamento para caso a rotina ultrapasse 4 gb de memoria em uso, finaliza o processo
		If oSched:MemoryInUse("ECJOB_W") / 1024 > nMaxMemory
			Exit
		EndIf

		Sleep(nTempo)//espera alguns para executar novamente

		// Apos as 00:00h forca a queda da thread para iniciar novamente com a database atualizada
		If dDataBase <> Date()
			KillApp(.T.)
		EndIf

	EndDo

	oSched:FinalAmb()
	FreeObj(oSched)

Return

Static Function ECJOB_W1()

	Local oAnyPedido := AnyPedido():New()

	oAnyPedido:CreatePedWeb()

Return

Static Function ECJOB_W2()

	Local oVtexPedido := VTEXOrder():New()

	oVtexPedido:CreatePedWeb()

Return

/*/{Protheus.doc} ECJOB_W3
Tratamento para gravar pedidos CWS
@author henrique/leandro/mauricio
@since 11/07/2025
/*/
Static Function ECJOB_W3()

	Local oCWSPedido	:= nIL

	oCWSPedido	:= CWSPedido():New()

	oCWSPedido:CreatePedWeb()

Return

Static Function ECJOB_W4()

	Local oCockPedido := CockPedido():New()

	oCockPedido:CreatePedWeb()

Return

/*/{Protheus.doc} ECJOB_W5
Tratamento para captura e gravacao de pedidos da Nuvemshop na esteira VT1
@author Claudio Guidi
@since 29/09/2026
/*/
Static Function ECJOB_W5()

	Local oNuvPedido := NuvemPedido():New()

	oNuvPedido:CreatePedWeb()

Return

