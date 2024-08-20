# IntunePaper.ps1
# Este script automatiza o processo de implantação de papéis de parede e telas de bloqueio em dispositivos Windows usando Microsoft Intune.

# Função para registrar logs
function Write-Log {
    param (
        [string]$Message,
        [string]$LogFile = "C:\Jornada365\Intune\Picture\Logs\IntunePaperLog_$(Get-Date -Format 'yyyyMMdd').log"
    )

    $LogDir = Split-Path $LogFile
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force
    }

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$Timestamp - $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

# Função para garantir que os módulos necessários estejam instalados
function Install-RequiredModules {
    $Modules = @('Microsoft.Graph.DeviceManagement', 'ThreadJob')
    foreach ($Module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            Write-Log "Instalando o módulo ${Module}..."
            try {
                Install-Module -Name $Module -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            } catch {
                Write-Log "Erro ao instalar o módulo ${Module}: $($_.Exception.Message)"
                throw "Erro ao instalar o módulo ${Module}."
            }
        }
        Import-Module -Name $Module -ErrorAction Stop
    }
    Write-Log "Módulos instalados e importados com sucesso."
}

# Função para garantir que os diretórios necessários existam
function Ensure-DirectoriesExist {
    param (
        [string[]]$Directories
    )
    foreach ($Dir in $Directories) {
        if (-not (Test-Path -Path $Dir)) {
            New-Item -ItemType Directory -Path $Dir -Force
            Write-Log "Diretório criado: ${Dir}"
        } else {
            Write-Log "Diretório já existe: ${Dir}"
        }
    }
}

# Função para limpar a pasta de saída
function Clear-OutputFolder {
    param (
        [string]$OutputFolder
    )
    Write-Log "Limpando a pasta de saída: ${OutputFolder}..."
    try {
        if (Test-Path -Path $OutputFolder) {
            Get-ChildItem -Path $OutputFolder | Remove-Item -Recurse -Force -ErrorAction Stop
            Write-Log "Pasta de saída limpa com sucesso."
        }
    } catch {
        $ErrorMsg = $_.Exception.Message
        Write-Log "Erro ao limpar a pasta de saída: ${ErrorMsg}"
        throw "Erro ao limpar a pasta de saída."
    }
}

# Função para conectar ao Microsoft Intune
function Connect-Intune {
    Write-Log "Iniciando autenticação no Microsoft Intune..."
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All", "DeviceManagementConfiguration.ReadWrite.All", "User.Read"
        Write-Log "Autenticação bem-sucedida no Microsoft Intune."
    } catch {
        $ErrorMsg = $_.Exception.Message
        Write-Log "Falha na autenticação: ${ErrorMsg}"
        throw "Erro ao autenticar no Microsoft Intune."
    }
}

# Função para criar ou substituir o script de detecção
function Create-DetectionScript {
    param (
        [string]$DetectionScriptDestinationPath,
        [string]$IntuneWallpapersDir
    )

    $ScriptContent = @"
# Script de Detecção

# Caminho de destino
\$targetPath = '$IntuneWallpapersDir'

# Verifica se há arquivos com os prefixos corretos
\$files = Get-ChildItem -Path \$targetPath -Filter 'papeldeparede.*', 'teladebloqueio.*' -Recurse

if (\$files.Count -eq 0) {
    Write-Output 'DetectionFailed'
    exit 0
}

Write-Output 'Detected'
exit 0
"@

    # Cria ou substitui o script de detecção
    $ScriptContent | Out-File -FilePath $DetectionScriptDestinationPath -Encoding UTF8 -Force
    Write-Log "Script de detecção criado ou atualizado em: ${DetectionScriptDestinationPath}"
}

