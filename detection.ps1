# Script de Detecção

# Caminho de destino
$targetPath = "C:\Windows\Web\Wallpaper\Intune"

# Lista de arquivos para verificar
$files = @("setta_combustiveis_agosto.jpg", "papeldeparede.jpg")

$allFilesPresent = $true

foreach ($file in $files) {
    $filePath = Join-Path $targetPath $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Arquivo $file não encontrado"
        $allFilesPresent = $false
        break
    }
}

if ($allFilesPresent) {
    Write-Host "Todos os arquivos estão presentes"
    exit 0  # Sucesso
} else {
    Write-Host "Nem todos os arquivos estão presentes"
    exit 1  # Falha
}
