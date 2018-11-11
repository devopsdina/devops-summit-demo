param(
  [Parameter(Mandatory=$true)]
  [string]
  $ResourceGroupName,

  [Parameter(Mandatory=$true)]
  [string]
  $SubscriptionId
)

Connect-AzureRmAccount
Write-Output "Selecting subscription '$($SubscriptionId)'"
Select-AzureRmSubscription -SubscriptionID $SubscriptionId

#####################################################################
########
######## Remove the resource group and all the stuff in it
########
#####################################################################

Get-AzureRmResourceGroup -Name $ResourceGroupName | Remove-AzureRmResourceGroup -Verbose -Force