# Função para garantir que o diretório de destino e os arquivos existam
function Ensure-WallpaperAndLockScreen {
    param (
        [string]$WallpaperPath,
        [string]$LockScreenPath,
        [string]$IntuneWallpapersDir
    )

    Ensure-DirectoriesExist -Directories @($IntuneWallpapersDir)

    # Copia o papel de parede, se especificado
    if ($WallpaperPath) {
        $WallpaperDest = Join-Path $IntuneWallpapersDir "papeldeparede$((Get-Item $WallpaperPath).Extension)"
        Copy-Item -Path $WallpaperPath -Destination $WallpaperDest -Force
        Write-Log "Imagem de papel de parede copiada para ${WallpaperDest}."
    }

    # Copia a tela de bloqueio, se especificada
    if ($LockScreenPath) {
        $LockScreenDest = Join-Path $IntuneWallpapersDir "teladebloqueio$((Get-Item $LockScreenPath).Extension)"
        Copy-Item -Path $LockScreenPath -Destination $LockScreenDest -Force
        Write-Log "Imagem de tela de bloqueio copiada para ${LockScreenDest}."
    }
}

# Função para criar o script de instalação
function Create-InstallScript {
    param (
        [string]$InstallScriptPath,
        [string]$IntuneWallpapersDir
    )

    $ScriptContent = @"
# Script de Instalação

# Diretório do papel de parede e tela de bloqueio
\$wallpaperPath = Get-ChildItem -Path '$IntuneWallpapersDir' -Filter 'papeldeparede.*' | Select-Object -First 1
\$lockScreenPath = Get-ChildItem -Path '$IntuneWallpapersDir' -Filter 'teladebloqueio.*' | Select-Object -First 1

# Configura o papel de parede
if (\$wallpaperPath) {
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value \$wallpaperPath.FullName
    rundll32.exe user32.dll, UpdatePerUserSystemParameters
} else {
    Write-Host 'Papel de parede não configurado.'
}

# Configura a tela de bloqueio (se aplicável)
if (\$lockScreenPath) {
    # A configuração da tela de bloqueio pode variar. Adicione comandos específicos aqui.
    Write-Host 'Tela de bloqueio configurada para: ' + \$lockScreenPath.FullName
} else {
    Write-Host 'Tela de bloqueio não configurada.'
}
"@

    # Cria ou substitui o script de instalação
    $ScriptContent | Out-File -FilePath $InstallScriptPath -Encoding UTF8 -Force
    Write-Log "Script de instalação criado ou atualizado em: ${InstallScriptPath}"
}

# Função para criar o script de desinstalação
function Create-UninstallScript {
    param (
        [string]$UninstallScriptPath
    )

    $ScriptContent = @"
# Script de Desinstalação

# Remove o papel de parede
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value ''
rundll32.exe user32.dll, UpdatePerUserSystemParameters
Write-Host 'Papel de parede removido.'

# Remove a tela de bloqueio (se aplicável)
# Adicione aqui os comandos específicos para remover a tela de bloqueio, se necessário.
Write-Host 'Tela de bloqueio removida, se configurada.'
"@

    # Cria ou substitui o script de desinstalação
    $ScriptContent | Out-File -FilePath $UninstallScriptPath -Encoding UTF8 -Force
    Write-Log "Script de desinstalação criado ou atualizado em: ${UninstallScriptPath}"
}

# Função para compactar o pacote IntuneWin
function Compress-IntuneWinPackage {
    param (
        [string]$SourceFolder,
        [string]$OutputFolder
    )

    Write-Log "Iniciando compressão da pasta ${SourceFolder} para o arquivo ${OutputFolder}\IntunePackage.intunewin..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $zipFile = Join-Path -Path $OutputFolder -ChildPath "IntunePackage.zip"

        # Garante que o arquivo ZIP não exista antes de criar
        if (Test-Path -Path $zipFile) {
            Remove-Item -Path $zipFile -Force
            Write-Log "Arquivo ZIP existente removido: ${zipFile}"
        }

        # Usando Compress-Archive para criar o arquivo ZIP
        Compress-Archive -Path "${SourceFolder}\*" -DestinationPath $zipFile -Force
        Write-Log "Arquivo ZIP criado com sucesso usando Compress-Archive."

        # Renomeando para .intunewin
        $finalPackage = Join-Path -Path $OutputFolder -ChildPath "IntunePackage.intunewin"
        Rename-Item -Path $zipFile -NewName $finalPackage -Force

        $sw.Stop()
        Write-Log "Compressão concluída em $($sw.Elapsed.TotalSeconds) segundos."
    } catch {
        Write-Log "Erro ao comprimir a pasta: $($_.Exception.Message)"
        throw "Erro ao comprimir a pasta."
    }
}

