<#
.SYNOPSIS
Deploys Azure Infrastructure for a simple VM with networking componenets using AzureRM cmdlets and a parameters object.

.DESCRIPTION
This script can be customized as needed for the deployment.

.PARAMETER DeploymentName
Required. The name of the system or product being deployed. A param validation could be added here to ensure the keyvault name does not go over 24 characters

.PARAMETER SubscriptionId
Required. The subscription id where the template will be deployed.

.PARAMETER ResourceGroupLocation
Optional. Defaults to eastus2, the user can pass which ever region the code should be deployed in

.PARAMETER ClientID
Optional. The client id to use to authenticate

.PARAMETER ClientSecret
Optional. The client secret to use to authenticate

.PARAMETER DirectoryID
Optional. The tenant id to connect to

.EXAMPLE
   ./deploy.ps1 -DeploymentName '<name>' -SubscriptionId '<sub id>'
   ./deploy.ps1 -DeploymentName '<name>' -SubscriptionId '<sub id>' -Location 'CentralUS'
   ./deploy.ps1 -DeploymentName '<name>' -SubscriptionId '<sub id>' -Location 'CentralUS' -Environment 'Prod'
#>

param(
  [Parameter(Mandatory=$true)]
  [string]
  $DeploymentName,

  [Parameter(Mandatory=$true)]
  [string]
  $SubscriptionId,

  [Parameter(Mandatory=$false)]
  $Location = 'eastus2',

  [Parameter(Mandatory=$false)]
  [ValidateSet('dev','prod')]
  [string]$Environment = 'dev',

  [Parameter(Mandatory=$false)]
  [string]$ClientID = $env:ClientID,
  
  [Parameter(Mandatory=$false)]
  [string]$ClientSecret = $env:ClientSecret,
  
  [Parameter(Mandatory=$false)]
  [string]$DirectoryID = $env:DirectoryID
)
$ErrorActionPreference = "Stop"

## Since we aren't publishing modules yet, we need to dot source them first before we call anything
## If the modules can be published, we can remove the 3 lines below
$script:moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
# Dot source functions
"$script:moduleRoot\functions\*.ps1" | Resolve-Path | ForEach-Object{. $_.ProviderPath}

Connect-Az -ClientID $ClientID -ClientSecret $ClientSecret -DirectoryId $DirectoryID

Write-Output "Selecting subscription '$($subscriptionId)'"
Select-AzureRmSubscription -SubscriptionID $subscriptionId

$ResourceGroupName = "$($DeploymentName)-rg" 
New-ResourceGroup -ResourceGroupName $ResourceGroupName -Location $Location

#####################################################################
########
######## Deploy Key Vault
########
#####################################################################
$VaultName = "$($DeploymentName)-kv-lvl2"
$keyVault = (Get-AzureRmKeyVault -VaultName "$($VaultName)").VaultName

if (-not $keyVault) {
  Write-Output "Creating Azure Key Vault $($VaultName)"
 $null = New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName -Location $Location -EnabledForTemplateDeployment
} else {
  Write-Output "$($keyVault) already exists..."
}

#####################################################################
########
######## Generate Password and put it in keyvault
########
#####################################################################
$alphaNumeric = (((48..57) + (65..90) + (97..122) | Get-Random -Count 25 | ForEach-Object {[char]$_}) -join '')
$charsSymbol= (((35,36,40,41,42,44,45,46,47,58,59,63,64,92,95) | Get-Random -Count 5 | ForEach-Object { [Char] $_ }) -join '')

$SecretValue = $alphaNumeric + $charsSymbol | ConvertTo-SecureString -AsPlainText -Force

$SecretName = "VMLocalAdminSecurePassword"
$secretExists = Get-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretName -ErrorAction SilentlyContinue

if (-not $secretExists) {
  $null = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $SecretValue
}

#####################################################################
########
######## Set variables by environment type
########
#####################################################################
if ($environment -eq 'Prod') {
  $osDiskType = 'Standard_LRS'
  $virtualMachineSize = 'Standard_F1'
  $vnetAddressPrefix = '10.10.0.0/16'
  $subnetPrefix = '10.10.0.0/24'
} else {
  $osDiskType = 'Standard_LRS'
  $virtualMachineSize = "Standard_DS3"
  $vnetAddressPrefix = '10.0.0.0/16'
  $subnetPrefix = '10.0.0.0/24'
}

#####################################################################
########
######## Deploy the ARM template!
########
#####################################################################

# Instead of having multiple parameter files, use an object to allow for flexibility.
$param = @{
  location = $Location
  vnetName = "$($DeploymentName)-Net"
  vnetAddressPrefix = $vnetAddressPrefix
  networkInterfaceName = "$($DeploymentName)-NIC"
  subnetPrefix = $subnetPrefix
  subnetName = "$($DeploymentName)-Subnet"
  virtualMachineName = "$($DeploymentName)-VM"
  osDiskType = $osDiskType
  virtualMachineSize = $virtualMachineSize
  adminPassword = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretName).SecretValue
}

Write-Output "Starting deployment..."
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Location $Location -TemplateFile './azuredeploy.json' -TemplateParameterObject $param -Mode 'Incremental' -Verbose