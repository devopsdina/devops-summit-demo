<#
.SYNOPSIS
Creates a resource group if one does not exist.

.PARAMETER ResourceGroupName
Required. The resource group to be created

.PARAMETER ResourceGroupLocation
Required. The geographic location for the resource group
#>
function New-ResourceGroup {
  param(
  [Parameter(Mandatory=$True)]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$True)]
  [string] $Location
  )

  #Create or check for existing resource group
  $resourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

  if(-not $resourceGroup)
  {
      Write-Output "Creating resource group '$resourceGroupName' in location '$Location'";
      New-AzureRmResourceGroup -Name $resourceGroupName -Location $Location
  }
  else{
      Write-Output "Using existing resource group '$resourceGroupName'";
      $return
  }
}