<#
.SYNOPSIS
Deploys Azure Infrastructure for a simple VM with networking componenets using AzureRM cmdlets

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
  [string]$ClientID = $env:ClientID,
  
  [Parameter(Mandatory=$false)]
  [string]$ClientSecret = $env:ClientSecret,
  
  [Parameter(Mandatory=$false)]
  [string]$DirectoryID = $env:DirectoryID
)
$ErrorActionPreference = "Stop"

#####################################################################
########
######## Check to see if Azure context exists, if not, look for the pop-up behind all the windows, else use this context!
########
#####################################################################
try {
  $Azcontext = Get-AzureRmcontext

  if (($null -ne $Azcontext.Tenant.Id) -and ($Azcontext.Tenant.Id -ne $DirectoryID)) {
    $Azcontext = $null
  }

  if (-not $Azcontext.Subscription) {
    if ((-not $ClientID) -or (-not $ClientSecret) -or (-not $DirectoryID)) {
      Connect-AzureRmAccount
    }
    else {
      $Cred = (New-Object System.Management.Automation.PSCredential $ClientID, (ConvertTo-SecureString $ClientSecret -AsPlainText -Force))
      Connect-AzureRmAccount -Credential $Cred -ServicePrincipal -TenantId $DirectoryID
    }
  }
}
catch {
    Throw $_
}

Write-Output "Selecting subscription '$($SubscriptionId)'"
Select-AzureRmSubscription -SubscriptionID $SubscriptionId

#####################################################################
########
######## Deploy Resource Group
########
#####################################################################
$ResourceGroupName = "$($DeploymentName)-rg" 
$resourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if(-not $resourceGroup)
{
  Write-Output "Creating resource group '$ResourceGroupName' in location '$Location'";
  New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
} else {
  Write-Output "$($ResourceGroupName) already exists..."
}

#####################################################################
########
######## Deploy Key Vault
########
#####################################################################
$VaultName = "$($DeploymentName)-kv-lvl0"
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
######## Deploy VM
########
#####################################################################
$VmName = "$($DeploymentName)-vm"

$VM = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue).Name

$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretName).SecretValue
$VMSize = "Standard_DS3"
$NetworkName = "MyNet"
$NICName = "MyNIC"
$SubnetName = "MySubnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"

$Vnet = Get-AzureRmResource -ResourceType 'Microsoft.Network/virtualNetworks' -ResourceGroupName $ResourceGroupName -Name $NetworkName -ErrorAction SilentlyContinue


if (-not $vnet) {
  $SingleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
  $Vnet = New-AzureRmVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
}

$NIC = get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $NICName -ErrorAction SilentlyContinue

if (-not $NIC) {
  $Vnet = Get-AzureRmVirtualNetwork -Name $networkname -ResourceGroupName $resourcegroupname
  $NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $Vnet.Subnets[0].Id
}

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VmName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2012-R2-Datacenter' -Version latest

if (-not $VM) {
  New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose
} else {
  Write-Output "$($VM) already exists..."
}