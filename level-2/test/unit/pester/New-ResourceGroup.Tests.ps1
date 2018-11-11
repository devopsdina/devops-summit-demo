$script:moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
"$script:moduleRoot\..\..\..\functions\New-ResourceGroup.ps1" | Resolve-Path | ForEach-Object{. $_.ProviderPath}

Describe 'New-ResourceGroup' {
  BeforeEach {
    Mock Get-AzureRmResourceGroup { }
    Mock New-AzureRmResourceGroup { }
  }

  it "Runs" {
    New-ResourceGroup -ResourceGroupName 'my-new-resource-group' -Location 'whatever-location-i-want'
  }

  it "Creates a resource group if it doesn't exist" {
    New-ResourceGroup -ResourceGroupName 'my-new-resource-group' -Location 'somewhere-in-the-world'
    Assert-MockCalled New-AzureRmResourceGroup -Exactly 1 -Scope It
  }

  it "Skips resource group creation if the resource group exists" {
    Mock Get-AzureRmResourceGroup {
      return @{
        ResourceGroupName = 'My-resource-group-already-exists'
        Location = 'somewhere-in-the-world'
        ProvisioningState = 'Succeeded'
        Tags = @{}
        ResourceId = "/subscriptions/my-azure-subscription/resourceGroups/My-resource-group-already-exists"
      }
    }
    New-ResourceGroup -ResourceGroupName 'My-resource-group-already-exists' -Location 'somewhere-in-the-world'
    Assert-MockCalled New-AzureRmResourceGroup -Exactly 0 -Scope It
  }
}