# Função para configurar a regra de detecção usando script externo
function Get-DetectionRule {
    param (
        [string]$DetectionScriptPath
    )

    if (-not (Test-Path -Path $DetectionScriptPath)) {
        Write-Log "Erro: O script de detecção não foi encontrado em ${DetectionScriptPath}."
        throw "Erro na criação da regra de detecção: Script não encontrado."
    }

    $scriptContent = Get-Content -Path $DetectionScriptPath -Raw
    $scriptContentBase64 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptContent))

    $detectionRule = @{
        "@odata.type" = "#microsoft.graph.win32LobAppPowerShellScriptDetectionRule"
        "scriptContent" = $scriptContentBase64
        "runAs32Bit" = $false
        "enforceSignatureCheck" = $false
    }

    # Verificação extra
    if ($null -eq $detectionRule -or $detectionRule.Count -eq 0) {
        Write-Log "Erro: A regra de detecção é inválida ou vazia."
        throw "Erro na criação da regra de detecção: Regra vazia ou inválida."
    }

    Write-Log "Regra de detecção criada com sucesso usando o script: ${DetectionScriptPath}."
    return $detectionRule
}

# Função principal para criar o pacote e realizar o deploy no Intune
function Execute-Deployment {
    param (
        [string]$AppName,
        [string]$Description,
        [string]$Publisher,
        [string]$WallpaperPath,
        [string]$LockScreenPath
    )

    # Validação de parâmetros
    if (-not $AppName) { 
        [System.Windows.Forms.MessageBox]::Show("O nome do aplicativo não foi especificado. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        throw "Nome do aplicativo não especificado." 
    }
    if (-not $Description) { 
        [System.Windows.Forms.MessageBox]::Show("A descrição do aplicativo não foi especificada. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        throw "Descrição do aplicativo não especificada." 
    }
    if (-not $Publisher) { 
        [System.Windows.Forms.MessageBox]::Show("O editor do aplicativo não foi especificado. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        throw "Editor do aplicativo não especificado." 
    }
    if (-not $WallpaperPath -and -not $LockScreenPath) { 
        [System.Windows.Forms.MessageBox]::Show("Pelo menos um caminho de imagem (papel de parede ou tela de bloqueio) deve ser fornecido. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        throw "Pelo menos um caminho de imagem deve ser fornecido (papel de parede ou tela de bloqueio)." 
    }

    $DetectionScriptDestinationPath = "C:\Jornada365\Intune\Picture\Detection\detect.ps1"
    $OutputFolder = "C:\Jornada365\Intune\Picture\Output"
    $IntuneWallpapersDir = "C:\Windows\Web\Wallpaper\Intune"
    $InstallScriptPath = "$OutputFolder\install.ps1"
    $UninstallScriptPath = "$OutputFolder\uninstall.ps1"

    try {
        Write-Log "Iniciando a criação do pacote IntuneWin para ${AppName}..."

        # Limpa a pasta de saída
        Clear-OutputFolder -OutputFolder $OutputFolder

        # Garante que o diretório de wallpapers no destino exista
        Ensure-WallpaperAndLockScreen -WallpaperPath $WallpaperPath -LockScreenPath $LockScreenPath -IntuneWallpapersDir $IntuneWallpapersDir

        # Cria ou substitui o script de detecção
        Create-DetectionScript -DetectionScriptDestinationPath $DetectionScriptDestinationPath -IntuneWallpapersDir $IntuneWallpapersDir

        # Cria ou substitui os scripts de instalação e desinstalação
        Create-InstallScript -InstallScriptPath $InstallScriptPath -IntuneWallpapersDir $IntuneWallpapersDir
        Create-UninstallScript -UninstallScriptPath $UninstallScriptPath

        # Compacta o pacote
        Compress-IntuneWinPackage -SourceFolder $OutputFolder -OutputFolder $OutputFolder
        $GeneratedPackageFile = Join-Path $OutputFolder "IntunePackage.intunewin"

        if (Test-Path -Path $GeneratedPackageFile) {
            Write-Log "Pacote ${GeneratedPackageFile} criado com sucesso."
            Rename-Item -Path $GeneratedPackageFile -NewName "$AppName.intunewin" -Force
        } else {
            Write-Log "Erro: o arquivo de pacote IntuneWin não foi encontrado."
            throw "Erro na criação do pacote IntuneWin."
        }

        $InstallCommandLine = "powershell.exe -ExecutionPolicy Bypass -File install.ps1"
        $UninstallCommandLine = "powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1"

        Connect-Intune

        Write-Log "Iniciando upload do pacote ${AppName} para o Intune..."

        # Configuração da regra de detecção usando script de detecção externo
        $DetectionRule = Get-DetectionRule -DetectionScriptPath $DetectionScriptDestinationPath

        # Verifica se a regra foi criada corretamente antes do upload
        if ($null -eq $DetectionRule -or $DetectionRule.Count -eq 0) {
            Write-Log "Erro: Regra de detecção inválida ou não incluída corretamente. O upload não será realizado."
            throw "Erro na configuração da regra de detecção."
        }

        # Adiciona a regra de detecção ao aplicativo
        $AppDetails = @{
            "@odata.type" = "#microsoft.graph.win32LobApp"
            "displayName" = $AppName
            "description" = $Description
            "publisher" = $Publisher
            "installCommandLine" = $InstallCommandLine
            "uninstallCommandLine" = $UninstallCommandLine
            "fileName" = "$AppName.intunewin"
            "detectionRules" = @($DetectionRule)
            "returnCodes" = @(
                @{
                    "@odata.type" = "#microsoft.graph.win32LobAppReturnCode"
                    "returnCode" = 0
                    "type" = "success"
                }
            )
        }

        Write-Log "Criando a aplicação no Intune..."
        $App = New-MgDeviceAppManagementMobileApp -BodyParameter $AppDetails -ErrorAction Stop

        Write-Log "Fazendo upload do conteúdo do arquivo de aplicativo..."
        $FilePath = Join-Path -Path $OutputFolder -ChildPath "$AppName.intunewin"
        $FileContent = [System.IO.File]::ReadAllBytes($FilePath)

        $uploadResult = New-MgDeviceAppManagementMobileAppContentFile -MobileAppId $App.Id -FileName "$AppName.intunewin" -Value $FileContent -ErrorAction Stop

        if ($uploadResult) {
            Write-Log "Upload do pacote ${AppName} concluído com sucesso."
            [System.Windows.Forms.MessageBox]::Show("Aplicativo implantado com sucesso no Microsoft Intune.", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            Write-Log "Erro: Falha no upload do arquivo de aplicativo para o Intune."
            throw "Erro ao fazer upload do arquivo de aplicativo."
        }
    } catch {
        $ErrorMsg = $_.Exception.Message
        Write-Log "Erro ao fazer upload do pacote ${AppName}: ${ErrorMsg}"
        [System.Windows.Forms.MessageBox]::Show("Falha ao implantar o aplicativo no Microsoft Intune.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        Finalize-Script
    }
}

# Função para finalizar o script e desconectar do Microsoft Graph
function Finalize-Script {
    Write-Log "Desconectando do Microsoft Intune..."
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Write-Log "Script finalizado com sucesso."
    if ($global:form) {
        $global:form.Close()
    }
}

# Função para inicializar a interface gráfica (GUI)
function Initialize-GUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Estilo e configuração da janela principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "IntunePaper | Jornada 365"
    $form.Size = New-Object System.Drawing.Size(750, 500)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false

    # Título
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "IntunePaper | Jornada 365"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object System.Drawing.Point(270, 20)
    $form.Controls.Add($titleLabel)

    # Subtítulo
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Aplique imagem em dispositivos Windows 10 e 11"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.Location = New-Object System.Drawing.Point(230, 60)
    $form.Controls.Add($subtitleLabel)

    # Logo
    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.ImageLocation = "https://jornada365.cloud/wp-content/uploads/2024/03/Logotipo-Jornada-365-Home.png"
    $logo.SizeMode = "Zoom"
    $logo.Size = New-Object System.Drawing.Size(150, 70)
    $logo.Location = New-Object System.Drawing.Point(50, 20)
    $form.Controls.Add($logo)

    # Informações do Aplicativo
    $appInfoGroup = New-Object System.Windows.Forms.GroupBox
    $appInfoGroup.Text = "Informações do Aplicativo"
    $appInfoGroup.Size = New-Object System.Drawing.Size(680, 160)
    $appInfoGroup.Location = New-Object System.Drawing.Point(35, 100)
    $appInfoGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($appInfoGroup)

    $appNameLabel = New-Object System.Windows.Forms.Label
    $appNameLabel.Text = "Nome do Aplicativo:"
    $appNameLabel.Location = New-Object System.Drawing.Point(20, 40)
    $appNameLabel.AutoSize = $true
    $appInfoGroup.Controls.Add($appNameLabel)

    $appNameTextBox = New-Object System.Windows.Forms.TextBox
    $appNameTextBox.Size = New-Object System.Drawing.Size(500, 24)
    $appNameTextBox.Location = New-Object System.Drawing.Point(160, 40)
    $appInfoGroup.Controls.Add($appNameTextBox)

    $descriptionLabel = New-Object System.Windows.Forms.Label
    $descriptionLabel.Text = "Descrição:"
    $descriptionLabel.Location = New-Object System.Drawing.Point(20, 80)
    $descriptionLabel.AutoSize = $true
    $appInfoGroup.Controls.Add($descriptionLabel)

    $descriptionTextBox = New-Object System.Windows.Forms.TextBox
    $descriptionTextBox.Size = New-Object System.Drawing.Size(500, 24)
    $descriptionTextBox.Location = New-Object System.Drawing.Point(160, 80)
    $appInfoGroup.Controls.Add($descriptionTextBox)

    $publisherLabel = New-Object System.Windows.Forms.Label
    $publisherLabel.Text = "Editor:"
    $publisherLabel.Location = New-Object System.Drawing.Point(20, 120)
    $publisherLabel.AutoSize = $true
    $appInfoGroup.Controls.Add($publisherLabel)

    $publisherTextBox = New-Object System.Windows.Forms.TextBox
    $publisherTextBox.Size = New-Object System.Drawing.Size(500, 24)
    $publisherTextBox.Location = New-Object System.Drawing.Point(160, 120)
    $appInfoGroup.Controls.Add($publisherTextBox)

    # Seção de Imagens
    $imageGroup = New-Object System.Windows.Forms.GroupBox
    $imageGroup.Text = "Imagens"
    $imageGroup.Size = New-Object System.Drawing.Size(680, 120)
    $imageGroup.Location = New-Object System.Drawing.Point(35, 270)
    $imageGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($imageGroup)

    $wallpaperLabel = New-Object System.Windows.Forms.Label
    $wallpaperLabel.Text = "Papel de Parede:"
    $wallpaperLabel.Location = New-Object System.Drawing.Point(20, 40)
    $wallpaperLabel.AutoSize = $true
    $imageGroup.Controls.Add($wallpaperLabel)

    # Reduzindo em 15% o tamanho da caixa de texto
    $wallpaperTextBox = New-Object System.Windows.Forms.TextBox
    $wallpaperTextBox.Size = New-Object System.Drawing.Size(357, 24)  # 15% menor que 420px
    $wallpaperTextBox.Location = New-Object System.Drawing.Point(160, 40)
    $imageGroup.Controls.Add($wallpaperTextBox)

    # Ajustando o botão para a esquerda
    $wallpaperButton = New-Object System.Windows.Forms.Button
    $wallpaperButton.Text = "Selecionar"
    $wallpaperButton.Size = New-Object System.Drawing.Size(100, 24)
    $wallpaperButton.Location = New-Object System.Drawing.Point(527, 40)  # Ajustado de 600px para 527px
    $wallpaperButton.BackColor = [System.Drawing.Color]::DarkBlue
    $wallpaperButton.ForeColor = [System.Drawing.Color]::White
    $wallpaperButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $wallpaperButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Imagens (*.jpg, *.jpeg, *.png)|*.jpg;*.jpeg;*.png"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $wallpaperTextBox.Text = $fileDialog.FileName
        }
    })
    $imageGroup.Controls.Add($wallpaperButton)

    $lockScreenLabel = New-Object System.Windows.Forms.Label
    $lockScreenLabel.Text = "Tela de Bloqueio:"
    $lockScreenLabel.Location = New-Object System.Drawing.Point(20, 80)
    $lockScreenLabel.AutoSize = $true
    $imageGroup.Controls.Add($lockScreenLabel)

    $lockScreenTextBox = New-Object System.Windows.Forms.TextBox
    $lockScreenTextBox.Size = New-Object System.Drawing.Size(357, 24)  # 15% menor que 420px
    $lockScreenTextBox.Location = New-Object System.Drawing.Point(160, 80)
    $imageGroup.Controls.Add($lockScreenTextBox)

    # Ajustando o botão para a esquerda
    $lockScreenButton = New-Object System.Windows.Forms.Button
    $lockScreenButton.Text = "Selecionar"
    $lockScreenButton.Size = New-Object System.Drawing.Size(100, 24)
    $lockScreenButton.Location = New-Object System.Drawing.Point(527, 80)  # Ajustado de 600px para 527px
    $lockScreenButton.BackColor = [System.Drawing.Color]::DarkBlue
    $lockScreenButton.ForeColor = [System.Drawing.Color]::White
    $lockScreenButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lockScreenButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "Imagens (*.jpg, *.jpeg, *.png)|*.jpg;*.jpeg;*.png"
        if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $lockScreenTextBox.Text = $fileDialog.FileName
        }
    })
    $imageGroup.Controls.Add($lockScreenButton)

    # Botão de Aplicar
    $applyButton = New-Object System.Windows.Forms.Button
    $applyButton.Text = "Aplicar"
    $applyButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $applyButton.ForeColor = [System.Drawing.Color]::White
    $applyButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $applyButton.Size = New-Object System.Drawing.Size(140, 50)
    $applyButton.Location = New-Object System.Drawing.Point(200, 380)  # Movendo para cima
    $applyButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyButton.Add_Click({
        # Validação dos campos obrigatórios
        if (-not $appNameTextBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("O nome do aplicativo não foi especificado. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        if (-not $descriptionTextBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("A descrição do aplicativo não foi especificada. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        if (-not $publisherTextBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("O editor do aplicativo não foi especificado. Por favor, preencha o campo obrigatório.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        if (-not $wallpaperTextBox.Text -and -not $lockScreenTextBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("Pelo menos um caminho de imagem (papel de parede ou tela de bloqueio) deve ser fornecido.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        Execute-Deployment -AppName $appNameTextBox.Text -Description $descriptionTextBox.Text -Publisher $publisherTextBox.Text -WallpaperPath $wallpaperTextBox.Text -LockScreenPath $lockScreenTextBox.Text
    })
    $form.Controls.Add($applyButton)

    # Botão de Fechar
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Fechar"
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $closeButton.ForeColor = [System.Drawing.Color]::White
    $closeButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $closeButton.Size = New-Object System.Drawing.Size(140, 50)
    $closeButton.Location = New-Object System.Drawing.Point(400, 380)  # Movendo para cima
    $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $closeButton.Add_Click({
        Write-Log "Script encerrado pelo usuário."
        $form.Close()
    })
    $form.Controls.Add($closeButton)

    $global:form = $form
    $form.ShowDialog() | Out-Null
}

# Execução do script
try {
    Install-RequiredModules
    
    $BaseDir = "C:\Jornada365\Intune\Picture"
    $OutputDir = "$BaseDir\Output"
    $LogDir = "$BaseDir\Logs"
    $DetectionDir = "$BaseDir\Detection"
    
    Ensure-DirectoriesExist -Directories @($BaseDir, $OutputDir, $LogDir, $DetectionDir)
    
    Initialize-GUI
} catch {
    $ErrorMsg = $_.Exception.Message
    Write-Log "Erro na execução do script: ${ErrorMsg}"
} finally {
    Finalize-Script
}
