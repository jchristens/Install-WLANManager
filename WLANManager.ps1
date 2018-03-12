################
# WLAN Manager #
################
#Version: 2015-05-07
#Author: johan.carlsson@innovatum.se , http://www.innovatum.se/personer/johan-carlsson

## Version 12/03/2018
## Updated by JENS CHRISTENS - jens.christens@live.com

## Changelog:
## - Fixed WLANAdapters WMI Query
## - Fixed WLANAdapters Disable Issues (With Wifi MiniPort)
## - Updated Write-Hosts for Write-Outputs
## - Added some troubleshooting hints

<#

.SYNOPSIS
Disables the WLAN NIC when LAN NIC network connection is verified.
Enables WLAN NIC when LAN NIC network connection is lost.

.DESCRIPTION
WLAN Manager runs as a scheduled task and will automatically disable your WLAN card when a LAN connection is verified.
The WLAN card will be re-enabled once the LAN connection is lost. This ensures you'll always have the fastest available connection and stops network bridging.

.EXAMPLE
.\WLANManager.ps1
Runs WLAN Manager in an interactive window. Will not install anything. This mode is only for testing and watching what happens via console output.

.EXAMPLE
.\WLANManager.ps1 -ReleaseDHCPLease:$true
Runs WLAN Manager in an interactive window. Will not install anything. This mode is only for testing and watching what happens via console output. Releases DHCP lease before disabling WLAN card.

.EXAMPLE
.\WLANManager.ps1 -BalloonTip:$true
Runs WLAN Manager in an interactive window. Will not install anything. This mode is only for testing and watching what happens via console output. Will show a balloontip when enabling or disabling WLAN card.

.EXAMPLE
.\WLANManager.ps1 -Install:System
Installs WLAN Manager and will run at all times in the SYSTEM context.

.EXAMPLE
.\WLANManager.ps1 -Install:System -ReleaseDHCPLease:$true
Installs WLAN Manager and will run at all times in the SYSTEM context. Releases DHCP lease before disabling WLAN card.

.EXAMPLE
.\WLANManager.ps1 -Remove:System
Removes WLAN Manager installation for System.

.EXAMPLE
.\WLANManager.ps1 -Install:User
Installs WLAN Manager and will run at user logon in the USER context.

.EXAMPLE
.\WLANManager.ps1 -Install:User -ReleaseDHCPLease:$true
Installs WLAN Manager and will run at user logon in the USER context. Releases DHCP lease before disabling WLAN card.

.EXAMPLE
.\WLANManager.ps1 -Install:User -BalloonTip:$true
Installs WLAN Manager and will run at user logon in the USER context. Will show a balloontip when enabling or disabling WLAN card.

.EXAMPLE
.\WLANManager.ps1 -Remove:User
Removes WLAN Manager installation for User.

.NOTES
None.

.LINK
https://gallery.technet.microsoft.com/scriptcenter/WLAN-Manager-f438a4d7

#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$False,Position=1,HelpMessage="Installs WLAN Manager for System or User.")]
    [ValidateSet("System", "User")]
    [string]$Install,
    [Parameter(Mandatory=$False,Position=2,HelpMessage="Removes WLAN Manager for System or User.")]
    [ValidateSet("System", "User")]
    [string]$Remove,
    [Parameter(Mandatory=$False,Position=3,HelpMessage="Release DHCP lease before disabling WLAN card.")]
    [switch]$ReleaseDHCPLease,
    [Parameter(Mandatory=$False,Position=4,HelpMessage="Displays balloontip when changes occur. Only valid when installing or running as User.")]
    [switch]$BalloonTip
)


#########################################
# Custom Variables for Your Environment #
#########################################
#Destination Path to where you want to store files for local install of WLAN Manager when installing for: System
$SystemDestinationPath = "$env:ProgramFiles\WLANManager"
#Registry destination path for writing version information to the registry when installing for: System
$SystemVersionRegPath = "HKLM:\SOFTWARE\WLAN Manager"
#Destination Path to where you want to store files for local install of WLAN Manager when installing for: User
$UserDestinationPath = "$env:LOCALAPPDATA\WLANManager"
#Registry destination path for writing version information to the registry when installing for: User
$UserVersionRegPath = "HKCU:\SOFTWARE\WLAN Manager"


<#
D O   N O T   C H A N G E   A N Y T H I N G   B E L O W   T H I S   L I N E
#>


