# Script de Instalação

# Caminho de destino
$targetPath = "C:\Windows\Web\Wallpaper\Intune"

# Cria o diretório se não existir
if (-not (Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath -Force
}

# Lista de arquivos para copiar
$files = @("setta_combustiveis_agosto.jpg", "papeldeparede.jpg")

foreach ($file in $files) {
    $sourcePath = Join-Path $PSScriptRoot $file
    $destPath = Join-Path $targetPath $file

    # Verifica se o arquivo fonte existe
    if (Test-Path $sourcePath) {
        # Remove arquivos existentes com o mesmo nome, independentemente da extensão
        Get-ChildItem $targetPath -File | Where-Object {
            $_.BaseName -eq [System.IO.Path]::GetFileNameWithoutExtension($file) -and
            $_.Extension -match "\.(jpg|jpeg|png)$"
        } | Remove-Item -Force

        # Copia o novo arquivo
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "Arquivo $file copiado com sucesso para $destPath"
    } else {
        Write-Host "Arquivo fonte $sourcePath não encontrado"
    }
}

Write-Host "Instalação concluída"
