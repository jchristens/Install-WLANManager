<#
################
# WLAN Manager #
################

.GUID
b53c75e4-3ef4-418a-9405-7537942afbb6

.VERSION
2018-09-24

.AUTHOR 
johan.carlsson@innovatum.se
http://www.innovatum.se/personer/johan-carlsson

.UPDATE
24/09/2018
Updated by JENS CHRISTENS
jens.christens@live.com

.CHANGELOG
September 2018
- Fixed the Win10 error when first installing SchTask. (No MSFT_ScheduledTask objects found with property 'TaskName' equal to 'WLANManager') 

March 2018
- Fixed create Schedule Task issue (Exception calling "GetTask" with "1" argument(s): "The system cannot find the file specified. (Exception from HRESULT: 0x80070002)
- Updated WLANAdapters WMI Query
- Updated WLANAdapters Disable Issues (With Wifi MiniPort)
- Updated Write-Hosts for Write-Outputs
- Added some troubleshooting hints
- Fixed the Win8 identification

#>

## Collect OS Information

$Global:Win8orGreater = [Environment]::OSVersion.Version -ge (new-object 'Version' 8,0)

## Function: Disable-WLANAdapters 

function Disable-WLANAdapters
{
    ## Get only WLAN Adapters - possibly needs to be changed depending on environment
    $WLANAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object {($_.Description -notlike "*VirtualBox*”) -and ($_.Description -notlike "*VMware*”) -and ($_.Description -like "*Wireless*”) -or ($_.Description -like "*Wi-Fi*”)}
    foreach ($WLANAdapter in $WLANAdapters)
        {
            ## Disable WLAN Adapter
            $WLANAdapter.Disable()
        }
}



## Function: Enable-WLANAdapters

function Enable-WLANAdapters
{
    ## Get only WLAN Adapter
    $WLANAdapters = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object {($_.Description -notlike "*VirtualBox*”) -and ($_.Description -notlike "*VMware*”) -and ($_.Description -like "*Wireless*”) -or ($_.Description -like "*Wi-Fi*”)}
    foreach ($WLANAdapter in $WLANAdapters)
        {
            ## Disable WLAN Adapter
            $WLANAdapter.Enable()
        }
}


## Function: Test-WiredConnection 

function Test-WiredConnection
{
## Get only wired connections with IP-address
$NetworkConnectionsLAN = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE” | Where-Object {($_.Description -notlike "*VirtualBox*”) -and ($_.Description -notlike "*VMware*”) -and ($_.Description -notlike "*Wireless*”) -and ($_.Description -notlike "*Wi-Fi*”)}

If ($NetworkConnectionsLAN -eq $null)
    {
        return $false
    }
ElseIf ($NetworkConnectionsLAN -ne $null)
    {
        return $true
    }
}



## Function: Test-WirelessConnection 


function Test-WirelessConnection
{
## Get only wireless connections with IP-address
$NetworkConnectionsWLAN = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE” | Where-Object {($_.Description -notlike "*VirtualBox*”) -and ($_.Description -notlike "*VMware*”) -or ($_.Description -like "*Wireless*”) -or ($_.Description -like "*Wi-Fi*”)}

If ($NetworkConnectionsWLAN -eq $null)
    {
        return $false
    }
ElseIf ($NetworkConnectionsWLAN -ne $null)
    {
        return $true
    }
}



## Function: Install-WLANManager 

function Install-WLANManager
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$SourcePath,

    [Parameter(Mandatory=$True,Position=2)]
    [string]$DestinationPath
)

## Writing Outputs for DEBUG
## Comment if no DEBUG needed

