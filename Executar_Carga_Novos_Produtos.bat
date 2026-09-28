@echo off
chcp 65001 > nul
cls
echo ===============================================================================
echo     FORTBRAS / HIPERVAREJO - CENTRAL DE CARGA E ENRIQUECIMENTO NUVEMSHOP
echo ===============================================================================
echo.
echo Escolha a operacao que deseja executar:
echo.
echo [1] Sincronizar Palavras Similares da VTEX para as Tags Nuvemshop (SEO)
echo [2] Gerar Novo Indice de Palavras Similares (Ler Planilha VTEX)
echo [3] Sincronizar Dados Veiculares em Massa (Montadora, Modelo, Ano, Aplicacao)
echo [4] Auditar e Corrigir Precos Invertidos (Preco Promocional maior que Cheio)
echo [5] Sincronizar e Limpar Categorias (Hierarquia sem linhas em branco)
echo [6] Executar Pipeline Completo de Enriquecimento (Passos 5, 3, 1 e 4)
echo [0] Sair
echo.
echo ===============================================================================
set /p OPCAO="Digite a opcao desejada [0-6]: "

if "%OPCAO%"=="1" goto OP1
if "%OPCAO%"=="2" goto OP2
if "%OPCAO%"=="3" goto OP3
if "%OPCAO%"=="4" goto OP4
if "%OPCAO%"=="5" goto OP5
if "%OPCAO%"=="6" goto OP6
if "%OPCAO%"=="0" goto SAIR
goto INVALIDO

:OP1
echo.
echo [INFO] Iniciando Sincronizacao de Tags (Palavras Similares VTEX)...
node sync_all_vtex_tags.js
pause
goto FIM

:OP2
echo.
echo [INFO] Gerando indice NDJSON a partir da planilha oficial VTEX...
node build_vtex_tags_ndjson.js
pause
goto FIM

:OP3
echo.
echo [INFO] Iniciando Sincronizacao de Custom Fields Veiculares...
node sync_all_vehicle_custom_fields.js
pause
goto FIM

:OP4
echo.
echo [INFO] Auditando e Corrigindo Precos Invertidos na Nuvemshop...
node fix_all_inverted_prices_on_store.js
pause
goto FIM

:OP5
echo.
echo [INFO] Higienizando e Sincronizando Categorias...
node step1_sync_categories.js
pause
goto FIM

:OP6
echo.
echo ===============================================================================
echo [PIPELINE] Executando enriquecimento e saneamento completo da loja...
echo ===============================================================================
echo.
echo [1/4] Higienizando Categorias...
node step1_sync_categories.js
echo.
echo [2/4] Sincronizando Dados Veiculares (Custom Fields)...
node sync_all_vehicle_custom_fields.js
echo.
echo [3/4] Sincronizando Tags com Palavras Similares da VTEX...
node sync_all_vtex_tags.js
echo.
echo [4/4] Validando Precos Invertidos...
node fix_all_inverted_prices_on_store.js
echo.
echo ===============================================================================
echo [SUCESSO] Pipeline completo concluido!
echo ===============================================================================
pause
goto FIM

:INVALIDO
echo.
echo Opcao invalida!
pause
goto FIM

:SAIR
echo.
echo Saindo...

:FIM
