using module ./Config.psm1

# Invoke-PS2EXE `
#     -inputFile "Main.ps1" `
#     -outputFile "Main.exe"  `
#     -iconFile ".\Icon\Powershell.ico" `
#     -company "Stanislaw Horna" `
#     -title "Monitor_Network_Availability" `
#     -version "1.0.0.0" `
#     -copyright "Stanislaw Horna" `
#     -product "Monitor_Network_Availability"

Param(
    $Defaultlocation
)

Add-Type -AssemblyName System.Windows.Forms
New-Variable -Name "logsPath" -Value "$location/Logs" -Force -Scope Global -Option ReadOnly
New-Variable -Name "falilureCounter" -Value 0 -Force -Scope Global
New-Variable -Name "errorDetails" -Value "" -Force -Scope Global
New-Variable -Name 'pingsLatency' -Value $(New-Object System.Collections.ArrayList) -Force -Scope Global
New-Variable -Name 'averageLatency' -Value 0 -Force -Scope Global

function Invoke-Main {
    if($null -ne $Defaultlocation){
        New-Variable -Name "location" -Value $Defaultlocation -Force -Scope Global -Option ReadOnly
        New-Variable -Name "logsPath" -Value "$location/Logs" -Force -Scope Global -Option ReadOnly
        Set-Location $location
    }
    $Global:ProgressPreference = 'SilentlyContinue'
    $Global:ErrorActionPreference = 'SilentlyContinue'
    Invoke-WelcomeMessage -Title "Monitor Network Availability" -Portal $([Configuration]::serverNameToPing)
    if ($([Configuration]::logEnabled) -eq $true) {
        Invoke-FolderStructure
        $LogFile = Get-logFileName
    }
    $cooldownPopups = [int]$($([Configuration]::delayBetweenSameNotificationsInSeconds) / $([Configuration]::delayBetweenPingsInSeconds)) 
    $firstIteration = $true
    $connectionLostPopUp = 0
    $highLatencyPopUp = 0
    while ($true) {
        $test = Invoke-TestConnection -destinationServer "$([Configuration]::serverNameToPing)"
        if ($([Configuration]::logEnabled) -eq $true) {
            Write-LogFile -testOutput $test -logFile $LogFile
        }
        ## Console Update section
        if ($firstIteration -eq $false) {
            Remove-LastLine -numberOfLinesToRemove 3
        }
        switch ($Global:falilureCounter -gt $([Configuration]::numberOfFailedPingsToDisplayNotification)) {
            $true { Write-Host "Failed pings in a strike: $Global:falilureCounter" -ForegroundColor Red }
            $false { Write-Host "Failed pings in a strike: $Global:falilureCounter" }
        }
        switch ($Global:averageLatency -gt $([Configuration]::averageLatencyThresholdToDisplayNotification)) {
            $true { Write-Host "Average latency $Global:averageLatency ms" -ForegroundColor Red }
            $false { Write-Host "Average latency $Global:averageLatency ms" }
        }
        Write-Host "Latency of last ping: $($test.PingReplyDetails.RoundtripTime) ms"

        ## Windows Popups section
        if (
            $Global:falilureCounter -gt $([Configuration]::numberOfFailedPingsToDisplayNotification) `
                -and
            $connectionLostPopUp -le 0
        ) {
            $connectionLostPopUp = $cooldownPopups
            
            Invoke-Popup `
                -title $([Configuration]::ConnectionFailed_popupTitle) `
                -description ([Configuration]::ConnectionFailed_popupDescription)
        }
        if (
            $Global:averageLatency -gt $([Configuration]::averageLatencyThresholdToDisplayNotification) `
                -and
            $highLatencyPopUp -le 0
        ) {
            $highLatencyPopUp = $cooldownPopups
            Invoke-Popup `
                -title $([Configuration]::HighLatencyWarining_pop_popupTitle) `
                -description ([Configuration]::HighLatencyWarining_popupDescription)
            
        }
        $highLatencyPopUp--
        $connectionLostPopUp--
        Start-Sleep -Seconds $([Configuration]::delayBetweenPingsInSeconds)
        $firstIteration = $false
    }
}

function Invoke-FolderStructure {
    if ( -not $(Test-Path -Path "$logsPath")) {
        New-Item -ItemType Directory -Path $logsPath | Out-Null
    }
}

function Get-logFileName {
    $date = (Get-Date).ToString("yyyy-MM-dd")
    return $("$logsPath/$date - $([Configuration]::logName).txt")
}

function Write-LogFile {
    param (
        $testOutput,
        $logFile
    )
    $status = $testOutput.PingSucceeded
    if ($status -eq $true) {
        $status = "Success"
    }
    else {
        $status = "Failure"
    }
    $latency = $testOutput.PingReplyDetails.RoundtripTime
    if ( -not $(Test-Path -Path $logFile)) {
        "`"timestamp`";`"status`";`"latency`";`"Server Name`";`"Error details`"" | Out-File -FilePath $logFile
    }
    "`"$((Get-Date).ToString('HH\:mm\:ss\.fff'))`";`"$status`";`"$latency`";`"$([Configuration]::serverNameToPing)`";`"$Global:errorDetails`"" | Out-File -FilePath $logFile -Append
}

