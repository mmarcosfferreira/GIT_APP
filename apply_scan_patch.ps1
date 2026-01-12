# Script para aplicar o patch no Scan-MusicFolder
$file = "D:\Desenvolvimento\Power Sheel\ERP_GESTAO\ERP_GESTAO.ps1"
$content = Get-Content $file -Raw -Encoding UTF8

# Patch 1: Mudar a mensagem (linha ~4999-5000)
$oldMsg = '    $msg = "DESEJA ESCANEAR MUSICAS $($pattern.ToUpper())?"' + "`r`n" + '    $res = [System.Windows.Forms.MessageBox]::Show($msg, "SCAN", ''YesNo'', ''Question'')'
$newMsg = '    $msg = "SIM = Scan Rapido (Pastas)`nNAO = Scan TODO PC (Demora)"' + "`r`n" + '    $res = [System.Windows.Forms.MessageBox]::Show($msg, "SCAN $($pattern.ToUpper())", ''YesNoCancel'', ''Question'')'

$content = $content.Replace($oldMsg, $newMsg)

# Patch 2: Adicionar lógica para scan completo (após linha ~5002)
$oldReturn = '    if ($res -ne ''Yes'') { return }'
$newCode = @'
    if ($res -eq 'Cancel') { return }
    
    # NAO = Scan TODO PC em Background
    if ($res -eq 'No') {
        if ($script:MusicScanWorker.IsBusy) {
            [System.Windows.Forms.MessageBox]::Show("SCAN JA EM ANDAMENTO!", "AGUARDE", 'OK', 'Warning')
            return
        }
        Show-ScanLog
        $inputArgs = @{ Filter = $pattern }
        $script:MusicScanWorker.RunWorkerAsync($inputArgs)
        return
    }
    
    # SIM = Scan Rapido
'@

$content = $content.Replace($oldReturn, $newCode)

# Salvar
Set-Content $file -Value $content -Encoding UTF8 -NoNewline

Write-Host "PATCH APLICADO COM SUCESSO!" -ForegroundColor Green
Write-Host "Reinicie a aplicacao para usar o scan completo." -ForegroundColor Cyan
