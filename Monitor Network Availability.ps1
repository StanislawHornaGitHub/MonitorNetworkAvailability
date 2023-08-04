using module ./Config.psm1

# Invoke-PS2EXE `
#     -inputFile "Monitor Network Availability.ps1" `
#     -outputFile "Monitor Network Availability.exe"  `
#     -iconFile ".\Icon\Powershell.ico" `
#     -company "Stanislaw Horna" `
#     -title "Monitor_Network_Availability" `
#     -version "1.0.0.0" `
#     -copyright "Stanislaw Horna" `
#     -product "Monitor_Network_Availability"


Add-Type -AssemblyName System.Windows.Forms
New-Variable -Name "location" -Value "$((Get-Location).Path)" -Force -Scope Global -Option ReadOnly
New-Variable -Name "logsPath" -Value "$location/Logs" -Force -Scope Global -Option ReadOnly
New-Variable -Name "falilureCounter" -Value 0 -Force -Scope Global
New-Variable -Name "errorDetails" -Value "" -Force -Scope Global
New-Variable -Name 'pingsLatency' -Value $(New-Object System.Collections.ArrayList) -Force -Scope Global
New-Variable -Name 'averageLatency' -Value 0 -Force -Scope Global
New-Variable -Name 'latencyToGraph' -Value $(New-Object System.Collections.ArrayList) -Force -Scope Global

