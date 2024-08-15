$Regexists = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$PersonalizationCSP= 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

$ImagePath= 'C:\Windows\Web\Wallpaper\Intune\papeldeparede.jpg'

if ($Regexists -eq $false){

New-Item -path $PersonalizationCSP
New-ItemProperty -path $PersonalizationCSP -Name LockScreenImagePath -PropertyType String -Value $ImagePath
New-ItemProperty -path $PersonalizationCSP -Name LockScreenImageUrl -PropertyType string -Value $ImagePath
New-ItemProperty -path $PersonalizationCSP -Name LockScreenImageStatus -PropertyType DWord -Value 0

}

Else {

Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImagePath -Value $ImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImageUrl -Value $ImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImageStatus -Value 0 -Force

}
