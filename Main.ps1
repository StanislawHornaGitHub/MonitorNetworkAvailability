using module ./Config.psm1
New-Variable -Name "location" -Value "$((Get-Location).Path)" -Force -Scope Global -Option ReadOnly
New-Variable -Name "logsPath" -Value "$location/Logs" -Force -Scope Global -Option ReadOnly
New-Variable -Name "falilureCounter" -Value 0 -Force -Scope Global


function Invoke-Main {
    if( -not ($IsMacOS)){
        Add-Type -AssemblyName System.Windows.Forms
    }
    Invoke-FolderStructure
    $LogFile = Get-logFileName
    while ($true) {
        $test = Invoke-TestConnection -destinationServer "$([Configuration]::serverNameToPing)"
        Write-LogFile -testOutput $test -logFile $LogFile
        if($falilureCounter -gt $([Configuration]::numberOfFailedPingsToDisplayNotification)){
            Invoke-Popup -title $([Configuration]::ConnectionFailed_popupTitle) `
            -description ([Configuration]::ConnectionFailed_popupDescription)
        }
        Start-Sleep -Seconds $([Configuration]::delayBetweenPingsInSeconds)
    }
}

function Invoke-FolderStructure {
    if( -not $(Test-Path -Path "$logsPath")){
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
    $status = $testOutput.Status
    $latency = $testOutput.latency
    if( -not $(Test-Path -Path $logFile)){
        "`"timestamp`";`"status`";`"latency`";`"Server Name`"" | Out-File -FilePath $logFile
    }
    "`"$((Get-Date).ToString('HH\:mm\:ss\.fff'))`";`"$status`";`"$latency`";`"$([Configuration]::serverNameToPing)`"" | Out-File -FilePath $logFile -Append
}

function Invoke-TestConnection {
    param (
        $destinationServer
    )
    $test = $(Test-Connection $destinationServer -Count 1 -TimeoutSeconds 1)
    if($test.Status -ne "Success"){
        $falilureCounter++
        return $false
    }
    $falilureCounter = 0
    return $test
}

Function Invoke-Popup {
	param (
		[Parameter(Mandatory = $true)]
		[string] $title,
		[Parameter(Mandatory = $true)]
		[String] $description
	)
	$global:endmsg = New-Object System.Windows.Forms.Notifyicon
	$p = (Get-Process powershell | Sort-Object -Property CPU -Descending | Select-Object -First 1).Path
	$endmsg.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($p)
	$endmsg.BalloonTipTitle = $title
	$endmsg.BalloonTipText = $description
	$endmsg.Visible = $true
	$endmsg.ShowBalloonTip(10)
}

Invoke-Main