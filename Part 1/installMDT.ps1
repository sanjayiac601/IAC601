#Define the path of the installer
$MDTInstallerPath = "C:\Users\Administrator\Desktop\Softwares\MicrosoftDeploymentToolkit_x64.msi"
# Install MDT
Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$MDTInstallerPath`" /quiet /norestart" -Wait
