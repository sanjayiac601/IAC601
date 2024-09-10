# Update Deployment Share
update-MDTDeploymentShare -Path "C:\DeploymentShare" -Verbose

# Install WDS
Install-WindowsFeature -Name WDS -IncludeManagementTools

# Initialize server
wdsutil /initialize-server /remInst:"C:\DeploymentShare"

# Respond to all the clients
wdsutil /Set-Server /AnswerClients:All

# Start the server
wdsutil /start-Server

# Import Boot Image file
Import-WdsBootImage -Path "C:\DeploymentShare\Boot\LiteTouchPE_x64.wim"


