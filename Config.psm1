class Configuration {
    static [string] $logName = "Network Availability" # Default: "Network Availability"
    static [string] $serverNameToPing = "google.com" # Default: "google.com"
    static [string] $ConnectionFailed_popupTitle = "Connection Lost"
    static [string] $ConnectionFailed_popupDescription = "Connection Lost" # Default: "Connection Lost"
    static [int] $delayBetweenPingsInSeconds = 5 # Default: 5
    static [int] $numberOfFailedPingsToDisplayNotification = 5 # Default: 5   
}