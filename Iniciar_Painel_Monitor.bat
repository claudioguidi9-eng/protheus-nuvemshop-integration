@echo off
chcp 65001 > nul
title MONITOR OPERACIONAL FORTBRAS - NUVEMSHOP (TORRE DE CONTROLE)
color 0B

echo ================================================================================
echo   INICIANDO PAINEL WEB DE MONITORAMENTO OPERACIONAL (FORTBRAS x NUVEMSHOP)
echo ================================================================================
echo.
echo Abrindo painel grafico no navegador padrao (http://localhost:3000)...
echo.

start "" cmd /c "timeout /t 3 > nul && start http://localhost:3000"

cd /d "C:\D\@Fortbras\monitor-integracao-nuvemshop"
npm run dev

echo.
echo Servidor do painel encerrado.
pause
