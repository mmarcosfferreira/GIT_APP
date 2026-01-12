$p = 'd:\Desenvolvimento\Power Sheel\ERP_GESTAO\ERP_GESTAO.ps1'
$c = [System.IO.File]::ReadAllText($p)
# Substituicoes seguras
$c = $c -replace '[áàâã]', 'a' -replace '[éê]', 'e' -replace 'í', 'i' -replace '[óôõ]', 'o' -replace 'ú', 'u' -replace 'ç', 'c'
$c = $c -replace '[ÁÀÂÃ]', 'A' -replace '[ÉÊ]', 'E' -replace 'Í', 'I' -replace '[ÓÔÕ]', 'O' -replace 'Ú', 'U' -replace 'Ç', 'C'
$c = $c -replace '📖', '' -replace '•', '-'
# Forcar gravacao em ASCII total (remove qualquer chance de erro de encoding)
[System.IO.File]::WriteAllLines($p, ($c -split "`r?`n"), [System.Text.Encoding]::ASCII)
Write-Host "Arquivo normalizado com sucesso!"
