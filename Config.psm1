class Configuration {
    static [int] $averageLatencyThresholdToDisplayNotification = 200 # Default: 200
    static [int] $numberOfPingsToCalculateAverage = 5 # Default 10
    static [int] $delayBetweenPingsInSeconds = 5 # Default: 5
    static [int] $numberOfFailedPingsToDisplayNotification = 5 # Default: 5   
    static [string] $serverNameToPing = "google.com" # Default: "google.com"
    static [int] $delayBetweenSameNotificationsInSeconds = 20 # Default: 20

    static [bool] $logEnabled = $true # Default: $true
    static [string] $logName = "Network Availability"

    static [string] $ConnectionFailed_popupTitle = "Connection Lost"
    static [string] $ConnectionFailed_popupDescription = "Connection to host $([Configuration]::serverNameToPing) is lost"
    static [string] $HighLatencyWarining_pop_popupTitle = "High ping latency"
    static [string] $HighLatencyWarining_popupDescription = "Average latency of last $([Configuration]::numberOfPingsToCalculateAverage) pings is greater than $([Configuration]::averageLatencyThresholdToDisplayNotification) ms"
    static [string] $IconPath =".\Icon\Powershell.ico"
}