function Invoke-TestConnection {
    param (
        $destinationServer
    )

    $test = $(Test-NetConnection $destinationServer -WarningAction SilentlyContinue -WarningVariable warning)
    $Global:errorDetails = $warning
    if (($test.PingSucceeded -eq $true)) {
        $Global:falilureCounter = 0
        if ($Global:pingsLatency.count -ge $([Configuration]::numberOfPingsToCalculateAverage)) {
            $Global:pingsLatency.RemoveAt(0)
            $Global:pingsLatency.Add($($test.PingReplyDetails.RoundtripTime))
        }
        else {
            $Global:pingsLatency.Add($($test.PingReplyDetails.RoundtripTime))
            $latencySum = 0
            $Global:pingsLatency | ForEach-Object { $latencySum += $_ }
            $Global:averageLatency = [math]::Round($($latencySum / $Global:pingsLatency.count), 0)
        }
    }
    else {
        $Global:falilureCounter++
    }
    
    return $test
}

function Invoke-WelcomeMessage {
    param (
        [Parameter(Mandatory = $true)]
        $Title,
        [Parameter(Mandatory = $false)]
        $Portal
    )
    if ($Portal) {
        $numberOfminuses = ((("Destination Host: $Portal".Length - $Title.Length) / 2) - 1)
        if ($("-------- " + $Title + " --------").Length -gt $numberOfminuses) {
            $numberOfminuses = (($("-------- " + " --------").Length / 2) - 1)
        }
        $TempTitle = ""
        for ($i = 0; $i -lt $numberOfminuses; $i++) {
            $TempTitle += "-"
        }
        $TempTitle += " $Title "
        for ($i = 0; $i -lt $numberOfminuses; $i++) {
            $TempTitle += "-"
        }
        $Title = $TempTitle
    }
    else {
        $Title = "-------- " + $Title + " --------"
    }
    $line = ""
    for ($i = 0; $i -lt $Title.Length; $i++) {
        $line += "-"
    }
    Clear-Host
    Set-ConsoleSize -title $Title
    Write-Host $line
    Write-Host $Title
    Write-Host $line
    if ($Portal) {
        Write-Host "Destination Host: $Portal"
        Write-Host $line
    }
}

function Set-ConsoleSize {
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [int]$Height = 15,
        [Parameter(Mandatory = $False, Position = 1)]
        [int]$Width = 50,
        [string]$title
    )
    $console = $host.ui.rawui
    $ConBuffer = $console.BufferSize
    $ConSize = $console.WindowSize

    $currWidth = $ConSize.Width
    $currHeight = $ConSize.Height
    if ($title) {
        $Width = ($title.Length)
    }

    if ($Height -gt $host.UI.RawUI.MaxPhysicalWindowSize.Height) {
        $Height = $host.UI.RawUI.MaxPhysicalWindowSize.Height
    }
    if ($Width -gt $host.UI.RawUI.MaxPhysicalWindowSize.Width) {
        $Width = $host.UI.RawUI.MaxPhysicalWindowSize.Width
    }
    If ($ConBuffer.Width -gt $Width ) {
        $currWidth = $Width
    }
    If ($ConBuffer.Height -gt $Height ) {
        $currHeight = $Height
    }
    $host.UI.RawUI.WindowTitle = "Monitor Network Availability"
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.size($currWidth, $currHeight)
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.size($Width, $Height)
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.size($Width, $Height)
}

function Remove-LastLine {
    param(
        [int]$numberOfLinesToRemove = 1
    )
    $CurrentLine = $Host.UI.RawUI.CursorPosition.Y
    $ConsoleWidth = $Host.UI.RawUI.BufferSize.Width

    for ($i = 1; $i -le $numberOfLinesToRemove; $i++) {
	
        [Console]::SetCursorPosition(0, ($CurrentLine - $i))
        [Console]::Write("{0,-$ConsoleWidth}" -f " ")

    }
    [Console]::SetCursorPosition(0, ($CurrentLine - $numberOfLinesToRemove))
}
Function Invoke-Popup {
    param (
        [Parameter(Mandatory = $true)]
        [string] $title,
        [Parameter(Mandatory = $true)]
        [String] $description
    )
    $imgIcon = New-Object system.drawing.icon (([Configuration]::IconPath))
    $global:endmsg = New-Object System.Windows.Forms.Notifyicon
    $endmsg.Icon = $imgIcon
    $endmsg.BalloonTipTitle = $title
    $endmsg.BalloonTipText = $description
    $endmsg.Visible = $true
    $endmsg.ShowBalloonTip(10)
}

Invoke-Main