# Extrator para versão reduzida do ERP_GESTAO
# Mantém apenas: Jukebox Pro + Gestão de Arquivos

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " CRIANDO ERP_GESTAO_REDUZIDA.ps1" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

$original = Get-Content "ERP_GESTAO.ps1"
$reduzida = New-Object System.Collections.ArrayList

Write-Host "[1/5] Copiando header e configurações globais..." -ForegroundColor Yellow

# Header  e configurações (linhas 1-1394)
for ($i = 0; $i -lt 1395; $i++) {
    [void]$reduzida.Add($original[$i])
}

Write-Host "  ✓ $($reduzida.Count) linhas copiadas" -ForegroundColor Green

# Ajustar criação do TabControl - removendo abas não necessárias
Write-Host "`n[2/5] Criando estrutura de abas reduzida..." -ForegroundColor Yellow

# Encontrar onde começa DASHBOARD e pular para GestãoFormação de Arquivos
$dashLine = 1433
$arquivosLine = 4252  # ABA GESTAO DE ARQUIVOS
$jukeboxLine = 5897   # ABA JUKEBOX

Write-Host "  Pulando de linha $dashLine para $arquivosLine..." -ForegroundColor Gray

# Adicionar comentário de separação
[void]$reduzida.Add("`r")
[void]$reduzida.Add("# ============================" + "`r")
[void]$reduzida.Add("# VERSÃO REDUZIDA - SOMENTE JUKEBOX + GESTÃO DE ARQUIVOS" + "`r")
[void]$reduzida.Add("# ============================" + "`r")
[void]$reduzida.Add("`r")

Write-Host "`n[3/5] Copiando ABA GESTÃO DE ARQUIVOS..." -ForegroundColor Yellow

# Copiar ABA de Gestão de Arquivos (4252 até antes do Jukebox - 5897)
for ($i = $arquivosLine; $i -lt $jukeboxLine; $i++) {
    [void]$reduzida.Add($original[$i])
}

$linhasArquivos = $jukeboxLine - $arquivosLine
Write-Host "  ✓ $linhasArquivos linhas copiadas" -ForegroundColor Green

Write-Host "`n[4/5] Copiando ABA JUKEBOX PROFISSIONAL..." -ForegroundColor Yellow

# Encontrar onde termina o Jukebox (próxima aba é EMAIL PRO - linha 6873)
$emailLine = 6873

# Copiar ABA de Jukebox (5897 até 6873)
for ($i = $jukeboxLine; $i -lt $emailLine; $i++) {
    [void]$reduzida.Add($original[$i])
}

$linhasJukebox = $emailLine - $jukeboxLine
Write-Host "  ✓ $linhasJukebox linhas copiadas" -ForegroundColor Green

Write-Host "`n[5/5] Finalizando com funções de tema e execução..." -ForegroundColor Yellow

# Copiar final (Apply-Theme, eventos, ShowDialog) - linhas 9119 até o final
for ($i = 9119; $i -lt $original.Count; $i++) {
    [void]$reduzida.Add($original[$i])
}

$linhasFinal = $original.Count - 9119
Write-Host "  ✓ $linhasFinal linhas copiadas" -ForegroundColor Green

# Salvar arquivo
$outputFile = "ERP_GESTAO_REDUZIDA.ps1"
$reduzida | Out-File $outputFile -Encoding UTF8

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nArquivo criado: $outputFile" -ForegroundColor White
Write-Host "Linhas no original: $($original.Count)" -ForegroundColor Gray
Write-Host "Linhas na versão reduzida: $($reduzida.Count)" -ForegroundColor Yellow
Write-Host "Redução: $([math]::Round((1 - $reduzida.Count/$original.Count)*100, 1))%" -ForegroundColor Cyan
Write-Host "`nAbas incluídas:" -ForegroundColor White
Write-Host "  ✓ Jukebox Profissional" -ForegroundColor Green
Write-Host "  ✓ Gestão de Arquivos" -ForegroundColor Green
Write-Host "`n"