#######################################################
# Change cmdlet parameters scope from Local to Global #
#######################################################
Set-Variable -Name Install -Value $Install -Scope Global -Force
Set-Variable -Name Remove -Value $Remove -Scope Global -Force
Set-Variable -Name ReleaseDHCPLease -Value $ReleaseDHCPLease -Scope Global -Force
Set-Variable -Name BalloonTip -Value $BalloonTip -Scope Global -Force


#################################
# Unload/Load PowerShell Module #
#################################

#Remove PowerShell Module
If ((Get-Module PSModule-WLANManager) -ne $null)
    {
        Remove-Module PSModule-WLANManager -Verbose
    }

#Import PowerShell Module
$strBasePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module "$strBasePath\PSModule-WLANManager.psm1" -Verbose


#####################
# Install or Remove #
#####################

#Version
$Global:Version = "2015-05-07"

#Set correct Destination and VersionRegPath
If ($Install -eq "System" -and $BalloonTip -eq $true)
    {
        Write-Error -Message "Parameter '-ShowBalloonTip:`$true' is ONLY valid when installing for USER." -Category InvalidArgument -ErrorAction Stop
    }
ElseIf ($Install -eq "System" -or $Remove -eq "System")
    {
        $CustomDestinationPath = $SystemDestinationPath
        $Global:VersionRegPath = $SystemVersionRegPath
    }
ElseIf ($Install -eq "User" -or $Remove -eq "User")
    {
        $CustomDestinationPath = $UserDestinationPath
        $Global:VersionRegPath = $UserVersionRegPath
    }

#Install
If ($Install -ne "")
    {
        #Install
        Install-WLANManager -SourcePath $strBasePath -DestinationPath $CustomDestinationPath
        Return
    }
#Remove
ElseIf ($Remove -ne "")
    {
        Remove-WLANManager -FilePath $CustomDestinationPath
        Return
    }


########
# Main #
########

while ($true)
{
    If ((Test-WiredConnection) -eq $true -and (Test-WirelessConnection) -eq $true)
        {
            Write-Host "Wired connection detected, disabling Wireless connection... " -NoNewline -ForegroundColor Yellow
            If ($BalloonTip -eq $true)
                {
                    Show-BalloonTip -Text "Wired connection detected, disabling Wireless connection." -Title "WLAN Manager" -Icon Info
                }
            If ($ReleaseDHCPLease -eq $true)
                {
                    Remove-DHCPLease
                }
            #≥Windows 8
            If ($Win8orGreater)
                {
                    $WLANAdapters = Get-NetAdapter -InterfaceDescription *Wireless*,*WiFi*
                    foreach ($WLANAdapter in $WLANAdapters)
                        {
                            Disable-NetAdapter -Name $WLANAdapter.Name -IncludeHidden -Confirm:$False
                        }
                }
            #<Windows 8
            Else
                {
                    Disable-WLANAdapters | Out-Null
                }
            #Wait for WLAN to release DHCP lease and get disabled
            while ((Test-WiredConnection) -eq $true -and (Test-WirelessConnection) -eq $true)
                {
                    sleep -Seconds 1
                }
            Write-Host "Done" -ForegroundColor White -BackgroundColor Green
        }

    ElseIf ((Test-WiredConnection) -eq $false -and (Test-WirelessConnection) -eq $false)
        {
            Write-Host "Wired connection lost, enabling Wireless connection... " -NoNewline -ForegroundColor Yellow
            If ($BalloonTip -eq $true)
                {
                    Show-BalloonTip -Text "Wired connection lost, enabling Wireless connection." -Title "WLAN Manager" -Icon Info
                }
            #≥Windows 8
            If ($Win8orGreater)
                {
                    $WLANAdapters = Get-NetAdapter -InterfaceDescription *Wireless*,*WiFi*
                    foreach ($WLANAdapter in $WLANAdapters)
                        {
                            Enable-NetAdapter -Name $WLANAdapter.Name -IncludeHidden -Confirm:$False
                        }
                }
            #<Windows 8
            Else
                {
                    Enable-WLANAdapters | Out-Null
                }
            #Wait for WLAN Adapter to initialize and obtain an IP-address
            while ((Test-WiredConnection) -eq $false -and (Test-WirelessConnection) -eq $false)
                {
                    sleep -Seconds 1
                }
            Write-Host "Done" -ForegroundColor White -BackgroundColor Green
        }

    Else
        {
            Write-Host "Sleeping..." -ForegroundColor Yellow
            sleep -Seconds 1
        }
}
