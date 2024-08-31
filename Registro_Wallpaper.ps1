# Jornada 365 | IntunePaper
# Script para aplicar Papel de Parede e Tela de Bloqueio
# Pode ser implantado no Windows 10 e 11 Pro via Intune
# Editor: Sérgio Sant'Ana Júnior - https://jornada365.cloud
#------------------------------------------------------------------------####

# Caminho para as imagens do Papel de Parede e Tela de Bloqueio
$ImagePath = 'C:\Windows\Web\Wallpaper\Intune\wallpaper.jpg'      # Caminho da imagem do Papel de Parede
$LockScreenImagePath = 'C:\Windows\Web\Wallpaper\Intune\lockscreen.jpg'  # Caminho da imagem da Tela de Bloqueio

# Caminho do Registro para as configurações do PersonalizationCSP
$RegKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

# Definições das chaves do Registro para as configurações de Papel de Parede e Tela de Bloqueio
$DesktopPath = "DesktopImagePath"
$DesktopStatus = "DesktopImageStatus"
$DesktopUrl = "DesktopImageUrl"
$LockScreenPath = "LockScreenImagePath"
$LockScreenStatus = "LockScreenImageStatus"
$LockScreenUrl = "LockScreenImageUrl"

# Valores a serem aplicados nas chaves do Registro
$StatusValue = 1 # Valor indicando que as imagens estão ativas
$DesktopImageValue = $ImagePath # Caminho da imagem do Papel de Parede
$LockScreenImageValue = $LockScreenImagePath # Caminho da imagem da Tela de Bloqueio

# Verifica se o caminho do Registro existe
if (!(Test-Path $RegKeyPath)) {
    # Se o caminho não existir, cria o caminho no Registro
    New-Item -Path $RegKeyPath -Force | Out-Null
    
    # Cria e aplica todas as configurações de Papel de Parede e Tela de Bloqueio
    New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
} else {
    # Se o caminho do Registro já existir, apenas atualiza as configurações
    New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
}

# Reinicia o explorer.exe para que as novas configurações sejam aplicadas
Stop-Process -Name explorer -Force

# Limpa o log de erros do PowerShell antes de sair
$error.Clear()
