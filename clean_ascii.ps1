$p = 'd:\Desenvolvimento\Power Sheel\ERP_GESTAO\ERP_GESTAO.ps1'
$c = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$c = $c.Replace('á', 'a').Replace('à', 'a').Replace('â', 'a').Replace('ã', 'a')
$c = $c.Replace('é', 'e').Replace('ê', 'e')
$c = $c.Replace('í', 'i')
$c = $c.Replace('ó', 'o').Replace('ô', 'o').Replace('õ', 'o')
$c = $c.Replace('ú', 'u')
$c = $c.Replace('ç', 'c')
$c = $c.Replace('Á', 'A').Replace('À', 'A').Replace('Â', 'A').Replace('Ã', 'A')
$c = $c.Replace('É', 'E').Replace('Ê', 'E')
$c = $c.Replace('Í', 'I')
$c = $c.Replace('Ó', 'O').Replace('Ô', 'O').Replace('Õ', 'O')
$c = $c.Replace('Ú', 'U')
$c = $c.Replace('Ç', 'C')
$c = $c.Replace([char]0x1F4D6, '') # Livro
$c = $c.Replace([char]0x2022, '-') # Bullet
$c = $c.Replace([char]0x2191, '(+)') # Seta cima
$c = $c.Replace([char]0x2193, '(-)') # Seta baixo
[System.IO.File]::WriteAllText($p, $c, [System.Text.Encoding]::ASCII)
Write-Host "Limpeza total concluida em ASCII!"
