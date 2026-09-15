#INCLUDE "TOTVS.CH"

/*/{Protheus.doc} ECJOBNUV
JOB de execucao continua em segundo plano para sincronizacao de Catalogo,
Precos e Estoques entre o TOTVS Protheus e a plataforma Nuvemshop.
Segue o padrao arquitetural dos servicos de e-commerce da empresa.

@param cEmp, character, Empresa de execucao (ex: "01")
@param cFil, character, Filial de execucao (ex: "03150001")
@param cUsaFil, character, Flag "S"/"N" se processa apenas a filial isolada

@author Claudio Guidi
@since 05/09/2026
@version 1.0
@project Integracao Nuvemshop - TOTVS Protheus
/*/
User Function ECJOBNUV(cEmp, cFil, cUsaFil)
	Local oSched     := Nil
	Local nTempo     := 0
	Local nMaxMemory := 0
	Local cLockKey   := ""

	Default cEmp    := "01"
	Default cFil    := "03150001"
	Default cUsaFil := "N"

	// Inicializa o ambiente Protheus
	oSched := SchedAcesso():New()
	oSched:cEmp := cEmp
	oSched:cFil := cFil
	oSched:IniciaAmb()

	// Parametros de governanca: intervalo de sleep e teto de consumo de memoria
	nTempo     := 1000 * SuperGetMV("JOB_NUVSLEEP", .F., 60) // Intervalo padrao: 60 segundos
	nMaxMemory := SuperGetMV("JOB_MAXMEM", .F., 3)           // Teto maximo de reciclagem: 3 GB
	cLockKey   := "ECJOBNUV" + cEmp + cFil

	ConOut("[ECJOBNUV] Servico de integracao de produtos Nuvemshop iniciado na Empresa: " + cEmp + " Filial: " + cFil)

	While !KillApp()
		// Mutex para garantir que apenas uma instancia do JOB rode por filial
		If !LockByName(cLockKey, .T., .T., .T.)
			ConOut("[ECJOBNUV] Outra instancia em execucao para a chave: " + cLockKey + ". Aguardando proximo ciclo...")
		Else
			// Executa o processamento da fila de produtos
			ECJOBNUV1(cUsaFil, cFil)
			UnLockByName(cLockKey, .T., .T., .T.)
		EndIf

		// Monitoramento e reciclagem automatica de memoria
		If (oSched:MemoryInUse("ECJOBNUV") / 1024) > nMaxMemory
			ConOut("[ECJOBNUV][RECICLAGEM] Consumo de memoria superior a " + cValToChar(nMaxMemory) + " GB. Finalizando processo para reinicio limpo.")
			KillApp(.T.)
		EndIf

		// Queda/Reinicio diario na virada de data base
		If dDataBase <> Date()
			ConOut("[ECJOBNUV][VIRADA DATA] Data base alterada. Reiniciando servico para sincronizar com a nova data...")
			KillApp(.T.)
		EndIf

		Sleep(nTempo)
	EndDo

	FreeObj(oSched)
	ConOut("[ECJOBNUV] Servico finalizado.")
Return

/*/{Protheus.doc} ECJOBNUV1
Worker interno acionado pelo loop principal.
/*/
Static Function ECJOBNUV1(cUsaFil, cFil)
	Local oNuvProd := NuvemProduto():New()
	Local lSyncCat := SuperGetMV("JOB_NUVCAT", .F., .F.) // Habilita carga total/incremental B2C periodica
	Local cFilEcom := AllTrim(cValToChar(SuperGetMV("MV_NUVFIL", .F., "03150001")))

	Default cFil := cFilEcom

	// 1. Dispara a sincronizacao da fila VTF (precos e estoques em tempo real)
	oNuvProd:UpdtAtuWeb()

	// 2. Se configurado JOB_NUVCAT = .T., executa a sincronizacao de precos/estoques B2C (Match VTEX)
	If lSyncCat
		ConOut("[ECJOBNUV] Executando sincronizacao de estoque e preco B2C agendada na filial " + cFil + "...")
		oNuvProd:SyncAllStockPriceB2C(cFil)
	EndIf

	FreeObj(oNuvProd)
Return .T.