Write-Output "SourcePath: $SourcePath"
Write-Output "DestinationPath: $DestinationPath"
Write-Output "VersionRegPath: $VersionRegPath"


    ## Write version info to registry for SCCM detection method
    Write-Output "Verifying WLAN Manager version information... "
    If ((Test-Path $VersionRegPath) -eq $false)
        {
            Write-Output "Missing"
            Write-Output "Writing WLAN Manager version information... "
            New-Item -Path $VersionRegPath -Force | Out-Null
            New-ItemProperty -Path $VersionRegPath -Name Version -PropertyType String -Value $Version | Out-Null
            Write-Output "Done"
        }
    Else
        {
            Write-Output "Installed"
        }

    ## Copy Script Files
    Write-Output "Verify WLAN Manager Files... "
    If ((Test-Path $DestinationPath) -eq $false)
        {
            Write-Output "Missing"
            Write-Output "Installing WLAN Manager Files... "
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Copy-Item -Path "$SourcePath\*" -Destination "$DestinationPath" -Force
            Write-Output "Done"
        }
    Else
        {
            Write-Output "Installed"
        }

    ## Register Scheduled Task
    Write-Output "Verify WLAN Manager Scheduled Task... "

    ## Set correct $TaskName value depending on install for System or User
    If ($Install -eq "System")
        {
            $User = "NT AUTHORITY\System"
            $TaskName = "WLAN Manager"
            $TaskRunAt = "8"
            $TaskRunAs = "System"
            $TaskRunLevel = "5"
            ## $Trigger
            If ($Win8orGreater)
                {
                    $Trigger = New-ScheduledTaskTrigger -AtStartup
                }
            ## ReleaseDHCPLease
            If ($ReleaseDHCPLease -eq "")
                {
                    $ReleaseDHCPLease = $false
                }
            ## BalloonTip
            $BalloonTip = $false
        }
    ElseIf ($Install -eq "User")
        {
            $User = "$env:USERNAME"
            $TaskName = "WLAN Manager ($env:USERNAME)"
            $TaskRunAt = "8"
            $TaskRunAs = "User"
            $TaskRunLevel = "3"
            ## $Trigger
            If ($Win8orGreater)
                {
                    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
                }
            ## ReleaseDHCPLease
            If ($ReleaseDHCPLease -eq "")
                {
                    $ReleaseDHCPLease = $false
                }
            ## BalloonTip
            If ($BalloonTip -eq "")
                {
                    $BalloonTip = $false
                }
        }
    ## ≥Windows 8

    If ($Win8orGreater)
        {
            try 
                { 
                    (Get-ScheduledTask -TaskName "$TaskName" -ErrorAction Stop) 
                }#end try
                catch 
                    {
                    Write-Output "Missing"
                    Write-Output "Installing WLAN Manager Scheduled Task... " 
                    #$Trigger = New-ScheduledTaskTrigger -AtStartup
                    $Action = New-ScheduledTaskAction -Execute "$env:windir\System32\WindowsPowerShell\v1.0\PowerShell.exe" -Argument "-WindowStyle Hidden -NonInteractive -Executionpolicy Unrestricted -Command ""& """"$DestinationPath\WLANManager.ps1"""""" -ReleaseDHCPLease:`$$ReleaseDHCPLease -BalloonTip:`$$BalloonTip"""
                    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
                    Register-ScheduledTask -TaskName "$TaskName" -Trigger $Trigger -User $User –Action $Action -Settings $Settings -RunLevel Highest | Out-Null
                    Start-ScheduledTask -TaskName "$TaskName"
                    Write-Output "Done"
                    } #end catch
                    Write-Output "Installed"
        }#End if win8orgreater
    ## <Windows 8

    Else
        {
            try {
                (Get-STask -TaskName "$TaskName" -ErrorAction stop)
                }#End try
                catch 
                    {
                    Write-Output "Missing"
                    Write-Output "Installing WLAN Manager Scheduled Task... " 
                    New-STask -TaskName "$TaskName" -TaskCommand "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -TaskArguments "-WindowStyle Hidden -NonInteractive -Executionpolicy Unrestricted -Command ""& """"$DestinationPath\WLANManager.ps1"""""" -ReleaseDHCPLease:`$$ReleaseDHCPLease -BalloonTip:`$$BalloonTip""" -TaskRunAt $TaskRunAt -TaskRunAs $TaskRunAs -TaskRunLevel $TaskRunLevel| Out-Null
                    #New-STask -TaskName "$TaskName" -TaskCommand "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe" -TaskScript "$DestinationPath\WLANManager.ps1" -TaskArguments "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -file ""$DestinationPath\WLANManager.ps1 -BalloonTip:`$$BalloonTip""" | Out-Null
                    Start-STask -TaskName "$TaskName" | Out-Null
                    Write-Output "Done"
                    } #End catch
                    Write-Output "Installed"

        }#End else win8 or greater


## Function: Remove-WLANManager

