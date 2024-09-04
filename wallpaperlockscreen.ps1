<#
    IntunePaper | Jornada 365
    Script para aplicar papel de parede e tela de bloqueio via Intune.
    Adaptado para funcionar corretamente no Microsoft Intune
    Autor: Sergio Sant'Ana Junior
    Versao: 3.8
    Compativel com PowerShell 5.x e 7.x, Windows 10 e Windows 11
    Ultima modificacao: 04/09/2024
#>

# ============================ CONFIGURACOES ============================
$directoryPath = "C:\ProgramData\Pictures\Intune"  # Mudado para ProgramData para ser acessível no contexto SYSTEM
$wallpaperUrl = "https://raw.githubusercontent.com/sesantanajr/wallpaper/main/wallpaper.png"
$lockScreenUrl = "https://raw.githubusercontent.com/sesantanajr/wallpaper/main/lockscreen.png"
$wallpaperPath = "$directoryPath\wallpaper.png"
$lockScreenPath = "$directoryPath\lockscreen.png"
$lockScreenRegKey = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization"
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
$spotlightRegKey = "HKLM:\Software\Policies\Microsoft\Windows\CloudContent"
$maxRetries = 3
$retryDelay = 5

# Valores para o registro
$DesktopStatus = "DesktopImageStatus"
$LockScreenStatus = "LockScreenImageStatus"
$DesktopPathReg = "DesktopImagePath"
$DesktopUrlReg = "DesktopImageUrl"
$LockScreenPathReg = "LockScreenImagePath"
$LockScreenUrlReg = "LockScreenImageUrl"
$StatusValue = 1
$DesktopImageValue = $wallpaperPath
$LockScreenImageValue = $lockScreenPath

# ============================ FUNCOES ============================

# Funcao para garantir a criacao do diretorio e baixar as imagens de forma robusta
function Ensure-DirectoryAndDownloadImages {
    if (-Not (Test-Path -Path $directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force
        Write-Host "Diretorio criado: $directoryPath"
    } else {
        Write-Host "Diretorio ja existe: $directoryPath"
    }

    # Remover imagens existentes, se necessario
    if (Test-Path -Path $wallpaperPath) { Remove-Item -Path $wallpaperPath -Force }
    if (Test-Path -Path $lockScreenPath) { Remove-Item -Path $lockScreenPath -Force }

    # Tentar baixar as imagens
    try {
        Write-Host "Baixando imagens de papel de parede e tela de bloqueio..."
        Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperPath -UseBasicParsing
        Invoke-WebRequest -Uri $lockScreenUrl -OutFile $lockScreenPath -UseBasicParsing

        if (-Not (Test-Path -Path $wallpaperPath)) { throw "Erro ao baixar o papel de parede." }
        if (-Not (Test-Path -Path $lockScreenPath)) { throw "Erro ao baixar a tela de bloqueio." }

        Write-Host "Imagens baixadas com sucesso."
    } catch {
        Write-Error "Erro ao baixar as imagens: $_"
        exit 1
    }
}

# Funcao para desativar o Windows Spotlight
function Disable-WindowsSpotlight {
    Write-Host "Desativando Windows Spotlight..."

    # Verifica se a chave de registro existe, e cria se necessário
    if (-Not (Test-Path $spotlightRegKey)) {
        New-Item -Path $spotlightRegKey -Force | Out-Null
        Write-Host "Chave de registro criada: $spotlightRegKey"
    }

    # Desativar Windows Spotlight via registro
    Set-ItemProperty -Path $spotlightRegKey -Name 'DisableWindowsConsumerFeatures' -Value 1
    Set-ItemProperty -Path $spotlightRegKey -Name 'DisableWindowsSpotlightFeatures' -Value 1
    Set-ItemProperty -Path $spotlightRegKey -Name 'DisableWindowsSpotlightOnActionCenter' -Value 1
    Set-ItemProperty -Path $spotlightRegKey -Name 'DisableWindowsSpotlightOnLockScreen' -Value 1
    Set-ItemProperty -Path $spotlightRegKey -Name 'DisableWindowsSpotlightSuggestions' -Value 1
    Write-Host "Windows Spotlight desativado."
}

# Funcao para forcar a atualizacao do papel de parede usando a API do Windows
function Force-WallpaperUpdate {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        public const int SPI_SETDESKWALLPAPER = 20;
        public const int SPIF_UPDATEINIFILE = 0x01;
        public const int SPIF_SENDCHANGE = 0x02;
    }
"@
    [Wallpaper]::SystemParametersInfo([Wallpaper]::SPI_SETDESKWALLPAPER, 0, $wallpaperPath, [Wallpaper]::SPIF_UPDATEINIFILE -bor [Wallpaper]::SPIF_SENDCHANGE)
}

