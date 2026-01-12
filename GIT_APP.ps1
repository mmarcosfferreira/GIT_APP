# ============================
# GIT_APP.ps1 - Standalone Git Manager
# Extracted from ERP_GESTAO_REDUZIDA.ps1
# ============================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# --- Configuration ---
$script:GitHubTokensFile = "$PSScriptRoot\github_tokens.json"
$script:AppConfig = @{}
$ConfigFile = "$PSScriptRoot\data\config.json"

# Load config if exists
if (Test-Path $ConfigFile) {
    try { $script:AppConfig = Get-Content $ConfigFile | ConvertFrom-Json -AsHashtable } catch {}
}

# Save config function
function Save-Config {
    $configDir = Split-Path $ConfigFile -Parent
    if (!(Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $script:AppConfig | ConvertTo-Json | Out-File $ConfigFile -Encoding utf8
}

# --- Theme Colors ---
$Colors = @{
    Primary    = [System.Drawing.Color]::FromArgb(88, 166, 255)
    Secondary  = [System.Drawing.Color]::FromArgb(100, 100, 150)
    Danger     = [System.Drawing.Color]::FromArgb(200, 50, 50)
    Success    = [System.Drawing.Color]::FromArgb(40, 120, 60)
    Warning    = [System.Drawing.Color]::FromArgb(200, 150, 0)
    Background = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Surface    = [System.Drawing.Color]::FromArgb(45, 45, 55)
    Text       = [System.Drawing.Color]::White
}

# --- Apply Theme (Simplified) ---
function Apply-Theme($control) {
    if ($null -eq $control) { return }
    try {
        $control.BackColor = $Colors.Background
        $control.ForeColor = $Colors.Text
        if ($control.Controls) {
            foreach ($c in $control.Controls) {
                Apply-Theme $c
            }
        }
    }
    catch {}
}

# ============================
# DETECTOR DE SEGREDOS (Tokens, API Keys, Senhas)
# ============================
function Test-FileContainsSecrets {
    param([string]$filePath)
    
    try {
        $fileInfo = Get-Item $filePath -ErrorAction SilentlyContinue
        if (-not $fileInfo) { return $false }
        
        $ext = $fileInfo.Extension.ToLower()
        $binaryExts = @('.exe', '.dll', '.zip', '.rar', '.7z', '.mp3', '.wav', '.mp4', '.mkv', '.jpg', '.png', '.gif', '.ico', '.db', '.sqlite')
        if ($binaryExts -contains $ext) { return $false }
        if ($fileInfo.Length -gt 1MB) { return $false }
        
        $content = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return $false }
        
        $secretPatterns = @(
            'ghp_[a-zA-Z0-9]{36}',
            'gho_[a-zA-Z0-9]{36}',
            'github_pat_[a-zA-Z0-9_]{22,}',
            'hf_[a-zA-Z0-9]{34}',
            'sk-[a-zA-Z0-9]{48}',
            'AIza[a-zA-Z0-9_-]{35}',
            'api[_-]?key\s*[=:]\s*[''][a-zA-Z0-9_-]{20,}['']',
            'token\s*[=:]\s*[''][a-zA-Z0-9_-]{20,}['']',
            'password\s*[=:]\s*[''][^'']{8,}['']',
            'senha\s*[=:]\s*[''][^'']{8,}['']',
            'secret\s*[=:]\s*[''][a-zA-Z0-9_-]{16,}['']',
            'Bearer\s+[a-zA-Z0-9_-]{20,}',
            'Authorization['']?\s*[=:]\s*[''][^'']{20,}['']'
        )
        
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

# ============================
# TOKEN MANAGER
# ============================
function Show-TokenManager {
    param($refUser, $refToken)
    
    $tmForm = New-Object System.Windows.Forms.Form
    $tmForm.Text = "🔐 Gerenciador de Tokens GitHub"
    $tmForm.Size = "1000, 700"
    $tmForm.StartPosition = "CenterScreen"
    $tmForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $tmForm.ForeColor = "White"
    $tmForm.FormBorderStyle = 'Sizable'

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = "Fill"
    $split.SplitterDistance = 350
    $split.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 55)
    $tmForm.Controls.Add($split)

    $pnlLeft = $split.Panel1
    $pnlLeft.Padding = New-Object System.Windows.Forms.Padding(10)

    $lblList = New-Object System.Windows.Forms.Label
    $lblList.Text = "🔑 Tokens Salvos"
    $lblList.Dock = "Top"
    $lblList.Height = 35
    $lblList.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblList.ForeColor = $Colors.Primary
    $pnlLeft.Controls.Add($lblList)
    
    $lstTokens = New-Object System.Windows.Forms.ListBox
    $lstTokens.Dock = "Fill"
    $lstTokens.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 30)
    $lstTokens.ForeColor = "White"
    $lstTokens.BorderStyle = "FixedSingle"
    $lstTokens.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $pnlLeft.Controls.Add($lstTokens)
    
    $pnlListBtns = New-Object System.Windows.Forms.Panel
    $pnlListBtns.Dock = "Bottom"
    $pnlListBtns.Height = 100
    $pnlLeft.Controls.Add($pnlListBtns)

    $btnUse = New-Object System.Windows.Forms.Button
    $btnUse.Text = "✅ USAR SELECIONADO"
    $btnUse.Dock = "Top"
    $btnUse.Height = 45
    $btnUse.BackColor = [System.Drawing.Color]::FromArgb(40, 120, 60)
    $btnUse.FlatStyle = "Flat"
    $btnUse.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $pnlListBtns.Controls.Add($btnUse)

    $btnDel = New-Object System.Windows.Forms.Button
    $btnDel.Text = "🗑️ EXCLUIR"
    $btnDel.Dock = "Bottom"
    $btnDel.Height = 40
    $btnDel.BackColor = [System.Drawing.Color]::FromArgb(150, 50, 50)
    $btnDel.FlatStyle = "Flat"
    $pnlListBtns.Controls.Add($btnDel)

    $pnlRight = $split.Panel2
    $pnlRight.Padding = New-Object System.Windows.Forms.Padding(20)
    $pnlRight.AutoScroll = $true

    $lblNew = New-Object System.Windows.Forms.Label
    $lblNew.Text = "➕ Adicionar Novo Token"
    $lblNew.Dock = "Top"
    $lblNew.Height = 40
    $lblNew.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $pnlRight.Controls.Add($lblNew)

    function Add-InputBlock {
        param($parent, $labelTxt, $isPassword)
        
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = "Top"
        $panel.Height = 70
        $panel.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
        
        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Dock = "Top"
        $txt.Height = 35
        $txt.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $txt.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
        $txt.ForeColor = "White"
        if ($isPassword) { $txt.PasswordChar = "*" }
        
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labelTxt
        $lbl.Dock = "Top"
        $lbl.Height = 25
        
        $panel.Controls.Add($txt)
        $panel.Controls.Add($lbl)
        
        $parent.Controls.Add($panel)
        
        return $txt
    }

    $grpHelp = New-Object System.Windows.Forms.GroupBox
    $grpHelp.Text = "❓ COMO OBTER O TOKEN?"
    $grpHelp.Height = 150
    $grpHelp.Dock = "Top"
    $grpHelp.ForeColor = "Cyan"
    
    $lblHelpTxt = New-Object System.Windows.Forms.Label
    $lblHelpTxt.Text = "1. Clique no botão abaixo para abrir o GitHub.`n2. Crie um 'Classic' Token.`n3. Marque a permissão 'Repo'.`n4. Copie o código (ghp_...) e cole acima."
    $lblHelpTxt.Dock = "Top"
    $lblHelpTxt.Height = 60
    $lblHelpTxt.ForeColor = "White"
    
    $btnOpenGit = New-Object System.Windows.Forms.Button
    $btnOpenGit.Text = "🌐 ABRIR GITHUB TOKENS"
    $btnOpenGit.Dock = "Top"
    $btnOpenGit.Height = 35
    $btnOpenGit.BackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
    $btnOpenGit.FlatStyle = "Flat"
    $btnOpenGit.Add_Click({ [System.Diagnostics.Process]::Start("https://github.com/settings/tokens") })

    $grpHelp.Controls.Add($btnOpenGit)
    $grpHelp.Controls.Add($lblHelpTxt)
    $pnlRight.Controls.Add($grpHelp)
    
    $pnlSave = New-Object System.Windows.Forms.Panel; $pnlSave.Dock = "Top"; $pnlSave.Height = 60; $pnlSave.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 10)
    $btnSaveToken = New-Object System.Windows.Forms.Button; $btnSaveToken.Text = "💾 SALVAR NA LISTA"; $btnSaveToken.Dock = "Top"; $btnSaveToken.Height = 40; $btnSaveToken.BackColor = $Colors.Primary; $btnSaveToken.FlatStyle = "Flat"
    $pnlSave.Controls.Add($btnSaveToken)
    $pnlRight.Controls.Add($pnlSave)
    
    $txtTokenTm = Add-InputBlock $pnlRight "Personal Access Token:" $true
    $txtUserTm = Add-InputBlock $pnlRight "Usuário GitHub:" $false
    $txtAlias = Add-InputBlock $pnlRight "Nome (Apelido):" $false
    
    $pnlRight.Controls.Remove($lblNew)
    $pnlRight.Controls.Add($lblNew)
    
    $tokensList = @()
    if (Test-Path $script:GitHubTokensFile) {
        try { $tokensList = Get-Content $script:GitHubTokensFile | ConvertFrom-Json } catch { $tokensList = @() }
    }
    
    function Refresh-TokenList {
        $lstTokens.Items.Clear()
        if ($tokensList -is [System.Array]) {
            foreach ($t in $tokensList) {
                $lstTokens.Items.Add("$($t.Alias) | User: $($t.User)")
            }
        }
        elseif ($tokensList) {
            $lstTokens.Items.Add("$($tokensList.Alias) | User: $($tokensList.User)")
        }
    }
    
    Refresh-TokenList

    $btnSaveToken.Add_Click({
            $alias = $txtAlias.Text
            $user = $txtUserTm.Text
            $token = $txtTokenTm.Text
    
            if (!$alias -or !$user -or !$token) { [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos!"); return }
    
            $newItem = @{ Alias = $alias; User = $user; Token = $token }
    
            $arr = [System.Collections.ArrayList]::new()
            if ($tokensList) { $arr.AddRange($tokensList) }
            $arr.Add($newItem)
    
            $arr | ConvertTo-Json | Out-File $script:GitHubTokensFile -Encoding utf8
    
            Set-Variable -Name tokensList -Value (Get-Content $script:GitHubTokensFile | ConvertFrom-Json) -Scope 1
            Refresh-TokenList
            [System.Windows.Forms.MessageBox]::Show("Token salvo com sucesso!")
    
            $txtAlias.Text = ""; $txtUserTm.Text = ""; $txtTokenTm.Text = ""
        })

    $btnDel.Add_Click({
            $idx = $lstTokens.SelectedIndex
            if ($idx -ge 0) {
                $arr = [System.Collections.ArrayList]::new()
                if ($tokensList) { $arr.AddRange($tokensList) }
                $arr.RemoveAt($idx)
        
                $arr | ConvertTo-Json | Out-File $script:GitHubTokensFile -Encoding utf8
                $tokensList = $arr
                Refresh-TokenList
            }
        })

    $btnUse.Add_Click({
            $idx = $lstTokens.SelectedIndex
            if ($idx -ge 0) {
                $sel = if ($tokensList -is [System.Array]) { $tokensList[$idx] } else { $tokensList }
                $refUser.Text = $sel.User
                $refToken.Text = $sel.Token
                $tmForm.Close()
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Selecione um token na lista à esquerda!")
            }
        })

    Apply-Theme $tmForm
    [void]$tmForm.ShowDialog()
}

# ============================
# GITHUB UPLOAD FORM
# ============================
function Show-GitHubUpload {
    $gitForm = New-Object System.Windows.Forms.Form
    $gitForm.Text = "📤 GitHub - Upload de Projeto"
    $gitForm.Size = "850, 680"
    $gitForm.StartPosition = "CenterScreen"
    $gitForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $gitForm.ForeColor = "White"
    $gitForm.FormBorderStyle = 'FixedDialog'
    $gitForm.MaximizeBox = $false

    # Header
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text = "🐙 GitHub Upload Manager"
    $lblHeader.Location = "20, 15"
    $lblHeader.Size = "400, 30"
    $lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblHeader.ForeColor = [System.Drawing.Color]::FromArgb(88, 166, 255)
    $gitForm.Controls.Add($lblHeader)

    # --- SEÇÃO: PASTA DO PROJETO ---
    $lblPasta = New-Object System.Windows.Forms.Label
    $lblPasta.Text = "📁 Pasta do Projeto:"
    $lblPasta.Location = "20, 45"
    $lblPasta.Size = "150, 20"
    $gitForm.Controls.Add($lblPasta)
 
    $txtPasta = New-Object System.Windows.Forms.TextBox
    $txtPasta.Location = "20, 70"
    $txtPasta.Size = "450, 25"
    $txtPasta.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtPasta.ForeColor = "White"
    $txtPasta.Text = $PSScriptRoot
    $gitForm.Controls.Add($txtPasta)
 
    $btnBrowsePasta = New-Object System.Windows.Forms.Button
    $btnBrowsePasta.Text = "..."
    $btnBrowsePasta.Location = "480, 68"
    $btnBrowsePasta.Size = "80, 28"
    $btnBrowsePasta.BackColor = $Colors.Primary
    $btnBrowsePasta.FlatStyle = "Flat"
    $btnBrowsePasta.Add_Click({
            $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
            $fbd.Description = "Selecione a pasta do projeto"
            $fbd.SelectedPath = $txtPasta.Text
            if ($fbd.ShowDialog() -eq 'OK') { 
                $txtPasta.Text = $fbd.SelectedPath
                $lstIgnore.Items.Clear()
                $files = Get-ChildItem -Path $fbd.SelectedPath -File -ErrorAction SilentlyContinue | Select-Object -First 50
            
                $secretFiles = @()
            
                foreach ($f in $files) {
                    $sizeMB = [math]::Round($f.Length / 1MB, 2)
                    $isBig = $sizeMB -ge 100
                    $isBinary = $f.Extension -match '\.(exe|dll|mp3|wav|mp4|mkv|zip|rar|7z|db|sqlite)$'
                
                    $hasSecret = Test-FileContainsSecrets -filePath $f.FullName
                    if ($hasSecret) { $secretFiles += $f.Name }
                
                    $displayText = if ($hasSecret) { "🔒 $($f.Name) ($sizeMB MB)" } 
                    elseif ($isBig) { "⚠️ $($f.Name) ($sizeMB MB)" } 
                    else { "$($f.Name) ($sizeMB MB)" }
                
                    $item = New-Object System.Windows.Forms.ListViewItem($displayText)
                    $item.Tag = $f.Name
                
                    if ($hasSecret) {
                        $item.ForeColor = [System.Drawing.Color]::Red
                        $item.Checked = $true
                    }
                    elseif ($isBig) {
                        $item.ForeColor = [System.Drawing.Color]::Orange
                        $item.Checked = $true
                    }
                    elseif ($isBinary) {
                        $item.ForeColor = [System.Drawing.Color]::Gray
                        $item.Checked = $true
                    }
                    else {
                        $item.ForeColor = [System.Drawing.Color]::LightGreen
                    }
                
                    $lstIgnore.Items.Add($item) | Out-Null
                }
            
                if ($secretFiles.Count -gt 0) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "🔒 ATENÇÃO! Foram detectados $($secretFiles.Count) arquivo(s) com possíveis SEGREDOS:`n`n" + ($secretFiles -join "`n"),
                        "🔐 Segredos Detectados",
                        'OK',
                        'Warning'
                    )
                }
            }
        })
    $gitForm.Controls.Add($btnBrowsePasta)

    # --- SEÇÃO: REPOSITÓRIO ---
    $lblRepo = New-Object System.Windows.Forms.Label
    $lblRepo.Text = "🔗 URL do Repositório (HTTPS):"
    $lblRepo.Location = "20, 105"
    $lblRepo.Size = "250, 20"
    $gitForm.Controls.Add($lblRepo)
 
    $txtRepo = New-Object System.Windows.Forms.TextBox
    $txtRepo.Location = "20, 130"
    $txtRepo.Size = "540, 25"
    $txtRepo.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtRepo.ForeColor = "White"
    $txtRepo.Text = if ($script:AppConfig['GitHubRepo']) { $script:AppConfig['GitHubRepo'] } else { "https://github.com/usuario/repositorio.git" }
    $gitForm.Controls.Add($txtRepo)
 
    # --- SEÇÃO: CREDENCIAIS ---
    $lblCred = New-Object System.Windows.Forms.Label
    $lblCred.Text = "🔐 Credenciais GitHub:"
    $lblCred.Location = "20, 165"
    $lblCred.Size = "200, 20"
    $gitForm.Controls.Add($lblCred)
 
    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Usuário (Handle):"
    $lblUser.Location = "20, 190"
    $lblUser.Size = "100, 20"
    $gitForm.Controls.Add($lblUser)
 
    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Location = "130, 187"
    $txtUser.Size = "180, 25"
    $txtUser.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtUser.ForeColor = "White"
    $txtUser.Text = if ($script:AppConfig['GitHubUser']) { $script:AppConfig['GitHubUser'] } else { "" }
    $gitForm.Controls.Add($txtUser)

    $lblToken = New-Object System.Windows.Forms.Label
    $lblToken.Text = "Token:"
    $lblToken.Location = "320, 190"
    $lblToken.Size = "90, 20"
    $gitForm.Controls.Add($lblToken)
 
    $txtToken = New-Object System.Windows.Forms.TextBox
    $txtToken.Location = "420, 187"
    $txtToken.Size = "100, 25"
    $txtToken.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtToken.ForeColor = "White"
    $txtToken.PasswordChar = "*"
    $txtToken.Text = if ($script:AppConfig['GitHubToken']) { $script:AppConfig['GitHubToken'] } else { "" }
    $gitForm.Controls.Add($txtToken)
 
    $btnTokenHelp = New-Object System.Windows.Forms.Button
    $btnTokenHelp.Text = "❓"
    $btnTokenHelp.Location = "525, 185"
    $btnTokenHelp.Size = "30, 28"
    $btnTokenHelp.FlatStyle = "Flat"
    $btnTokenHelp.BackColor = [System.Drawing.Color]::Transparent
    $btnTokenHelp.ForeColor = [System.Drawing.Color]::Cyan
    $btnTokenHelp.Cursor = 'Hand'
    $btnTokenHelp.Add_Click({ 
            Show-TokenManager $txtUser $txtToken
        })
    $gitForm.Controls.Add($btnTokenHelp)
 
    # --- SEÇÃO: VISIBILIDADE (NOVO REPO) ---
    $lblVisibility = New-Object System.Windows.Forms.Label
    $lblVisibility.Text = "👁️ Visibilidade (para novo repositório):"
    $lblVisibility.Location = "20, 220"
    $lblVisibility.Size = "280, 20"
    $gitForm.Controls.Add($lblVisibility)
 
    $rbPublic = New-Object System.Windows.Forms.RadioButton
    $rbPublic.Text = "🌍 Público"
    $rbPublic.Location = "20, 243"
    $rbPublic.Size = "100, 20"
    $rbPublic.Checked = $true
    $gitForm.Controls.Add($rbPublic)
 
    $rbPrivate = New-Object System.Windows.Forms.RadioButton
    $rbPrivate.Text = "🔒 Privado"
    $rbPrivate.Location = "130, 243"
    $rbPrivate.Size = "100, 20"
    $gitForm.Controls.Add($rbPrivate)
 
    $btnCreateRepo = New-Object System.Windows.Forms.Button
    $btnCreateRepo.Text = "➕ Criar Novo Repo"
    $btnCreateRepo.Location = "250, 238"
    $btnCreateRepo.Size = "130, 28"
    $btnCreateRepo.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 150)
    $btnCreateRepo.FlatStyle = "Flat"
    $btnCreateRepo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $btnCreateRepo.Add_Click({
            $repoName = [Microsoft.VisualBasic.Interaction]::InputBox("Digite o nome do novo repositório:", "Criar Repositório", "meu-projeto")
            if (!$repoName) { return }
    
            $user = $txtUser.Text
            $token = $txtToken.Text
            $isPrivate = $rbPrivate.Checked

            if ($user -match "@") {
                [System.Windows.Forms.MessageBox]::Show("Erro: Use o NOME DE USUÁRIO (Handle) do GitHub, não o email!", "Erro de Autenticação", 'OK', 'Error')
                return 
            }
    
            if (!$user -or !$token) {
                [System.Windows.Forms.MessageBox]::Show("Preencha usuário e token primeiro!", "Erro", 'OK', 'Warning')
                return
            }
    
            try {
                $headers = @{
                    "Authorization" = "token $token"
                    "Accept"        = "application/vnd.github.v3+json"
                }
                $body = @{
                    name      = $repoName
                    private   = $isPrivate
                    auto_init = $true
                } | ConvertTo-Json
        
                $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json"
        
                $txtRepo.Text = $response.clone_url
                [System.Windows.Forms.MessageBox]::Show("Repositório '$repoName' criado com sucesso!`n`nURL: $($response.clone_url)", "Sucesso", 'OK', 'Information')
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Erro ao criar repositório: $($_.Exception.Message)", "Erro", 'OK', 'Error')
            }
        })
    $gitForm.Controls.Add($btnCreateRepo)

    # --- SEÇÃO: MENSAGEM DE COMMIT ---
    $lblCommit = New-Object System.Windows.Forms.Label
    $lblCommit.Text = "📝 Mensagem do Commit:"
    $lblCommit.Location = "20, 275"
    $lblCommit.Size = "200, 20"
    $gitForm.Controls.Add($lblCommit)
 
    $txtCommit = New-Object System.Windows.Forms.TextBox
    $txtCommit.Location = "20, 300"
    $txtCommit.Size = "540, 25"
    $txtCommit.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtCommit.ForeColor = "White"
    $txtCommit.Text = "Atualização do projeto - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    $gitForm.Controls.Add($txtCommit)
 
    # --- LOG DE SAÍDA ---
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Text = "📋 Log de Execução:"
    $lblLog.Location = "20, 335"
    $lblLog.Size = "200, 20"
    $gitForm.Controls.Add($lblLog)
    
    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Location = "20, 360"
    $txtLog.Size = "540, 160"
    $txtLog.BackColor = [System.Drawing.Color]::Black
    $txtLog.ForeColor = [System.Drawing.Color]::LimeGreen
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $txtLog.ReadOnly = $true
    $gitForm.Controls.Add($txtLog)

    # --- SELETOR DE ARQUIVOS PARA IGNORAR ---
    $lblIgnore = New-Object System.Windows.Forms.Label
    $lblIgnore.AutoSize = $true
    $lblIgnore.Text = "🔐 Arquivos a IGNORAR (marque para não enviar)"
    $lblIgnore.Location = "580, 60"
    $lblIgnore.Size = "270, 20"
    $lblIgnore.ForeColor = [System.Drawing.Color]::Yellow
    $gitForm.Controls.Add($lblIgnore)
    
    $lstIgnore = New-Object System.Windows.Forms.ListView
    $lstIgnore.Name = "lstIgnore"
    $lstIgnore.Location = "580, 85"
    $lstIgnore.Size = "240, 480"
    $lstIgnore.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 50)
    $lstIgnore.ForeColor = [System.Drawing.Color]::White
    $lstIgnore.Font = New-Object System.Drawing.Font("Consolas", 8)
    $lstIgnore.View = [System.Windows.Forms.View]::Details
    $lstIgnore.CheckBoxes = $true
    $lstIgnore.FullRowSelect = $true
    $lstIgnore.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::None
    $lstIgnore.Columns.Add("Arquivo", 230) | Out-Null
    $lstIgnore.ShowItemToolTips = $true
    $gitForm.Controls.Add($lstIgnore)
    
    $btnLoadFiles = New-Object System.Windows.Forms.Button
    $btnLoadFiles.Text = "🔄 Atualizar Lista"
    $btnLoadFiles.Location = "580, 570"
    $btnLoadFiles.Size = "115, 28"
    $btnLoadFiles.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 100)
    $btnLoadFiles.FlatStyle = "Flat"
    $btnLoadFiles.Add_Click({
            $lstIgnore.Items.Clear()
            if (Test-Path $txtPasta.Text) {
                $files = Get-ChildItem -Path $txtPasta.Text -File -ErrorAction SilentlyContinue | Select-Object -First 50
            
                foreach ($f in $files) {
                    $sizeMB = [math]::Round($f.Length / 1MB, 2)
                    $isBig = $sizeMB -ge 100
                    $isBinary = $f.Extension -match '\.(exe|dll|mp3|wav|mp4|mkv|zip|rar|7z|db|sqlite)$'
                
                    $hasSecret = Test-FileContainsSecrets -filePath $f.FullName
                
                    $displayText = if ($hasSecret) { "🔒 $($f.Name) ($sizeMB MB)" } 
                    elseif ($isBig) { "⚠️ $($f.Name) ($sizeMB MB)" } 
                    else { "$($f.Name) ($sizeMB MB)" }
                
                    $item = New-Object System.Windows.Forms.ListViewItem($displayText)
                    $item.Tag = $f.Name
                
                    if ($hasSecret) {
                        $item.ForeColor = [System.Drawing.Color]::Red
                        $item.Checked = $true
                    }
                    elseif ($isBig) {
                        $item.ForeColor = [System.Drawing.Color]::Orange
                        $item.Checked = $true
                    }
                    elseif ($isBinary) {
                        $item.ForeColor = [System.Drawing.Color]::Gray
                        $item.Checked = $true
                    }
                    else {
                        $item.ForeColor = [System.Drawing.Color]::LightGreen
                    }
                
                    $lstIgnore.Items.Add($item) | Out-Null
                }
            }
        })
    $gitForm.Controls.Add($btnLoadFiles)
    
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "✅ Todos"
    $btnSelectAll.Location = "700, 570"
    $btnSelectAll.Size = "60, 28"
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(60, 100, 60)
    $btnSelectAll.FlatStyle = "Flat"
    $btnSelectAll.Add_Click({
            foreach ($item in $lstIgnore.Items) { $item.Checked = $true }
        })
    $gitForm.Controls.Add($btnSelectAll)
    
    $btnClearAll = New-Object System.Windows.Forms.Button
    $btnClearAll.Text = "❌ Limpar"
    $btnClearAll.Location = "765, 570"
    $btnClearAll.Size = "55, 28"
    $btnClearAll.BackColor = [System.Drawing.Color]::FromArgb(100, 60, 60)
    $btnClearAll.FlatStyle = "Flat"
    $btnClearAll.Add_Click({
            foreach ($item in $lstIgnore.Items) { $item.Checked = $false }
        })
    $gitForm.Controls.Add($btnClearAll)
    
    # --- BARRA DE PROGRESSO DO PUSH ---
    $pbPush = New-Object System.Windows.Forms.ProgressBar
    $pbPush.Name = "pbPush"
    $pbPush.Location = "580, 605"
    $pbPush.Size = "240, 25"
    $pbPush.Style = "Continuous"
    $pbPush.Maximum = 100
    $pbPush.Value = 0
    $gitForm.Controls.Add($pbPush)
    
    $lblPushStatus = New-Object System.Windows.Forms.Label
    $lblPushStatus.Name = "lblPushStatus"
    $lblPushStatus.Text = "Aguardando..."
    $lblPushStatus.Location = "580, 635"
    $lblPushStatus.Size = "240, 20"
    $lblPushStatus.ForeColor = [System.Drawing.Color]::Cyan
    $gitForm.Controls.Add($lblPushStatus)

    # Função para log
    $addGitLog = {
        param([string]$msg, [string]$color = "LimeGreen")
        if ($txtLog.IsDisposed) { return }
        try {
            $txtLog.SelectionStart = $txtLog.TextLength
            $txtLog.SelectionColor = [System.Drawing.Color]::$color
            $txtLog.AppendText("$msg`n")
            $txtLog.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
        catch {}
    }

    # --- OPÇÃO README ---
    $cbReadme = New-Object System.Windows.Forms.CheckBox
    $cbReadme.Text = "📄 Gerar README.md DETALHADO e Profissional (Recomendado)"
    $cbReadme.Location = "20, 330"
    $cbReadme.Size = "450, 25"
    $cbReadme.Checked = $true 
    $cbReadme.ForeColor = [System.Drawing.Color]::Gold
    $cbReadme.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $gitForm.Controls.Add($cbReadme)

    # --- SISTEMA DE TOOLTIPS ---
    $toolTipGit = New-Object System.Windows.Forms.ToolTip
    $toolTipGit.IsBalloon = $true
    $toolTipGit.ToolTipIcon = 'Info'
    $toolTipGit.ToolTipTitle = "Ajuda Git"
    $toolTipGit.AutoPopDelay = 10000
    $toolTipGit.InitialDelay = 500

    # --- SELEÇÃO DE BRANCH ---
    $lblBranch = New-Object System.Windows.Forms.Label
    $lblBranch.Text = "🌿 Branch (Ramo):"
    $lblBranch.Location = "20, 530"
    $lblBranch.Size = "120, 20"
    $lblBranch.ForeColor = "White"
    $gitForm.Controls.Add($lblBranch)
    $lblBranch.BringToFront()

    $cmbBranch = New-Object System.Windows.Forms.ComboBox
    $cmbBranch.Location = "140, 527"
    $cmbBranch.Size = "150, 25"
    $cmbBranch.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $cmbBranch.ForeColor = "White"
    $cmbBranch.Items.AddRange(@("main", "master", "dev"))
    $cmbBranch.Text = "main"
    $gitForm.Controls.Add($cmbBranch)
    $cmbBranch.BringToFront()
    
    $toolTipGit.SetToolTip($cmbBranch, "Selecione a 'linha do tempo' do projeto.`nUse 'main' ou 'master' para a versão principal do código.")

    # --- BOTÃO PULL (ATUALIZAR) ---
    $btnPull = New-Object System.Windows.Forms.Button
    $btnPull.Text = "⬇️ ATUALIZAR (Pull)"
    $btnPull.Location = "300, 525"
    $btnPull.Size = "170, 28"
    $btnPull.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204)
    $btnPull.FlatStyle = "Flat"
    $btnPull.ForeColor = "White"
    $btnPull.Add_Click({
            $txtLog.Clear()
            $pasta = $txtPasta.Text
            $branch = $cmbBranch.Text
    
            $addLog = $addGitLog
    
            if (-not (Test-Path "$pasta\.git")) {
                [System.Windows.Forms.MessageBox]::Show("Repositório não encontrado!", "Erro", 'OK', 'Error')
                return
            }

            $gitExe = if (Get-Command "git" -ErrorAction SilentlyContinue) { "git" } else { "git.exe" }
    
            & $addLog "⬇️ Iniciando PULL da branch '$branch'..." "Cyan"
    
            try {
                $pInfo = New-Object System.Diagnostics.ProcessStartInfo
                $pInfo.FileName = $gitExe
                $pInfo.Arguments = "pull origin $branch --allow-unrelated-histories"
                $pInfo.WorkingDirectory = $pasta
                $pInfo.UseShellExecute = $false
                $pInfo.RedirectStandardOutput = $true
                $pInfo.RedirectStandardError = $true
                $pInfo.CreateNoWindow = $true
                $pInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        
                $proc = New-Object System.Diagnostics.Process
                $proc.StartInfo = $pInfo
                $proc.Start() | Out-Null
        
                $output = $proc.StandardOutput.ReadToEnd()
                $errors = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
        
                if ($output) { & $addLog $output "White" }
                if ($errors) { & $addLog $errors "Yellow" }
        
                if ($proc.ExitCode -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Projeto atualizado com sucesso!", "Pull Concluído", 'OK', 'Information')
                    & $addLog "✅ Pull concluído com sucesso!" "Green"
                }
                else {
                    & $addLog "⚠️ Ocorreu um erro ao atualizar." "Red"
                }
            }
            catch {
                & $addLog "Erro fatal: $($_.Exception.Message)" "Red"
            }
        })
    $gitForm.Controls.Add($btnPull)
    $btnPull.BringToFront()

    # --- BOTÃO MERGE ---
    $btnMerge = New-Object System.Windows.Forms.Button
    $btnMerge.Text = "🔀 MESCLAR (Merge)"
    $btnMerge.Location = "300, 560"
    $btnMerge.Size = "170, 28"
    $btnMerge.BackColor = [System.Drawing.Color]::FromArgb(160, 82, 45)
    $btnMerge.FlatStyle = "Flat"
    $btnMerge.ForeColor = "White"
    $btnMerge.Add_Click({
            $txtLog.Clear()
            $pasta = $txtPasta.Text
            $branch = $cmbBranch.Text
            $addLog = $addGitLog
    
            if (-not (Test-Path "$pasta\.git")) {
                [System.Windows.Forms.MessageBox]::Show("Repositório não encontrado!", "Erro", 'OK', 'Error')
                return
            }

            $gitExe = if (Get-Command "git" -ErrorAction SilentlyContinue) { "git" } else { "git.exe" }
            & $addLog "🔀 Iniciando MERGE da branch 'origin/$branch'..." "Yellow"
    
            try {
                $pInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
                    FileName               = $gitExe
                    Arguments              = "merge origin/$branch"
                    WorkingDirectory       = $pasta
                    UseShellExecute        = $false
                    RedirectStandardOutput = $true
                    RedirectStandardError  = $true
                    CreateNoWindow         = $true
                }
                $proc = [System.Diagnostics.Process]::Start($pInfo)
                $out = $proc.StandardOutput.ReadToEnd()
                $err = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
        
                if ($out) { & $addLog $out "White" }
                if ($err) { & $addLog $err "Yellow" }
        
                if ($proc.ExitCode -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("Mesclagem concluída!", "Merge OK", 'OK', 'Information')
                    & $addLog "✅ Merge concluído com sucesso!" "Green"
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show("Erro ou conflito no Merge.", "Erro", 'OK', 'Warning')
                }
            }
            catch { & $addLog "Erro: $($_.Exception.Message)" "Red" }
        })
    $gitForm.Controls.Add($btnMerge)
    $btnMerge.BringToFront()

    # --- BOTÃO FORCE PUSH ---
    $btnForcePush = New-Object System.Windows.Forms.Button
    $btnForcePush.Text = "⚠️ FORÇAR (Force)"
    $btnForcePush.Location = "300, 595"
    $btnForcePush.Size = "170, 28"
    $btnForcePush.BackColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
    $btnForcePush.FlatStyle = "Flat"
    $btnForcePush.ForeColor = "White"
    $btnForcePush.Add_Click({
            $confirm = [System.Windows.Forms.MessageBox]::Show("VOCÊ TEM CERTEZA?`nIsso irá SOBRESCREVER o código no GitHub.", "⚠️ ATENÇÃO: Ação Destrutiva", 'YesNo', 'Warning')
            if ($confirm -eq 'No') { return }

            $txtLog.Clear()
            $pasta = $txtPasta.Text
            $branch = $cmbBranch.Text
            $addLog = $addGitLog
            $gitExe = if (Get-Command "git" -ErrorAction SilentlyContinue) { "git" } else { "git.exe" }

            & $addLog "🚀 Iniciando FORCE PUSH para '$branch'..." "Red"
            try {
                $pInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
                    FileName               = $gitExe
                    Arguments              = "push -f origin $branch"
                    WorkingDirectory       = $pasta
                    UseShellExecute        = $false
                    RedirectStandardOutput = $true
                    RedirectStandardError  = $true
                    CreateNoWindow         = $true
                }
                $proc = [System.Diagnostics.Process]::Start($pInfo)
                $out = $proc.StandardOutput.ReadToEnd()
                $err = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
        
                if ($out) { & $addLog $out "White" }
                if ($err) { & $addLog $err "Yellow" }
                & $addLog "✅ Operação finalizada." "Green"
            }
            catch { & $addLog "Erro: $($_.Exception.Message)" "Red" }
        })
    $gitForm.Controls.Add($btnForcePush)
    $btnForcePush.BringToFront()

    # --- BOTÃO UPLOAD (Principal) ---
    $btnUpload = New-Object System.Windows.Forms.Button
    $btnUpload.Text = "🚀 FAZER UPLOAD (Push)"
    $btnUpload.Location = "20, 560"
    $btnUpload.Size = "270, 60"
    $btnUpload.BackColor = [System.Drawing.Color]::FromArgb(35, 134, 54)
    $btnUpload.FlatStyle = "Flat"
    $btnUpload.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnUpload.Add_Click({
            $txtLog.Clear()
        
            $lblRef = $this.Parent.Controls["lblPushStatus"]
            $pbRef = $this.Parent.Controls["pbPush"]
            $lstIgnoreRef = $this.Parent.Controls["lstIgnore"]
        
            if ($pbRef) { $pbRef.Value = 0 }
            if ($lblRef) { $lblRef.Text = "Status: Iniciando..." }
        
            $pasta = $txtPasta.Text
            $repoUrl = $txtRepo.Text
            $user = $txtUser.Text
            $token = $txtToken.Text
            $commitMsg = $txtCommit.Text
            $genReadme = $cbReadme.Checked
        
            if ($user -match "@") {
                & $addGitLog "ERRO: Use o NOME DE USUÁRIO do GitHub, não o email!" "Red"
                return
            }

            if (!(Test-Path $pasta)) {
                & $addGitLog "ERRO: Pasta não encontrada!" "Red"
                return
            }

            $script:AppConfig['GitHubRepo'] = $repoUrl
            $script:AppConfig['GitHubUser'] = $user
            if ($token) { $script:AppConfig['GitHubToken'] = $token }
            Save-Config

            try {
                Set-Location $pasta
                & $addGitLog "Pasta: $pasta" "White"
            
                if ($genReadme) {
                    & $addGitLog "Gerando README.md..." "Yellow"
                    $dateGen = Get-Date -Format 'yyyy-MM-dd HH:mm'
                
                    $readmeContent = @"
# 🐙 Projeto Git

![PowerShell](https://img.shields.io/badge/PowerShell-7.4+-blue?style=flat-square)

> Projeto gerenciado pelo Git App.

---

## 📖 Visão Geral

Este projeto foi enviado para o GitHub usando o **Git App** (standalone PowerShell tool).

---

## 👨‍💻 Autor

<div align="center">
  <a href="https://www.linkedin.com/in/marcos-ferreira-937165200/">
    <b>👉 Clique aqui para me seguir no LinkedIn</b>
  </a>
</div>

---

<p align="center">
  <sub>Desenvolvido por <b>$user</b></sub><br>
  <sub>Gerado automaticamente em: $dateGen</sub>
</p>
"@
                    [System.IO.File]::WriteAllText("$pasta\README.md", $readmeContent)
                    & $addGitLog "README.md criado!" "Green"
                }

                $gitPath = "git"
                $gitFound = $false
            
                if (Get-Command "git" -ErrorAction SilentlyContinue) {
                    $gitPath = "git"
                    $gitFound = $true
                }
                else {
                    $commonPaths = @(
                        "$env:ProgramFiles\Git\cmd\git.exe",
                        "$env:ProgramFiles\Git\bin\git.exe",
                        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
                    )
                
                    foreach ($p in $commonPaths) {
                        if (Test-Path $p) {
                            $gitPath = $p
                            $gitFound = $true
                            & $addGitLog "Git encontrado em: $p" "Cyan"
                            break
                        }
                    }
                }
            
                if (-not $gitFound) {
                    & $addGitLog "ERRO CRÍTICO: Git não encontrado!" "Red"
                    [System.Windows.Forms.MessageBox]::Show("O software 'Git' não foi encontrado.", "Git Não Instalado", 'OK', 'Error')
                    return
                }
            
                & $gitPath --version 2>&1 | ForEach-Object { & $addGitLog $_ "Cyan" }

                if (Test-Path ".git") {
                    & $addGitLog "Limpando histórico antigo..." "Yellow"
                    Remove-Item -Path ".git" -Recurse -Force -ErrorAction SilentlyContinue
                }
            
                & $addGitLog "Inicializando repositório..." "Yellow"
                & $gitPath init 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }

                $remotes = & $gitPath remote -v 2>&1
                if ($remotes -notmatch "origin") {
                    & $gitPath remote add origin $repoUrl 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }
                }
                else {
                    & $gitPath remote set-url origin $repoUrl 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }
                }

                if ($user -and $token) {
                    $cleanRepoUrl = $repoUrl -replace "https://[^@]+@", "https://"
                    $encUser = [Uri]::EscapeDataString($user)
                    $encToken = [Uri]::EscapeDataString($token)
                    $repoWithCreds = $cleanRepoUrl -replace "https://", "https://${encUser}:${encToken}@"
                
                    & $gitPath remote remove origin 2>&1 | Out-Null
                    & $gitPath remote add origin $repoWithCreds 2>&1 | Out-Null
                
                    & $addGitLog "Credenciais configuradas" "Green"
                }

                $currentName = & $gitPath config user.name 2>&1
                if (!$currentName) {
                    & $gitPath config user.name "$user"
                }

                $currentEmail = & $gitPath config user.email 2>&1
                if (!$currentEmail) {
                    $dummyEmail = "$user@users.noreply.github.com"
                    & $gitPath config user.email "$dummyEmail"
                }

                $ignoreContent = @"
# Arquivos grandes
*.exe
*.dll
data/downloads/

# Credenciais
github_tokens.json
data/config.json

# Arquivos ignorados pelo usuário
"@
                $checkedItems = $lstIgnoreRef.CheckedItems
                if ($checkedItems -and $checkedItems.Count -gt 0) {
                    foreach ($item in $checkedItems) {
                        $fileName = if ($item.Tag) { $item.Tag } else { ($item.Text -split ' \(' | Select-Object -First 1) }
                        $fileName = $fileName.Trim()
                        if ($fileName) {
                            $ignoreContent += "`n$fileName"
                        }
                    }
                    & $addGitLog "$($checkedItems.Count) arquivo(s) adicionados ao .gitignore" "Cyan"
                }
                $ignoreFile = "$pasta\.gitignore"
                [System.IO.File]::WriteAllText($ignoreFile, $ignoreContent)
                & $addGitLog ".gitignore configurado" "Cyan"

                & $addGitLog "Adicionando arquivos..." "Yellow"
                if ($pbRef) { $pbRef.Value = 30 }
                & $gitPath add -A 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }
            
                & $addGitLog "Criando commit..." "Yellow"
                if ($pbRef) { $pbRef.Value = 50 }
                & $gitPath commit -m "$commitMsg" --allow-empty 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }
            
                & $addGitLog "Enviando para GitHub..." "Yellow"
                if ($lblRef) { $lblRef.Text = "Enviando para GitHub..." }
                if ($pbRef) { $pbRef.Value = 70 }
                & $gitPath push -u origin HEAD --force 2>&1 | ForEach-Object { & $addGitLog $_ "Gray" }
            
                if ($pbRef) { $pbRef.Value = 100 }

                & $addGitLog "========================================" "Green"
                & $addGitLog "✅ UPLOAD CONCLUÍDO COM SUCESSO!" "Green"
                & $addGitLog "========================================" "Green"
                if ($lblRef) { $lblRef.Text = "✅ Concluído!" }
                [System.Windows.Forms.MessageBox]::Show("Upload concluído com sucesso!", "Sucesso", 'OK', 'Information')

                & $gitPath remote set-url origin $repoUrl 2>&1 | Out-Null
            }
            catch {
                & $addGitLog "ERRO: $_" "Red"
            }
        })
    $gitForm.Controls.Add($btnUpload)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Fechar"
    $btnClose.Location = "485, 595"
    $btnClose.Size = "75, 28"
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $btnClose.FlatStyle = "Flat"
    $btnClose.Add_Click({ $gitForm.Close() })
    $gitForm.Controls.Add($btnClose)

    $lblDica = New-Object System.Windows.Forms.Label
    $lblDica.Text = "Dica: Use um Personal Access Token"
    $lblDica.Location = "20, 625"
    $lblDica.Size = "200, 20"
    $lblDica.Font = New-Object System.Drawing.Font("Segoe UI", 7)
    $lblDica.ForeColor = [System.Drawing.Color]::Gray
    $gitForm.Controls.Add($lblDica)
    
    # Carregar arquivos na inicialização
    if (Test-Path $txtPasta.Text) {
        $files = Get-ChildItem -Path $txtPasta.Text -File -ErrorAction SilentlyContinue | Select-Object -First 50
        foreach ($f in $files) {
            $sizeMB = [math]::Round($f.Length / 1MB, 2)
            $sizeWarning = if ($sizeMB -ge 100) { " ⚠️" } else { "" }
            $displayText = "{0} ({1} MB){2}" -f $f.Name, $sizeMB, $sizeWarning
            $lstIgnore.Items.Add($displayText, $false)
        }
        for ($i = 0; $i -lt $lstIgnore.Items.Count; $i++) {
            $item = $lstIgnore.Items[$i]
            if ($item -match '\.(exe|dll|mp3|wav|mp4|mkv|zip|rar|7z)' -or $item -match '⚠️') {
                $item.Checked = $true
            }
        }
    }

    [void]$gitForm.ShowDialog()
}

# ============================
# MAIN EXECUTION
# ============================
Show-GitHubUpload

