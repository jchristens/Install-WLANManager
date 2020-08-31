# Install-WLANManager
WLANManager Powershell Module [Wired ON -> WiFi Off / Wifi Off -> Wired On]

Updated script from:

https://gallery.technet.microsoft.com/scriptcenter/WLAN-Manager-f438a4d7

https://github.com/askvictor/WLANManager

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

AUG 2020
- Removed UNICDOE quotation errors
- Please refer to ChrisGoding his fork for modifications.
https://github.com/chrisgoding/Install-WLANManager