# Funcao para aplicar o papel de parede via registro do Windows
function Apply-WallpaperRegistry {
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Write-Host "Aplicando papel de parede via registro (Tentativa $($i+1) de $maxRetries)..."
            
            # Definir o papel de parede no registro
            Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\Personalization' -Name 'WallPaper' -Value $wallpaperPath

            # Forçar a atualização do papel de parede
            Force-WallpaperUpdate
            Start-Sleep -Seconds 2
            Write-Host "Papel de parede aplicado com sucesso via registro do Windows."

            break
        } catch {
            Write-Error "Erro ao aplicar o papel de parede via registro: $_"
            if ($i -lt $maxRetries - 1) { Start-Sleep -Seconds $retryDelay }
            else { Write-Error "Falha ao aplicar o papel de parede apos $maxRetries tentativas."; exit 1 }
        }
    }
}

# Funcao para aplicar a tela de bloqueio via registro
function Apply-LockScreen {
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Write-Host "Aplicando tela de bloqueio (Tentativa $($i+1) de $maxRetries)..."

            # Verifica ou cria a chave de registro
            if (-Not (Test-Path $lockScreenRegKey)) {
                New-Item -Path $lockScreenRegKey -Force
                Write-Host "Chave de registro criada: $lockScreenRegKey"
            }

            # Aplicar a tela de bloqueio via reg.exe
            & reg add $lockScreenRegKey /v LockScreenImage /t REG_SZ /d $lockScreenPath /f
            & reg add $lockScreenRegKey /v LockScreenOverlayImage /t REG_SZ /d $lockScreenPath /f

            Write-Host "Tela de bloqueio aplicada via registro do Windows."

            break
        } catch {
            Write-Error "Erro ao aplicar a tela de bloqueio: $_"
            if ($i -lt $maxRetries - 1) { Start-Sleep -Seconds $retryDelay }
            else { Write-Error "Falha ao aplicar a tela de bloqueio apos $maxRetries tentativas."; exit 1 }
        }
    }

    Write-Host "Aplicacao da tela de bloqueio concluida."
}

# Funcao para aplicar configuracoes no registro HKLM\PersonalizationCSP
function Apply-RegistrySettings {
    Write-Host "Aplicando configuracoes no registro PersonalizationCSP..."

    if (-Not (Test-Path -Path $RegKeyPath)) {
        New-Item -Path $RegKeyPath -Force | Out-Null
        Write-Host "Caminho de registro criado: $RegKeyPath"
    }

    New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopPathReg -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $DesktopUrlReg -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenPathReg -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
    New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrlReg -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null

    Write-Host "Configuracoes aplicadas no registro PersonalizationCSP com sucesso."
}

# Funcao para verificar e instalar a Intune Management Extension (IME)
function Ensure-IntuneManagementExtension {
    Write-Host "Verificando Intune Management Extension..."
    $imePath = "C:\Program Files (x86)\Microsoft Intune Management Extension\agentexecutor.exe"
    if (-Not (Test-Path $imePath)) {
        Write-Host "Intune Management Extension nao encontrado. Instalando..."
        # Baixar e instalar a IME
        $imeUrl = "https://go.microsoft.com/fwlink/?linkid=2090973"
        $imeInstaller = "$env:TEMP\IntuneManagementExtension.msi"
        Invoke-WebRequest -Uri $imeUrl -OutFile $imeInstaller
        Start-Process msiexec.exe -ArgumentList "/i $imeInstaller /quiet /norestart" -Wait
        Remove-Item -Path $imeInstaller -Force
        Write-Host "Intune Management Extension instalado com sucesso."
    } else {
        Write-Host "Intune Management Extension ja esta instalada."
    }
}

# Funcao principal para executar o processo
function Main {
    Write-Host "Iniciando a aplicacao do papel de parede e tela de bloqueio..."
    Ensure-IntuneManagementExtension
    Disable-WindowsSpotlight
    Ensure-DirectoryAndDownloadImages
    Apply-WallpaperRegistry
    Apply-LockScreen
    Apply-RegistrySettings
    Write-Host "Processo concluido com sucesso. Papel de parede e tela de bloqueio aplicados."
}

# Executar a funcao principal
Main
