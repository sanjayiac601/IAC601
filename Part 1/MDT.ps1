# Create a new Folder
New-Item -Path C:\DeploymentShare -Type directory -Verbose
 
# Share Folder
New-SmbShare -Name "DeploymentShare" -Path "C:\DeploymentShare" -FullAccess "medialabs.com\administrator","everyone"

# Import MDT Module
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

# Create a new Deployment Share
New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "C:\DeploymentShare" -Description "MDT Deployment Share" -NetworkPath \\MEDIALABS\DeploymentShare | add-MDTPersistentDrive

# Import operating system into MDT deployment share
Import-MDTOperatingSystem -path "DS001:\Operating Systems" -SourcePath "E:\" -DestinationFolder "Windows 11" -Verbose

# Add VLC
Import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "VLC" -ShortName "VLC" -CommandLine "vlc-3.0.21-win64.exe /L=1033 /S"`
 -WorkingDirectory ".\Applications\VLC" -ApplicationSourcePath "C:\Users\Administrator\Desktop\Apps" -DestinationFolder "VLC" -Verbos

# Add Adobe Acrobat Reader
Import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "Adobe Acrobat" -ShortName "Adobe Acrobat" -CommandLine "Reader_en_install.exe /sAll /rs /msi EULA_ACCEPT=YES"`
 -WorkingDirectory ".\Applications\Adobe Acrobat" -ApplicationSourcePath "C:\Users\Administrator\Desktop\Apps" -DestinationFolder "Adobe Acrobat" -Verbos

# Add Google Chrome
Import-MDTApplication -path "DS001:\Applications" -enable "True" -Name "Google Chrome" -ShortName "Google Chrome" -CommandLine "ChromeSetup.exe /silent /install"`
 -WorkingDirectory ".\Applications\Google Chrome" -ApplicationSourcePath "C:\Users\Administrator\Desktop\Apps" -DestinationFolder "Google Chrome" -Verbos

# Import task sequence
Import-MDTTaskSequence -path "DS001:\Task Sequences" -Name "OS with APPs" -Template "Client.xml" -Comments "" -ID "1" -Version "1.0"`
 -OperatingSystemPath "DS001:\Operating Systems\Windows 11 Home in Windows 11 install.wim" -FullName "Windows User" -OrgName "Media Labs" -HomePage "about:blank" -Verbose

# Update CustomSettings.ini and Bootstrap.ini
$CSpath = "C:\DeploymentShare\Control\CustomSettings.ini"
$BSpath = "C:\DeploymentShare\Control\Bootstrap.ini"

$CScontent = @'
[Settings]
Priority=Default
Properties=MyCustomProperty

[Default]
OSInstall=Y
SkipCapture=YES
SkipAdminPassword=YES
SkipProductKey=YES
SkipComputerBackup=YES
SkipBitLocker=YES

SkipBDDWelcome=YES
SkipUserData=YES
SkipTimeZone=YES
SkipLocaleSelection=YES
SkipComputerName=YES
SkipSummary=YES
SkipDomainMembership=YES
SkipApplications=YES
 
KeyboardLocale=en-US
TimeZoneName=GMT Standard Time
EventServices=http://Deployment:9800
'@

$BScontent = @'
[Settings]
Priority=Default

[Default]
DeployRoot=\\MEDIALABS\DeploymentShare

UserID=Administrator
UserPassword=Aspire2
UserDomain=medialabs.com
TaskSequenceID=1
SkipTaskSequence=YES
KeyboardLocale=en-US
SkipBDDWelcome=YES
'@

Set-Content -Path $CSpath -Value $CScontent
Set-Content -Path $BSpath -Value $BScontent


Set-ItemProperty -Path DS001: -Name SupportX86 -Value 'False'


# update deployment share
update-MDTDeploymentShare -path "DS001:" -Verbose

# Install WDS
Install-WindowsFeature –Name WDS -IncludeManagementTools

# Initialize server
wdsutil /initialize-server /remInst:"C:\DeploymentShare"

# Respond to all the clients
wdsutil /Set-Server /AnswerClients:All

# start the server
wdsutil /start-Server

#Import Boot image file
Import-WdsBootImage -Path "C:\DeploymentShare\Boot\LiteTouchPE_x64.wim"
