$Regexists = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$PersonalizationCSP= 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'

$ImagePath = 'C:\Windows\Web\Wallpaper\Intune\papeldeparede.jpg'
$LockScreenImagePath = 'C:\Windows\Web\Wallpaper\Intune\teladebloqueio.jpg'

if ($Regexists -eq $false){

New-Item -path $PersonalizationCSP
New-ItemProperty -path $PersonalizationCSP -Name DesktopImagePath -PropertyType String -Value $ImagePath
New-ItemProperty -path $PersonalizationCSP -Name DesktopImageUrl -PropertyType string -Value $ImagePath
New-ItemProperty -path $PersonalizationCSP -Name DesktopImageStatus -PropertyType DWord -Value 0

New-ItemProperty -path $PersonalizationCSP -Name LockScreenImagePath -PropertyType String -Value $LockScreenImagePath
New-ItemProperty -path $PersonalizationCSP -Name LockScreenImageUrl -PropertyType string -Value $LockScreenImagePath
New-ItemProperty -path $PersonalizationCSP -Name LockScreenImageStatus -PropertyType DWord -Value 0

}

Else {

Set-ItemProperty -path $PersonalizationCSP -Name DesktopImagePath -Value $ImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name DesktopImageUrl -Value $ImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name DesktopImageStatus -Value 0 -Force

Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImagePath -Value $LockScreenImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImageUrl -Value $LockScreenImagePath -Force
Set-ItemProperty -path $PersonalizationCSP -Name LockScreenImageStatus -Value 0 -Force

}
