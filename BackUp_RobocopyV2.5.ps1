### POC READY V2.5 ###

# What: Backup procedure using robocopy, take a shadow copy of C:\ drive, and use robocopy to send content to a network location and log output to second network location.
# Where: Logged on users Local selected folders structure and files to shared folder on network, multiple sources can be defined.
# When: Can be run manually or as a scheduled process (Local scheduler\GPO\Jenkins\etc).
# Why: Well... why not?
# How: 1. A folder with the name as the machinename is created on network share.
#      2. A shadowcopy of drive C:\ is captured.
#      3. then selected folders structure from shadow copy are copied to network location.
#      4. Time stamped log file is created on second network location.
#      5. If Network location is not available, the script writes the output of an "ipconfig" command and the current time stamp to local path.
#        *If there are already copies of local data on remote destination then only changed files will be copied.
#        *If a remote copy is changed (newer) it will be skipped.
#        *The root folder is a network share with the name of the username of the user logged on and executing the process.

##This section opens the Elevated shell.
## * Keep this marked when working via ISE (fucks things up).
#If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
#{   
#$arguments = "& '" + $myinvocation.mycommand.definition + "'"
#Start-Process powershell -Verb runAs -ArgumentList $arguments
#Break
#}

### Create a SHADOW COPY of drive "C:\" and mount the image as "C:\shadowcopy".
$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\"   # <-- this here
#
cmd /c mklink /d C:\shadowcopy "$d"
Start-Sleep -s 2
#$s2.Delete()


### Vars.
$RootBackUpFolder = "\\10.0.0.1\fs\Users\$env:USERNAME\_AutoBackup\$env:COMPUTERNAME\"
$LogDest = "\\10.0.0.1\fs\Users\_AutoBackup\Logs"
$Netfld = Get-ChildItem -Path \\10.0.0.1\fs\Users\$env:USERNAME\_AutoBackup\
$Tmstmp = (Get-Date).ToString('dd-MM-yyyy')
$RemoteFolderName = $Netfld.Name -like "$env:COMPUTERNAME"
$FullPath = $RootBackUpFolder+$RemoteFolderName
$Ndrv = ( Test-Path \\10.0.0.1\fs\Users\$env:USERNAME)
$FailedLogs = "C:\Users\$env:USERNAME\Documents\BackUpFailed_$Tmstmp.txt"

### Verify network drive existance.
if ($Ndrv -eq $true ) {Write-Host "Network drive is available"}
else {(Write-Host "Network drive (U:\) is not available..."), ( ($Tmstmp) , (ipconfig) , (Get-ChildItem ENV:) | Out-File $FailedLogs -Append)
     }

### Verify bacup folder existance, if doesn't exist it creates it.
if (Test-Path $FullPath) {Write-Host "BackUP folder exists."}
else {
      New-Item -ItemType Directory -Path $RootBackUpFolder
     }

Start-Sleep -s 2

#get-childitem -Path $RootBackUpFolder  | % {$RoboDest = $_.FullName}

### Create function to be reused later.

# /E : Copy Subfolders, including Empty Subfolders.
# /TEE : Output to console window, as well as the log file.
# /XO : eXclude Older - if destination file exists and is the same date or newer than the source - don’t bother to overwrite it.
# /XD dirs [dirs]... : eXclude Directories matching given names/paths.
# /R:n : Number of Retries on failed copies - default is 1 million. (was used to solve the Pictures, Videos... copying problem)
# /W:n : Wait time between retries - default is 30 seconds. (was used to solve the Pictures, Videos... copying problem)
function Robo-Copy {
                    robocopy $args[0] $args[1] /E /TEE /XO /XD _Personal /R:0 /W:0 /LOG+:$LogDest\"$env:USERNAME"_"$env:COMPUTERNAME"_RunLog_$Tmstmp.txt
                    } 

### Robocopy to copy the relevant files from 1st location.
$RoboSource_1 = "C:\shadowcopy\Users\$env:username\desktop"
$FinDest_1 = "\desktop"

$FinalDestination_1 = $RootBackUpFolder + $FinDest_1
Robo-Copy $RoboSource_1 $FinalDestination_1

### Robocopy to copy the relevant files from 2nd location.
$RoboSource_2 = "C:\shadowcopy\Users\$env:username\documents"
$FinDest_2 = "\documents"

$FinalDestination_2 = $RootBackUpFolder + $FinDest_2
Robo-Copy $RoboSource_2 $FinalDestination_2

### Robocopy to copy the relevant files from 3rd location.
$RoboSource_3= "C:\shadowcopy\Users\$env:username\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
$FinDest_3 = "\bookmarks"

$FinalDestination_3 = $RootBackUpFolder + $FinDest_3
Robo-Copy $RoboSource_3 $FinalDestination_3

### Robocopy to copy the relevant files from 4th location.
$RoboSource_4= "C:\shadowcopy\Users\$env:username\AppData\Local\Microsoft\Outlook"
$FinDest_4 = "\outlook"

$FinalDestination_4 = $RootBackUpFolder + $FinDest_4
Robo-Copy $RoboSource_4 $FinalDestination_4

### Robocopy to copy the relevant files from 5th location.
$RoboSource_5= "C:\shadowcopy\Users\$env:username\Documents\Outlook Files"
$FinDest_5 = "\outlook"

$FinalDestination_5 = $RootBackUpFolder + $FinDest_5
Robo-Copy $RoboSource_5 $FinalDestination_5

### Delete the shadow copy created and the link to it (junction).
$s2.Delete()
#
[io.directory]::Delete("C:\shadowcopy")