function Invoke-Main {
    $Global:ProgressPreference = 'SilentlyContinue'
    $Global:ErrorActionPreference = 'SilentlyContinue'
    Invoke-WelcomeMessage -Title "Monitor Network Availability" -Portal $([Configuration]::serverNameToPing)
    if ($([Configuration]::logEnabled) -eq $true) {
        Invoke-FolderStructure
        $LogFile = Get-logFileName
    }
    $cooldownPopups = [int]$($([Configuration]::delayBetweenSameNotificationsInSeconds) / $([Configuration]::delayBetweenPingsInSeconds)) 
    $firstIteration = $true
    $firstGraph = $true
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
        if ($Global:latencyToGraph.count -ge 1) {
            if ($firstGraph -eq $true) {
                Show-Graph -Datapoints $Global:latencyToGraph `
                    -XAxisTitle "Time interval $([Configuration]::delayBetweenPingsInSeconds) s" `
                    -YAxisTitle "Latency" `
                    -Y_max $([Configuration]::graphScaleMax) `
                    -Y_min $([Configuration]::graphScaleMin)
                $firstGraph = $false
            }
            else {
                Update-Graph -Datapoints $Global:latencyToGraph `
                    -XAxisTitle "Time interval $([Configuration]::delayBetweenPingsInSeconds) s" `
                    -YAxisTitle "Latency" `
                    -Y_max $([Configuration]::graphScaleMax) `
                    -Y_min $([Configuration]::graphScaleMin)
            }
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
    if ($Global:latencyToGraph.count -ge $([Configuration]::numberOfPingsToGraph)) {
        $Global:latencyToGraph.RemoveAt(0)
    }
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
        $Global:latencyToGraph.Add($($test.PingReplyDetails.RoundtripTime))
    }
    else {
        $Global:falilureCounter++
        $Global:latencyToGraph.Add($([Configuration]::graphScaleMax))
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
    Set-ConsoleTitle -title $Title
    Write-Host $line
    Write-Host $Title
    Write-Host $line
    if ($Portal) {
        Write-Host "Destination Host: $Portal"
        Write-Host $line
    }
}
function Set-ConsoleTitle {
	param(
		$ConsoleTitle
	)
	$host.UI.RawUI.WindowTitle = $ConsoleTitle
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
    if ($null -ne $global:endmsg) {
        $endmsg.Dispose()
    }
    $imgIcon = New-Object system.drawing.icon (([Configuration]::IconPath))
    $global:endmsg = New-Object System.Windows.Forms.Notifyicon
    $endmsg.Icon = $imgIcon
    $endmsg.BalloonTipTitle = $title
    $endmsg.BalloonTipText = $description
    $endmsg.Visible = $true
    $endmsg.ShowBalloonTip(10)
}

function Show-Graph {
    Param(
        [int[]] $Datapoints = (1..100 | Get-Random -Count 50),
        [String] $XAxisTitle = 'X-Axis',
        [String] $YAxisTitle = 'Y-Axis',
        [int] $Y_max,
        [int] $Y_min
    )
    $numOfDatapoints = $Datapoints.Count
    $scaleMax = ($Datapoints | Measure-Object -Maximum).Maximum
    $scaleMin = ($Datapoints | Measure-Object -Minimum).Minimum
    $graphWidth = 16
    $graphHeight = 12
    $Y_titleStartIndex = 0
    $X_titleStartIndex = 0
    if (($null -ne $Y_max) -and ($null -ne $Y_min)) {
        $scaleMax = $Y_max 
        $scaleMin = $Y_min
    }
    $scaleLength = "$scaleMax".Length
    # Height greater than scale (10 lines) + X line + X label * 2 times
    if ($($host.UI.RawUI.WindowSize.Height) -gt 24) {
        $graphHeight = [int] ($($host.UI.RawUI.WindowSize.Height) / 2)
    }
    # Graduation on Y scale correction
    if ($numOfDatapoints -lt ($graphHeight - 1)) {
        if ([int]($scaleMax - $scaleMin + 1) -lt ($($host.UI.RawUI.WindowSize.Height) / 2)) {
            $graphHeight = [int]($scaleMax - $scaleMin + 1)
        }
    }
    # Center Y Axis title
    if ($graphHeight -gt $YAxisTitle.Length) {
        $Y_titleStartIndex = [int]($graphHeight - $YAxisTitle.Length) / 2
    }
    # Extend scale lenght if there is number below 0
    if ($("$scaleMax".Length) -lt $("$scaleMin".Length)) {
        $scaleLength = "$scaleMin".Length
    }
    # Extend graph width to the console window
    if ($($host.UI.RawUI.WindowSize.Width) -gt $graphWidth) {
        $graphWidth = ($($host.UI.RawUI.WindowSize.Width))
    }
    # Do not build widther graph than points available
    if ($graphWidth -gt (2 + $scaleLength + 1 + $numOfDatapoints)) {
        $graphWidth = (2 + $scaleLength + 1 + $numOfDatapoints)
    }
    # Center X Axis title
    if ($graphWidth -gt $XAxisTitle.Length) {
        $X_titleStartIndex = [int](($graphWidth - $XAxisTitle.Length - 1) / 2)
    }
    # Calculate the data set which fits into graph width
    $dataWidth = ($graphWidth - 2 - $scaleLength)
    if ($dataWidth -lt ($Datapoints.Count)) {
        $dividierCounter = 0
        for ($i = 1; $i -le $numOfDatapoints; $i++) {
            if ( $numOfDatapoints % $i -eq 0) { 
                $dividierCounter++
            }
        }
        if ($dividierCounter -eq 2 ) { 
            throw "Number of datapoints is a prime number, it can not be adjusted to console size"
        } 
        $oldDatapoints = $Datapoints
        $Datapoints = @()
        $averageOf = 2
        for (; $averageOf -lt 1000000; $averageOf++) {
            if ((($oldDatapoints.Count) % $averageOf) -eq 0) {
                $numOfDatapoints = ($($oldDatapoints.Count) / $averageOf)
                if ($numOfDatapoints -lt $dataWidth) {
                    break
                }
            } 
        }
        Write-Host "Average of: $averageOf"
        $count = 0
        $sum = 0
        for ($i = 0; $i -lt $oldDatapoints.Count; $i++) {
            $sum += $oldDatapoints[$i]
            $count++
            if ($count -eq $averageOf) {
                $Datapoints += [int]$($sum / $averageOf)
                $count = 0
                $sum = 0
            }
        }
        $graphWidth = ($Datapoints.Count + 2 + $scaleLength + 1)
    }
    $y_index = 0
    $division = (($scaleMax - $scaleMin) / ($graphHeight - 1)) 
    $print_X_Axis = $true
    # For through lines    
    for ($i = 0; $i -lt $graphHeight; $i++) {
        $lineToDisplay = ""
        # Add X Axis in right place
        if (($print_X_Axis -eq $true)`
                -and `
            ($([int]($scaleMax - ($i * $division))) -lt 0)) {
            # Check if in current iteration Y title should be displayed
            if (($i -ge $Y_titleStartIndex) `
                    -and `
                ($y_index -lt $($YAxisTitle.Length))) {
                $lineToDisplay += "$($YAxisTitle[$y_index])"
                $y_index++
            }
            else {
                $lineToDisplay += " "
            }
            # Add separator
            $lineToDisplay += " "
            $X_Axis = $lineToDisplay
            for ($l = 0; $l -lt ($graphWidth - 2 ); $l++) {
                if ($l -eq ($scaleLength)) {
                    $X_Axis += "|"
                }
                else {
                    $X_Axis += "-"  
                }
                
            }
            $X_Axis += ">"
            $print_X_Axis = $false
            Write-Host $X_Axis
        }
        $lineToDisplay = ""
        # Check if in current iteration Y title should be displayed
        if (($i -ge $Y_titleStartIndex) `
                -and `
            ($y_index -lt $($YAxisTitle.Length))) {
            $lineToDisplay += "$($YAxisTitle[$y_index])"
            $y_index++
        }
        else {
            $lineToDisplay += " "
        }
        # Add separator
        $lineToDisplay += " "
        # add Y scale
        $scaleNumber = "$([int]($scaleMax - ($i * $division)))"
        if ($("$scaleNumber".lenght) -lt $scaleLength) {
            $scaleAligner = ""
            $spaces = ($scaleLength - $("$scaleNumber".Length))
            #Write-Host "spaces: $spaces"
            for ($k = 0; $k -lt $spaces; $k++) {
                $scaleAligner += " "
            }
            $scaleNumber = "$scaleAligner" + "$scaleNumber"
        }
        $lineToDisplay += "$scaleNumber"
        # Add Y Axis line
        $lineToDisplay += "|"
        $AxisToDisplay = $lineToDisplay
        Write-Host $AxisToDisplay -NoNewline
        $lineToDisplay = ""
        for ($j = 0; $j -lt $Datapoints.Count; $j++) {
            if ($Datapoints[$j] -ge $scaleNumber) {
                $lineToDisplay += "$([char] 9608)"
            }
            else {
                $lineToDisplay += " "
            }
        }
        if (
            ($([int]($scaleMax - ($i * $division))) -ge $([Configuration]::averageLatencyThresholdToDisplayNotification)) `
            -or `
            $global:falilureCounter -ne 0) {
            Write-Host "$lineToDisplay`n" -NoNewline -ForegroundColor 'red'
        }
        else {
            Write-Host "$lineToDisplay`n" -NoNewline -ForegroundColor 'green'
        }
    }
    # If all values are greater than 0 the X axis was not printed
    if ($print_X_Axis -eq $true) {
        $X_Axis = "  "
        for ($l = 0; $l -lt ($graphWidth - 2 ); $l++) {
            if ($l -eq ($scaleLength)) {
                $X_Axis += "|"
            }
            else {
                $X_Axis += "-"  
            }
                
        }
        $X_Axis += ">"
        $print_X_Axis = $false
        Write-Host $X_Axis
    }
    $lineToDisplay = ""
    for ($i = 0; $i -lt $X_titleStartIndex; $i++) {
        $lineToDisplay += " "
    }
    $lineToDisplay += $XAxisTitle
    Write-Host $lineToDisplay
}
function Update-Graph {
    Param(
        [int[]] $Datapoints = (1..100 | Get-Random -Count 50),
        [String] $XAxisTitle = 'X-Axis',
        [String] $YAxisTitle = 'Y-Axis',
        [int] $Y_max,
        [int] $Y_min
    )
    $numOfDatapoints = $Datapoints.Count
    $scaleMax = ($Datapoints | Measure-Object -Maximum).Maximum
    $scaleMin = ($Datapoints | Measure-Object -Minimum).Minimum
    $graphWidth = 16
    $graphHeight = 12
    $Y_titleStartIndex = 0
    $X_titleStartIndex = 0
    if (($null -ne $Y_max) -and ($null -ne $Y_min)) {
        $scaleMax = $Y_max 
        $scaleMin = $Y_min
    }
    $scaleLength = "$scaleMax".Length
    # Height greater than scale (10 lines) + X line + X label * 2 times
    if ($($host.UI.RawUI.WindowSize.Height) -gt 24) {
        $graphHeight = [int] ($($host.UI.RawUI.WindowSize.Height) / 2)
    }
    # Graduation on Y scale correction
    if ($numOfDatapoints -lt ($graphHeight - 1)) {
        if ([int]($scaleMax - $scaleMin + 1) -lt ($($host.UI.RawUI.WindowSize.Height) / 2)) {
            $graphHeight = [int]($scaleMax - $scaleMin + 1)
        }
    }
    # Center Y Axis title
    if ($graphHeight -gt $YAxisTitle.Length) {
        $Y_titleStartIndex = [int]($graphHeight - $YAxisTitle.Length) / 2
    }
    # Extend scale lenght if there is number below 0
    if ($("$scaleMax".Length) -lt $("$scaleMin".Length)) {
        $scaleLength = "$scaleMin".Length
    }
    # Extend graph width to the console window
    if ($($host.UI.RawUI.WindowSize.Width) -gt $graphWidth) {
        $graphWidth = ($($host.UI.RawUI.WindowSize.Width))
    }
    # Do not build widther graph than points available
    if ($graphWidth -gt (2 + $scaleLength + 1 + $numOfDatapoints)) {
        $graphWidth = (2 + $scaleLength + 1 + $numOfDatapoints)
    }
    # Center X Axis title
    if ($graphWidth -gt $XAxisTitle.Length) {
        $X_titleStartIndex = [int](($graphWidth - $XAxisTitle.Length - 1) / 2)
    }
    # Calculate the data set which fits into graph width
    $dataWidth = ($graphWidth - 2 - $scaleLength)
    if ($dataWidth -lt ($Datapoints.Count)) {
        $dividierCounter = 0
        for ($i = 1; $i -le $numOfDatapoints; $i++) {
            if ( $numOfDatapoints % $i -eq 0) { 
                $dividierCounter++
            }
        }
        if ($dividierCounter -eq 2 ) { 
            throw "Number of datapoints is a prime number, it can not be adjusted to console size"
        } 
        $oldDatapoints = $Datapoints
        $Datapoints = @()
        $averageOf = 2
        for (; $averageOf -lt 1000000; $averageOf++) {
            if ((($oldDatapoints.Count) % $averageOf) -eq 0) {
                $numOfDatapoints = ($($oldDatapoints.Count) / $averageOf)
                if ($numOfDatapoints -lt $dataWidth) {
                    break
                }
            } 
        }
        $count = 0
        $sum = 0
        for ($i = 0; $i -lt $oldDatapoints.Count; $i++) {
            $sum += $oldDatapoints[$i]
            $count++
            if ($count -eq $averageOf) {
                $Datapoints += [int]$($sum / $averageOf)
                $count = 0
                $sum = 0
            }
        }
        $graphWidth = ($Datapoints.Count + 2 + $scaleLength + 1)
    }
    $y_index = 0
    $division = (($scaleMax - $scaleMin) / ($graphHeight - 1))
    $print_X_Axis = $true
    Remove-LastLine -numberOfLinesToRemove $($graphHeight + 2)
    # For through lines    
    for ($i = 0; $i -lt $graphHeight; $i++) {
        $lineToDisplay = ""
        # Add X Axis in right place
        if (($print_X_Axis -eq $true)`
                -and `
            ($([int]($scaleMax - ($i * $division))) -lt 0)) {
            # Check if in current iteration Y title should be displayed
            if (($i -ge $Y_titleStartIndex) `
                    -and `
                ($y_index -lt $($YAxisTitle.Length))) {
                $lineToDisplay += "$($YAxisTitle[$y_index])"
                $y_index++
            }
            else {
                $lineToDisplay += " "
            }
            # Add separator
            $lineToDisplay += " "
            $X_Axis = $lineToDisplay
            for ($l = 0; $l -lt ($graphWidth - 2 ); $l++) {
                if ($l -eq ($scaleLength)) {
                    $X_Axis += "|"
                }
                else {
                    $X_Axis += "-"  
                }
                
            }
            $X_Axis += ">"
            $print_X_Axis = $false
            Write-Host $X_Axis
        }
        $lineToDisplay = ""
        # Check if in current iteration Y title should be displayed
        if (($i -ge $Y_titleStartIndex) `
                -and `
            ($y_index -lt $($YAxisTitle.Length))) {
            $lineToDisplay += "$($YAxisTitle[$y_index])"
            $y_index++
        }
        else {
            $lineToDisplay += " "
        }
        # Add separator
        $lineToDisplay += " "
        # add Y scale
        $scaleNumber = "$([int]($scaleMax - ($i * $division)))"
        if ($("$scaleNumber".lenght) -lt $scaleLength) {
            $scaleAligner = ""
            $spaces = ($scaleLength - $("$scaleNumber".Length))
            #Write-Host "spaces: $spaces"
            for ($k = 0; $k -lt $spaces; $k++) {
                $scaleAligner += " "
            }
            $scaleNumber = "$scaleAligner" + "$scaleNumber"
        }
        $lineToDisplay += "$scaleNumber"
        # Add Y Axis line
        $lineToDisplay += "|"
        $AxisToDisplay = $lineToDisplay
        Write-Host $AxisToDisplay -NoNewline
        $lineToDisplay = ""
        for ($j = 0; $j -lt $Datapoints.Count; $j++) {
            if ($Datapoints[$j] -ge $scaleNumber) {
                $lineToDisplay += "$([char] 9608)"
            }
            else {
                $lineToDisplay += " "
            }
        }
        if (
            ($([int]($scaleMax - ($i * $division))) -ge $([Configuration]::averageLatencyThresholdToDisplayNotification)) `
            -or `
            $global:falilureCounter -ne 0) {
            Write-Host "$lineToDisplay`n" -NoNewline -ForegroundColor 'red'
        }
        else {
            Write-Host "$lineToDisplay`n" -NoNewline -ForegroundColor 'green'
        }
        
    }
    # If all values are greater than 0 the X axis was not printed
    if ($print_X_Axis -eq $true) {
        $X_Axis = "  "
        for ($l = 0; $l -lt ($graphWidth - 2 ); $l++) {
            if ($l -eq ($scaleLength)) {
                $X_Axis += "|"
            }
            else {
                $X_Axis += "-"  
            }
                
        }
        $X_Axis += ">"
        $print_X_Axis = $false
        Write-Host $X_Axis
    }
    $lineToDisplay = ""
    for ($i = 0; $i -lt $X_titleStartIndex; $i++) {
        $lineToDisplay += " "
    }
    $lineToDisplay += $XAxisTitle
    Write-Host $lineToDisplay
}

Invoke-Main