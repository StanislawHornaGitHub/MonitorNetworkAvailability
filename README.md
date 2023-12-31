﻿## [MonitorNetworkAvailability](/Monitor_Network_Availability.ps1.ps1)
Simple Powershell script running in the background to ping external server and monitor availability of this server and calculates average latency of the pings.

Script is sending ping to server configured in [Config.psm1](/Config.psm1) file and if the output does not meet requirements user is informed using windows pop-ups
<p float="left">
    <img src="/Screenshots/Average_Latency_Red_Console.png" width="432" />
    <img src="/Screenshots/Latency_PopUp.png" width="366" />
</p>
<p float="left">
    <img src="/Screenshots/Failed_Pings_Red_Console.png" width="432" />
    <img src="/Screenshots/ConnectionLost_PopUp.png" width="366" />
</p>

# How to configure the script
All configuration is done in [Config.psm1](/Config.psm1)
        
    $averageLatencyThresholdToDisplayNotification = 10
            Ping latency in milliseconds which has to be exceeded to generate pop-up
    $numberOfPingsToCalculateAverage = 5
            Number of pings which will be used to calculate average response
    $delayBetweenPingsInSeconds = 5
            Delay to wait before the next ping will be send 
    $numberOfFailedPingsToDisplayNotification = 5 
            Number of pings in a row which must be failed ones to generate the pop-up
    $serverNameToPing = "google.com"
            Server IP address or DNS name which will be pinged
    $delayBetweenSameNotificationsInSeconds = 20
            Delay to wait before next pop-up related to the same issue will be displayed.
            If the connection is broken you will not receive notification more often than,
            the time set in this variable
    $logEnabled = $true
            Bool value to enable or disable logging function

# How to run the script
1. [Set the config file](#how-to-configure-the-script) according to your needs
2. Right-click on [Monitor_Network_Availability.ps1](/Monitor_Network_Availability.ps1.ps1) 
3. Select "Run with PowerShell"
