# Invoke-PS2EXE `
#     -inputFile "Monitor Network Availability.ps1" `
#     -outputFile "Monitor Network Availability.exe"  `
#     -iconFile ".\Main\Icon\Powershell.ico" `
#     -company "Stanislaw Horna" `
#     -title "Monitor_Network_Availability" `
#     -version "1.0.0.0" `
#     -copyright "Stanislaw Horna" `
#     -product "Monitor_Network_Availability" `
#     -noconsole


function Invoke-Main {
    $location = (Get-Location).Path
    Set-Location "./Main"
    conhost.exe ".\Main.exe" $location   
}

Invoke-Main