function Remove-WLANManager
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$FilePath
)
    ## Set correct $TaskName value depending on install for System or User
    If ($Remove -eq "System")
        {
            $TaskName = "WLAN Manager"
        }#End if remove eq system
    ElseIf ($Remove -eq "User")
        {
            $TaskName = "WLAN Manager ($env:USERNAME)"
        }#End elseif remove eq user
    
    ## Remove version information from registry for SCCM Detection Method
    Write-Output "Removing WLAN Manager version information... "
    If ((Test-Path $VersionRegPath) -eq $true)
        {
            Remove-Item -Path $VersionRegPath -Force
            Write-Output "Done"
        }#End if test-path versionregpath eq true
    Else
        {
            Write-Output "$VersionRegPath doesn't exist."
        }#End else
    
    ## Remove WLAN Manager Scheduled Task
    Write-Output "Removing WLAN Manager Scheduled Task... "
    #≥Windows 8
    If ($Win8orGreater)
        {
            If ((Get-ScheduledTask -TaskName "$TaskName" -ErrorAction Continue) -ne $null)
                {
                    Unregister-ScheduledTask -TaskName "$TaskName" -Confirm:$false
                    Write-Output "Done"
                }#End if get-schtask -ne null
            Else
                {
                    Write-Output "$TaskName doesn't exist."
                }#End else 
        }
    #<Windows 8
    Else
        {
            If ((Get-STask -TaskName "$TaskName" -ErrorAction Continue) -ne $null)
                {
                    Unregister-STask -TaskName "$TaskName"
                    Write-Output "Done"
                }#End if get-stask -ne null
            Else
                {
                    Write-Output "$TaskName doesn't exist."
                }#End else
        }#End else greater win8
    
    ## Remove WLAN Manager files

    Write-Output "Removing WLAN Manager files... "
    If ((Test-Path -Path "$FilePath") -eq $True)
        {
            Remove-Item -Path $FilePath -Recurse -Confirm:$false
            Write-Output "Done"
        }#End if test-path eq true
    Else
        {
            Write-Output "$FilePath doesn't exist."
        }#End else

    #Verify that WLAN Manager scheduled task object is removed
    If ((Test-Path -Path "$env:windir\System32\Tasks\$TaskName") -eq $True)
        {
            Remove-Item -Path "$env:windir\System32\Tasks\$TaskName" -Confirm:$false
        }#End if test-path eq true
}



## Function: New-STask 

function New-STask
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$TaskName,
    [Parameter(Mandatory=$False,Position=2)]
    [string]$TaskDescription,
    [Parameter(Mandatory=$True,Position=3)]
    [string]$TaskCommand,
    [Parameter(Mandatory=$True,Position=4)]
    [string]$TaskArguments,
    [Parameter(Mandatory=$True,Position=5)]
    [ValidateSet('8', '3')] #8=AtStartup,?=USER
    [string]$TaskRunAt,
    [Parameter(Mandatory=$True,Position=6)]
    #[ValidateSet("System", "User")]
    [string]$TaskRunAs,
    [Parameter(Mandatory=$True,Position=7)]
    [ValidateSet('5', '3')] #5=SYSTEM,3=USER
    [string]$TaskRunLevel
)
## Set correct value for parameter $TaskRunAs

If ($TaskRunAs -eq "User")
    {
        Set-Variable -Name TaskRunAs -Value $env:USERNAME -Force
    }

## Create Task Scheduler Com Object (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx)
$Service = New-Object -ComObject("Schedule.Service")

## Connect to the local machine
$Service.Connect()

##Get specified Scheduled Tasks folder
$TaskFolder = $Service.GetFolder("\")

## Create Task Definition
$TaskDefinition = $Service.NewTask(0) 
$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
$TaskDefinition.Settings.Enabled = $true
$TaskDefinition.Settings.AllowDemandStart = $true
$TaskDefinition.Settings.DisallowStartIfOnBatteries = $false
$TaskDefinition.Settings.StopIfGoingOnBatteries = $false
$TaskDefinition.Settings.Compatibility = "3" #Windows 7, Windows Server 2008 R2
$TaskDefinition.Settings.Hidden = $true
$TaskDefinition.Principal.RunLevel = "1" #Highest

## Create Task Trigger (http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx)
$Triggers = $TaskDefinition.Triggers
$Trigger = $Triggers.Create($TaskRunAt)
$Trigger.Enabled = $true
 
## Create Task Action (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx)
$Action = $TaskDefinition.Actions.Create(0)
$Action.Path = "$TaskCommand"
$Action.Arguments = "$TaskArguments"
 
## Register Task (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx)
$TaskFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"$TaskRunAs",$null,$TaskRunLevel)
#$TaskFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"$TaskRunAs",$null,5)
}

## Function: Unregister-STask

function Unregister-STask
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$TaskName
)

