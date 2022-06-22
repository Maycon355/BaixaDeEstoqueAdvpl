#include 'protheus.ch'
#include 'parmtype.ch'

/*/{Protheus.doc} G0108656
//TODO Descrição auto-gerada.

@since 21/02/2020
@version 1.0
@type function
/*/
User Function MNTMOVTM1(cCodCF)

	Local cCodTM := cCodCF

	If Substr(cCodCF,1,2) == 'RE'
		cCodTM := "501"
	ElseIf Substr(cCodCF,1,2) == 'DE' .Or. Substr(cCodCF,1,2) == 'PR'
		cCodTM := "499"
	EndIf

Return cCodTM


User Function MntMovEst1(cCod, cLocal, cProd, nQuant, dData, cDocEst, cFilMov, cCCusto, lTemEstorno,;
		cNumeroSeq, cOrdem, cBemMov, cFilBemMov, cOP, cItemCTA, aRastro, cCodLocMov, lRetArray, nCustoMov)

	Local aRetArray := { .T., "" }
	Local lSbf := .F.
	Local cRet := Space(6)
	Local nOpc := 0
	Local _FilialAnt := cFilAnt //Salva filial corrente
	Local nIndex := IIf(IsInCallStack("MNTA600") .Or. IsInCallStack("MNTA656"), 2, 3)

	Local nTanSBF   := TamSX3("BF_LOCALIZ")[1]
	Local cLocalSbf := ""
	Local cCodTM    := "" // Código numérico do campo D3_TM

	Local cNumSeqD := CriaVar('D3_NUMSEQ')
	Local cLoteCtl := CriaVar('D3_LOTECTL')
	Local cNumLote := CriaVar('D3_NUMLOTE')
	Local cLocaliz := CriaVar('D3_LOCALIZ')
	Local cNumSeri := CriaVar('D3_NUMSERI')
	Local cCodCta  := ""
	Local _aCab1    := {}
    Local _atotitem := {}

	Default nCustoMov   := 0
	Default lTemEstorno := .F.
	Default cNumeroSeq  := " "
	Default cLocal      := ''
	Default aRastro     := {}
	Default cBemMov     := ""
	Default cFilBemMov  := ""
	Default cCodLocMov  := ""
	Default lRetArray   := .F.


	Private lMsErroAuto := .F. //Indica se houve erro ao executar rotina automática
	Private lMSHelpAuto := .T. // para nao mostrar os erro na tela

	cLocal    := IIf( Empty( cLocal ), Padr( GetMv("MV_NGLOCPA"), TamSx3("NNR_CODIGO")[1] ), cLocal )
	cLocalSbf := If(!Empty(cCodLocMov),PADR(Alltrim(cCodLocMov),nTanSBF),"")

	cCodTM := U_MNTMOVTM1(cCod)
    

	// Validacoes
	If lTemEstorno .And. !Empty(cNumeroSeq)
		dbSelectArea("SD3")
		dbSetOrder(04)
		If dbSeek(xFilial("SD3")+cNumeroSeq)
			If SD3->D3_ESTORNO == "S"
				aRetArray[1] := .F.
				aRetArray[2] := STR1452 // 'O estorno da movimentação já foi realizado.'
			EndIf
		EndIf
	EndIf

	If aRetArray[1] .And. nQuant <= 0
		aRetArray[1] := .F.
		aRetArray[2] := STR1453// 'A quantidade para movimentação é inválida.'
	EndIf

	// Gera movimentacao
	If aRetArray[1]

		//garante que __lSX8 seja .F.
		__lSx8 := .F.

		//Troca a filial para a que será gerada a movimentação
		If ValType(cFilMov) == "C"
			If !Empty(cFilMov) .And. Len(cFilMov) == Len(cFilAnt)
				cFilAnt := cFilMov
			EndIf
		EndIf

		//identifica o tipo de operacao (baixa ou estorno)
		If lTemEstorno .And. !Empty(cNumeroSeq)
			nOpc := 5  //estorno
		Else
			nOpc := 3  //baixa
		EndIf

		//posiciONa no cadastro do produto
		dbSelectArea("SB1")
		dbSetOrder(01)
		dbSeek(xFilial('SB1')+cProd)

		If Len(aRastro) <> 0

			cLocal   := aRastro[1]
			cLoteCtl := aRastro[3]
			cNumLote := aRastro[2]
			cLocaliz := aRastro[5]
			cNumSeri := aRastro[4]

		Else // Carrega campos da SBF (saldos por endereco)

			dbSelectArea("SBF")
			If Empty(cLocalSbf)
				dbSetOrder(02)
				lSbf := dbSeek(xFilial("SBF") + cProd + cLocal)
			Else
				dbSetOrder(1)
				lSbf := dbSeek(xFilial("SBF") + cLocal + cLocalSbf  + cProd)
			EndIf

			If lSbf
				cLoteCtl := If(Empty('BF_LOTECTL'), '', SBF->BF_LOTECTL)
				cNumLote := If(Empty('BF_NUMLOTE'), '', SBF->BF_NUMLOTE)
				cLocaliz := If(Empty('BF_LOCALIZ'), '', SBF->BF_LOCALIZ)
				cNumSeri := If(Empty('BF_NUMSERI'), '', SBF->BF_NUMSERI)
			EndIf

		EndIf

		//--------------------------------------------------
		// busca dados do próprio item
		//--------------------------------------------------
		If nOpc == 5 .And. !Empty( cNumeroSeq ) // estorno
			dbSelectArea("SD3")
			dbSetOrder(04)
			If dbSeek(xFilial("SD3")+cNumeroSeq)
				cLocaliz := SD3->D3_LOCALIZ
				cNumSeri := SD3->D3_NUMSERI
			EndIf
		EndIf

		cDocumSD3 := GetSxeNum("SD3","D3_DOC")//NextNumero("SD3",2,"D3_DOC",.T.)
		cDocumSD3 := "C" + Substr(cDocumSD3,2,8) 

		_aCab1 := {{"D3_DOC" ,cDocumSD3, NIL},;
			{"D3_TM" ,cCodTM , NIL},;
			{"D3_CC" ,"        ", NIL},;
			{"D3_EMISSAO" ,dData, NIL}}

		aAutoItens := {{"D3_COD"    , cProd                                         , Nil},;
			{"D3_UM"     , SB1->B1_UM                                    , Nil},;
			{"D3_QUANT"  , nQuant                                        , Nil},;
			{"D3_CF"     , cCod                                          , Nil},;
			{"D3_CONTA"  , SB1->B1_CONTA                                 , Nil},;
			{"D3_LOCAL"  , If(Empty(cLocal), SB1->B1_LOCPAD, cLocal)     , Nil},;
			{"D3_SEGUM"  , SB1->B1_SEGUM,                                , Nil},;
			{"D3_QTSEGUM", CONvUm(SB1->B1_COD,0/*qtdOco*/,0,2)           , Nil},;
			{"D3_GRUPO"  , SB1->B1_GRUPO                                 , Nil},;
			{"D3_TIPO"   , SB1->B1_TIPO                                  , Nil},;
			{"D3_NUMSERI", cNumSeri                                      , Nil},;
			{"D3_CHAVE"  , SubStr(cCod,2,1)+If(cCod $ 'RE4|DE4','9','0') , Nil},;
			{"D3_USUARIO", cUserName                                     , Nil},;
			{"D3_LOCALIZ", cLocaliz                                      , Nil},;
			{"D3_NUMSEQ" , cNumeroSeq                                    , Nil},;
			{"D3_ESTORNO", If(lTemEstorno ,"S"," ")                      , Nil}}




		If cCCusto != Nil
			aAdd(_aCab1, {"D3_CC", cCCusto, Nil})
		EndIf

		If nCustoMov > 0
			aAdd(aAutoItens,{"D3_CUSTO1", nCustoMov, Nil})
		EndIf

		// Código da Ordem.
		If cOrdem != Nil
			aAdd(aAutoItens, {"D3_ORDEM", cOrdem, Nil})
		EndIf

		// Ordem de Produção.
		If cOP != Nil
			aAdd(aAutoItens, {"D3_OP", cOP, Nil})
		EndIf

		//------------------------------------------------
		//Carrega campo D3_ITEMCTA quando for passado bem
		//------------------------------------------------
		If !Empty( cBemMov )
			cCodCta := NGSEEK( "ST9", cBemMov, 1, "T9_ITEMCTA", xFilial( "ST9", cFilBemMov ) )
			If !Empty( cCodCta ) .And. NGIFdbSeek( "CTD", cCodCta, 1 )
				aAdd( aAutoItens, { "D3_ITEMCTA", cCodCta, Nil } )
			EndIf
		Else
			If cItemCTA != Nil
				aAdd(aAutoItens, {"D3_ITEMCTA", cItemCTA, Nil})
			EndIf
		EndIf

		aAdd(aAutoItens, {"INDEX", nIndex, Nil})

		//+---------------------------------------------------------------+
		//| Ponto de Entrada para inclusão e alteração de campos passados |
		//| na geração de Movimentos Internos.                            |
		//+---------------------------------------------------------------+
		If ExistBlock("NGMOVSD3")
			aAutoItens := ExecBlock("NGMOVSD3", .F., .F., aAutoItens)
		EndIf

		dbSelectArea("SB2")
		dbSetOrder(01)
		If !dbSeek(xFilial("SB2")+cProd+If(Empty(cLocal), SB1->B1_LOCPAD, cLocal))
			CriaSB2(cProd, If(Empty(cLocal), SB1->B1_LOCPAD, cLocal))
		EndIf

		lMsErroAuto := .F.

		// MSExecAuto (SD3)
		If Substr(cCod,1,2)=='PR' // Produção.
			MsExecAuto({|x,y| MATA250(x,y)},aAutoItens,nOpc) // Produção Simples.
		Else
			aadd(_atotitem,aAutoItens)
			MSExecAuto({|x,y,z| MATA241(x,y,z)},_aCab1,_atotitem,3)
		EndIf

		If lMsErroAuto
            MostraErro()
			aRetArray[1] := .F.

			If lRetArray
				aRetArray[2] := MostraErro( GetSrvProfString("Startpath","") , ) // Não apresenta tela de erro
			ElseIf !IsBlind()
				MostraErro()// Apresenta MostraErro() em tela somente quando há interface com o usuário
			EndIf

		Else

			aRetArray := { .T., SD3->D3_NUMSEQ }
			//-------------------------------------
			//INTEGRACAO POR MENSAGEM UNICA
			//-------------------------------------
			If AllTrim(GetNewPar("MV_NGINTER","N")) == "M" // Mensagem Unica

				If AllTrim(SD3->D3_ESTORNO) == "S"
					NGMUCanReq(SD3->( RecNo() ), "SD3")
				Else
					If !NGMUStoTuO(SD3->( RecNo() ), "SD3")

						aAdd(aAutoItens, {"D3_NUMSEQ", cRet,})
						aAdd(aAutoItens, {"INDEX", 3,})

						MSExecAuto({|x,y| MATA240(x,y)},aCab1,aAutoItens,5)
						aRetArray := { .F., STR1454 } //"Houve um problema ao realizar integração por mensagem única."
					EndIf
				EndIf
			EndIf
		EndIf
	EndIf

	cFilAnt := _FilialAnt // Retorna a filial salva

	//---------------------------------------
	//Ajuste para retorno tipo caracter
	//Sucesso : retorna código NUMSEQ
	//Problema: retorna vazio
	//---------------------------------------
	If !lRetArray
		If aRetArray[1]
			cRet := aRetArray[2]
		Else
			cRet := ''
		EndIf
	EndIf

Return IIf( lRetArray, aRetArray, cRet )
