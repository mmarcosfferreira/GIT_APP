# ==========================================
# INICIAR SISTEMA (Launcher Automático)
# ==========================================

Write-Host "=== INICIANDO ERP GESTAO PRO ===" -ForegroundColor Cyan

# 1. Verifica se Node.js está instalado
try {
    $nodeVersion = node -v
    Write-Host "Node.js detectado: $nodeVersion" -ForegroundColor Green
}
catch {
    Write-Host "[ERRO] Node.js não encontrado!" -ForegroundColor Red
    Write-Host "Por favor, instale o Node.js em https://nodejs.org/"
    Pause
    Exit
}

# 2. Verifica se as dependências (node_modules) existem
if (-not (Test-Path ".\node_modules")) {
    Write-Host "Dependências não encontradas. Instalando via npm install..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERRO] Falha ao instalar dependências." -ForegroundColor Red
        Pause
        Exit
    }
} else {
    Write-Host "Dependências verificadas." -ForegroundColor Green
}

# 3. Inicia o Electron em modo de desenvolvimento
Write-Host "Iniciando aplicação..." -ForegroundColor Cyan
# O comando abaixo roda o script 'electron:dev' definido no package.json
npm run electron:dev