## Set ErrorActionPreference to avoid errormessage if TaskName is not found
$ErrorActionPreference = "SilentlyContinue"

## Create Task Scheduler Com Object (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx)
$Service = New-Object -ComObject("Schedule.Service")

## Connect to the local machine
$Service.Connect()

## Get specified Scheduled Tasks folder
$TaskFolder = $Service.GetFolder("\")

## Check if specific task exists and if so delete
If ($TaskName -eq $TaskFolder.GetTask("$TaskName").Name)
    {
        #Delete Task
        $TaskFolder.DeleteTask("$TaskName",0)
    }#ENd if taskname eq taskfolder.gettask.name

If(-not $?)
    {
        Write-Output "$TaskName not found."
    }#End if not true
}



## Function: Get-STask

function Get-STask
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$TaskName
)

## Set ErrorActionPreference to avoid errormessage if TaskName is not found
$ErrorActionPreference = "SilentlyContinue"

## Create Task Scheduler Com Object (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx)
$Service = New-Object -ComObject("Schedule.Service")
Write-Output "Service: "
$service

## Connect to the local machine
$Service.Connect()
Write-Output "Service Connected: "
$service

## Get specified Scheduled Tasks folder
$TaskFolder = $Service.GetFolder("\")
Write-Output "TaskFolder: "
$TaskFolder

## Check if specific task exists and if so return details
Write-Output "TaskName: $TaskName"
try {
If ($TaskName -eq $TaskFolder.GetTask("$TaskName").Name)
    {
        $TaskFolder.GetTask("$TaskName")
    }#End if taskname eq taskfolder.gettask.taskname
    
    }#End try
catch { Write-Output "Not created."}

<#
If(-not $?)
    {
        Write-Output "$TaskName not found."
    }#End if not true
#>
}



## Function: Start-STask

function Start-STask
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$TaskName
)

## Set ErrorActionPreference to avoid errormessage if TaskName is not found
$ErrorActionPreference = "SilentlyContinue"

## Create Task Scheduler Com Object (http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx)
$Service = New-Object -ComObject("Schedule.Service")

## Connect to the local machine
$Service.Connect()

## Get specified Scheduled Tasks folder
$TaskFolder = $Service.GetFolder("\")

## Check if specific task exists and if so start the task
If ($TaskName -eq $TaskFolder.GetTask("$TaskName").Name)
    {
        $Task = $TaskFolder.GetTask("$TaskName")
        $Task.Run(1)
    }#End if taskname eq taskfolder.gettask.taskname

If(-not $?)
    {
        Write-Output "$TaskName not found."
    }#End if not true
}



## Function: Show-BallonTip 
## Source: http://www.powertheshell.com/balloontip/

function Show-BalloonTip  
{
 
  [CmdletBinding(SupportsShouldProcess = $true)]
  param
  (
    [Parameter(Mandatory=$true)]
    $Text,
   
    [Parameter(Mandatory=$true)]
    $Title,
   
    [ValidateSet('None', 'Info', 'Warning', 'Error')]
    $Icon = 'Info',

    $Timeout = 10000
  )
 
Add-Type -AssemblyName System.Windows.Forms

if ($global:balloon -eq $null)
{
$global:balloon = New-Object System.Windows.Forms.NotifyIcon
}

$path                    = Get-Process -id $pid | Select-Object -ExpandProperty Path
$balloon.Icon            = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
$balloon.BalloonTipIcon  = $Icon
$balloon.BalloonTipText  = $Text
$balloon.BalloonTipTitle = $Title
$balloon.Visible         = $true

$balloon.ShowBalloonTip($Timeout)
} 



## Function: Remove-BallonTip 
## Source: http://www.powertheshell.com/balloontip/

function Remove-BalloonTip
{
If ($global:balloon -ne $null)
    {
        $global:balloon.Dispose()
        Remove-Variable -Name balloon -Scope Script
    }
Else
    {
        Write-Warning "Variable 'balloon' not found."
    }
}



## Function: Remove-DHCPLease 

function Remove-DHCPLease
{
    #Get only WLAN Adapter
    $WLANAdapterConfiguration = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object {($_.Description -notlike "*VMware*”) -and ($_.Description -like "*Wireless*”) -or ($_.Description -like "*WiFi*") -or ($_.Description -like "*Wi-Fi*")}
    #Release DHCP lease
    $WLANAdapterConfiguration.ReleaseDHCPLease() | Out-Null
}
