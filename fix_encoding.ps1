$path = "d:\Desenvolvimento\Power Sheel\ERP_GESTAO\ERP_GESTAO.ps1"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$map = @{
    'á' = 'a'; 'à' = 'a'; 'â' = 'a'; 'ã' = 'a';
    'é' = 'e'; 'ê' = 'e';
    'í' = 'i';
    'ó' = 'o'; 'ô' = 'o'; 'õ' = 'o';
    'ú' = 'u';
    'ç' = 'c';
    'Á' = 'A'; 'À' = 'A'; 'Â' = 'A'; 'Ã' = 'A';
    'É' = 'E'; 'Ê' = 'E';
    'Í' = 'I';
    'Ó' = 'O'; 'Ô' = 'O'; 'Õ' = 'O';
    'Ú' = 'U';
    'Ç' = 'C';
    '📖' = ''; '•' = '-'; '↑' = '(+)'; '↓' = '(-)'
}
foreach ($key in $map.Keys) {
    $content = $content.Replace($key, $map[$key])
}
# Salvar com UTF8 (com BOM)
[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
Write-Host "Limpeza concluida!"
