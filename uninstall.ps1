# Script de Desinstalação

# Caminho de destino
$targetPath = "C:\Windows\Web\Wallpaper\Intune"

# Lista de arquivos para remover
$files = @("wallpaper.jpg", "lockscreen.jpg")

foreach ($file in $files) {
    $filePath = Join-Path $targetPath $file
    if (Test-Path $filePath) {
        Remove-Item -Path $filePath -Force
        Write-Host "Arquivo $file removido com sucesso"
    } else {
        Write-Host "Arquivo $file não encontrado"
    }
}

# Remove o diretório se estiver vazio
if ((Get-ChildItem $targetPath | Measure-Object).Count -eq 0) {
    Remove-Item -Path $targetPath -Force
    Write-Host "Diretório $targetPath removido"
} else {
    Write-Host "Diretório $targetPath não está vazio, mantendo-o"
}

Write-Host "Desinstalação concluída"
